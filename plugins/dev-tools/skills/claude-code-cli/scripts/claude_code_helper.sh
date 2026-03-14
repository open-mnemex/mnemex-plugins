#!/usr/bin/env bash
# claude_code_helper.sh — batch processing & health check for Claude Code CLI
# Usage: claude_code_helper.sh [-m model] [-e effort] <check|batch|batch-files> [args...]
set -euo pipefail

MODEL_FLAG=()
EFFORT_FLAG=()
# Parse optional flags before subcommand
while [[ $# -gt 0 ]]; do
  case "$1" in
    -m) MODEL_FLAG=(--model "$2"); shift 2 ;;
    -e) EFFORT_FLAG=(--effort "$2"); shift 2 ;;
    *)  break ;;
  esac
done

SUBCMD="${1:-help}"
shift || true

# Default concurrency cap — conservative start, increase if no errors
MAX_CONCURRENT=5

# Common flags for non-interactive claude -p
# - env -u CLAUDECODE: avoid nested session error
# - --no-session-persistence: no session files for scripted use
# - --tools "": disable tools for Q&A (fastest)
# - --output-format text: plain text output
run_claude() {
  local prompt="$1"
  local outfile="$2"
  env -u CLAUDECODE claude -p "$prompt" \
    ${MODEL_FLAG[@]+"${MODEL_FLAG[@]}"} \
    ${EFFORT_FLAG[@]+"${EFFORT_FLAG[@]}"} \
    --output-format text \
    --tools "" \
    --no-session-persistence \
    > "$outfile" 2>&1 || true
}

# ─── check ───────────────────────────────────────────────────────────
cmd_check() {
  echo "=== Claude Code CLI Health Check ==="
  if ! command -v claude &>/dev/null; then
    echo "FAIL: claude not found in PATH"
    echo "Install: npm install -g @anthropic-ai/claude-code"
    return 1
  fi
  echo "OK: claude found at $(command -v claude)"

  local version
  version=$(env -u CLAUDECODE claude --version 2>/dev/null || echo "unknown")
  echo "OK: version $version"

  local tmpfile
  tmpfile=$(mktemp /tmp/claude_check_XXXXX.txt)
  trap "rm -f '$tmpfile'" RETURN

  if env -u CLAUDECODE claude -p "Reply with exactly: HEALTH_OK" \
    ${MODEL_FLAG[@]+"${MODEL_FLAG[@]}"} \
    --output-format text \
    --tools "" \
    --no-session-persistence \
    > "$tmpfile" 2>&1; then
    if grep -q "HEALTH_OK" "$tmpfile"; then
      echo "OK: authenticated and responding"
    else
      echo "WARN: responded but unexpected output: $(cat "$tmpfile")"
    fi
  else
    echo "FAIL: claude -p returned non-zero exit code"
    cat "$tmpfile"
    return 1
  fi
  echo "=== All checks passed ==="
}

# ─── batch ───────────────────────────────────────────────────────────
# Process questions from a file, one per line, max N concurrent
cmd_batch() {
  local file="${1:?Usage: claude_code_helper.sh batch <questions_file>}"
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
      local outfile="$tmpdir/${idx}.claude_out"
      run_claude "$question" "$outfile"

      {
        echo "=== [$idx] $question ==="
        if [[ -f "$outfile" ]]; then
          cat "$outfile"
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
  local prompt="${1:?Usage: claude_code_helper.sh batch-files <prompt> <files...>}"
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
      local outfile="$tmpdir/${idx}.claude_out"
      # Feed file content + prompt via stdin
      printf 'File: %s\n\n%s\n\n---\n\n%s' "$fname" "$content" "$prompt" | \
        env -u CLAUDECODE claude -p - \
          ${MODEL_FLAG[@]+"${MODEL_FLAG[@]}"} \
          ${EFFORT_FLAG[@]+"${EFFORT_FLAG[@]}"} \
          --output-format text \
          --tools "" \
          --no-session-persistence \
          > "$outfile" 2>&1 || true

      {
        echo "=== [$idx] $fname ==="
        if [[ -f "$outfile" ]]; then
          cat "$outfile"
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
    echo "Usage: claude_code_helper.sh [-m model] [-e effort] <command> [args...]"
    echo ""
    echo "Commands:"
    echo "  check                          Verify Claude Code CLI is installed and authenticated"
    echo "  batch <questions_file>         Process questions from file (one per line, max ${MAX_CONCURRENT} concurrent)"
    echo "  batch-files <prompt> <files>   Process multiple files with same prompt (max ${MAX_CONCURRENT} concurrent)"
    echo ""
    echo "Options:"
    echo "  -m <model>    Override model (e.g. haiku, sonnet, opus)"
    echo "  -e <effort>   Reasoning effort (low, medium, high)"
    exit 1
    ;;
esac
