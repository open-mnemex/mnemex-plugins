#!/usr/bin/env bash
# codex_helper.sh — batch processing & health check for Codex CLI
# Usage: codex_helper.sh [-m model] <check|batch|batch-files> [args...]
set -euo pipefail

MODEL_FLAG=()
REASONING_EFFORT="high"
# Parse optional flags before subcommand
while [[ $# -gt 0 ]]; do
  case "$1" in
    -m) MODEL_FLAG=(-m "$2"); shift 2 ;;
    *)  break ;;
  esac
done

SUBCMD="${1:-help}"
shift || true

# Default concurrency cap (empirically determined: 264 reqs, 0 errors at 15 concurrent)
# Concurrency 5 gives 4x throughput vs serial with reasonable overhead
MAX_CONCURRENT=5

# Common flags for non-interactive codex exec
COMMON_FLAGS=(
  -c "model_reasoning_effort=${REASONING_EFFORT}"
  -s read-only
  --skip-git-repo-check
  --ephemeral
  --color never
)

# ─── check ───────────────────────────────────────────────────────────
cmd_check() {
  echo "=== Codex CLI Health Check ==="
  if ! command -v codex &>/dev/null; then
    echo "FAIL: codex not found in PATH"
    echo "Install: npm install -g @openai/codex"
    return 1
  fi
  echo "OK: codex found at $(command -v codex)"

  local version
  version=$(codex --version 2>/dev/null || echo "unknown")
  echo "OK: version $version"

  local tmpfile
  tmpfile=$(mktemp /tmp/codex_check_XXXXX.txt)
  trap "rm -f '$tmpfile'" RETURN

  if codex exec \
    ${MODEL_FLAG[@]+"${MODEL_FLAG[@]}"} \
    "${COMMON_FLAGS[@]}" \
    -o "$tmpfile" \
    "Reply with exactly: HEALTH_OK" >/dev/null 2>&1; then
    if grep -q "HEALTH_OK" "$tmpfile"; then
      echo "OK: authenticated and responding"
    else
      echo "WARN: responded but unexpected output: $(cat "$tmpfile")"
    fi
  else
    echo "FAIL: codex exec returned non-zero exit code"
    return 1
  fi
  echo "=== All checks passed ==="
}

# ─── batch ───────────────────────────────────────────────────────────
# Process questions from a file, one per line, max N concurrent
cmd_batch() {
  local file="${1:?Usage: codex_helper.sh batch <questions_file>}"
  if [[ ! -f "$file" ]]; then
    echo "ERROR: file not found: $file" >&2
    return 1
  fi

  local total
  total=$(grep -c '.' "$file")
  echo "Processing $total questions (concurrency: ${MAX_CONCURRENT})..."
  echo ""

  local n=0
  local pids=()
  local tmpdir
  tmpdir=$(mktemp -d)
  trap "rm -rf '$tmpdir'" EXIT

  while IFS= read -r question || [[ -n "$question" ]]; do
    [[ -z "$question" || "$question" == \#* ]] && continue
    n=$((n + 1))
    local idx=$n

    (
      local out_file="$tmpdir/${idx}.agent_out"
      codex exec \
        ${MODEL_FLAG[@]+"${MODEL_FLAG[@]}"} \
        "${COMMON_FLAGS[@]}" \
        -o "$out_file" \
        "$question" >/dev/null 2>&1 || true

      {
        echo "=== [$idx] $question ==="
        if [[ -f "$out_file" ]]; then
          cat "$out_file"
        else
          echo "(no output)"
        fi
        echo ""
      } > "$tmpdir/$idx.out"
    ) &
    pids+=($!)

    # Cap concurrency
    if (( ${#pids[@]} >= MAX_CONCURRENT )); then
      wait -n 2>/dev/null || true
      local new_pids=()
      for pid in "${pids[@]}"; do
        if kill -0 "$pid" 2>/dev/null; then
          new_pids+=("$pid")
        fi
      done
      pids=("${new_pids[@]}")
    fi
  done < "$file"

  # Wait for remaining
  for pid in "${pids[@]}"; do
    wait "$pid" 2>/dev/null || true
  done

  # Output in order
  for i in $(seq 1 "$n"); do
    if [[ -f "$tmpdir/$i.out" ]]; then
      cat "$tmpdir/$i.out"
    fi
  done

  echo "=== Done: $n questions processed ==="
}

# ─── batch-files ─────────────────────────────────────────────────────
# Process multiple files with the same prompt, max N concurrent
cmd_batch_files() {
  local prompt="${1:?Usage: codex_helper.sh batch-files <prompt> <files...>}"
  shift
  local files=("$@")

  if (( ${#files[@]} == 0 )); then
    echo "ERROR: no files specified" >&2
    return 1
  fi

  echo "Processing ${#files[@]} files (concurrency: ${MAX_CONCURRENT})..."
  echo "Prompt: $prompt"
  echo ""

  local n=0
  local pids=()
  local tmpdir
  tmpdir=$(mktemp -d)
  trap "rm -rf '$tmpdir'" EXIT

  for file in "${files[@]}"; do
    if [[ ! -f "$file" ]]; then
      echo "WARN: skipping $file (not found)" >&2
      continue
    fi
    n=$((n + 1))
    local idx=$n
    local fname="$file"

    (
      local content
      content=$(cat "$fname")
      local out_file="$tmpdir/${idx}.agent_out"
      # Feed file content via stdin prompt
      printf '%s\n\n---\n\n%s' "$content" "$prompt" | codex exec \
        ${MODEL_FLAG[@]+"${MODEL_FLAG[@]}"} \
        "${COMMON_FLAGS[@]}" \
        -o "$out_file" \
        - >/dev/null 2>&1 || true

      {
        echo "=== [$idx] $fname ==="
        if [[ -f "$out_file" ]]; then
          cat "$out_file"
        else
          echo "(no output)"
        fi
        echo ""
      } > "$tmpdir/$idx.out"
    ) &
    pids+=($!)

    # Cap concurrency
    if (( ${#pids[@]} >= MAX_CONCURRENT )); then
      wait -n 2>/dev/null || true
      local new_pids=()
      for pid in "${pids[@]}"; do
        if kill -0 "$pid" 2>/dev/null; then
          new_pids+=("$pid")
        fi
      done
      pids=("${new_pids[@]}")
    fi
  done

  # Wait for remaining
  for pid in "${pids[@]}"; do
    wait "$pid" 2>/dev/null || true
  done

  # Output in order
  for i in $(seq 1 "$n"); do
    if [[ -f "$tmpdir/$i.out" ]]; then
      cat "$tmpdir/$i.out"
    fi
  done

  echo "=== Done: $n files processed ==="
}

# ─── main ────────────────────────────────────────────────────────────
case "$SUBCMD" in
  check)       cmd_check ;;
  batch)       cmd_batch "$@" ;;
  batch-files) cmd_batch_files "$@" ;;
  *)
    echo "Usage: codex_helper.sh [-m model] <command> [args...]"
    echo ""
    echo "Commands:"
    echo "  check                          Verify Codex CLI is installed and authenticated"
    echo "  batch <questions_file>         Process questions from file (one per line, max ${MAX_CONCURRENT} concurrent)"
    echo "  batch-files <prompt> <files>   Process multiple files with same prompt (max ${MAX_CONCURRENT} concurrent)"
    echo ""
    echo "Options:"
    echo "  -m <model>    Override model (e.g. gpt-5.3-codex, gpt-5.1-codex-mini)"
    exit 1
    ;;
esac
