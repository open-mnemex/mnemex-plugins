#!/usr/bin/env bash
# gemini_helper.sh — batch processing & health check for Gemini CLI
# Usage: gemini_helper.sh <check|batch|batch-files> [args...]
set -euo pipefail

MODEL_FLAG=()
# Parse optional -m flag before subcommand
while [[ $# -gt 0 ]]; do
  case "$1" in
    -m) MODEL_FLAG=(-m "$2"); shift 2 ;;
    *)  break ;;
  esac
done

SUBCMD="${1:-help}"
shift || true

# ─── check ───────────────────────────────────────────────────────────
cmd_check() {
  echo "=== Gemini CLI Health Check ==="
  if ! command -v gemini &>/dev/null; then
    echo "FAIL: gemini not found in PATH"
    echo "Install: npm install -g @google/gemini-cli"
    return 1
  fi
  echo "OK: gemini found at $(command -v gemini)"

  local version
  version=$(gemini --version 2>/dev/null || echo "unknown")
  echo "OK: version $version"

  local result
  if result=$(gemini ${MODEL_FLAG[@]+"${MODEL_FLAG[@]}"} -p "Reply with exactly: HEALTH_OK" -o text 2>/dev/null); then
    if echo "$result" | grep -q "HEALTH_OK"; then
      echo "OK: authenticated and responding"
    else
      echo "WARN: responded but unexpected output: $result"
    fi
  else
    echo "FAIL: gemini -p returned non-zero exit code"
    return 1
  fi
  echo "=== All checks passed ==="
}

# ─── batch ───────────────────────────────────────────────────────────
# Process questions from a file, one per line, max 2 concurrent
cmd_batch() {
  local file="${1:?Usage: gemini_helper.sh batch <questions_file>}"
  if [[ ! -f "$file" ]]; then
    echo "ERROR: file not found: $file" >&2
    return 1
  fi

  local total
  total=$(grep -c '.' "$file")
  echo "Processing $total questions (concurrency: 2)..."
  echo ""

  local n=0
  local pids=()
  local tmpdir
  tmpdir=$(mktemp -d)
  trap "rm -rf '$tmpdir'" EXIT

  while IFS= read -r question || [[ -n "$question" ]]; do
    [[ -z "$question" || "$question" == \#* ]] && continue
    n=$((n + 1))

    (
      local out
      out=$(gemini ${MODEL_FLAG[@]+"${MODEL_FLAG[@]}"} -p "$question" -o text 2>/dev/null)
      {
        echo "=== [$n] $question ==="
        echo "$out"
        echo ""
      } > "$tmpdir/$n.out"
    ) &
    pids+=($!)

    # Cap at 2 concurrent
    if (( ${#pids[@]} >= 2 )); then
      wait -n 2>/dev/null || true
      # Clean up finished pids
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
# Process multiple files with the same prompt, max 2 concurrent
cmd_batch_files() {
  local prompt="${1:?Usage: gemini_helper.sh batch-files <prompt> <files...>}"
  shift
  local files=("$@")

  if (( ${#files[@]} == 0 )); then
    echo "ERROR: no files specified" >&2
    return 1
  fi

  echo "Processing ${#files[@]} files (concurrency: 2)..."
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
      local out
      out=$(cat "$fname" | gemini ${MODEL_FLAG[@]+"${MODEL_FLAG[@]}"} -p "$prompt" -o text 2>/dev/null)
      {
        echo "=== [$idx] $fname ==="
        echo "$out"
        echo ""
      } > "$tmpdir/$idx.out"
    ) &
    pids+=($!)

    # Cap at 2 concurrent
    if (( ${#pids[@]} >= 2 )); then
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

# ─── session-start ────────────────────────────────────────────────────
# Start a new Gemini session and return its UUID for safe resume later.
# Usage: gemini_helper.sh session-start <prompt> [--yolo]
# Output (stdout): first line is UUID, rest is Gemini's response.
cmd_session_start() {
  local prompt="${1:?Usage: gemini_helper.sh session-start <prompt> [--yolo]}"
  shift
  local extra_flags=("$@")

  # Run the prompt
  local response
  response=$(gemini ${MODEL_FLAG[@]+"${MODEL_FLAG[@]}"} -p "$prompt" ${extra_flags[@]+"${extra_flags[@]}"} -o text 2>/dev/null)

  # Find the UUID of the session we just created (it will be the newest)
  local uuid
  uuid=$(gemini --list-sessions 2>/dev/null | tail -1 | grep -oE '\[([a-f0-9-]{36})\]' | tr -d '[]')

  if [[ -z "$uuid" ]]; then
    echo "ERROR: could not find session UUID" >&2
    return 1
  fi

  # Output: UUID on first line, response after
  echo "$uuid"
  echo "$response"
}

# ─── session-resume ───────────────────────────────────────────────────
# Resume a Gemini session by UUID (safe — immune to index drift).
# Usage: gemini_helper.sh session-resume <uuid> <prompt> [--yolo]
# Output (stdout): Gemini's response.
cmd_session_resume() {
  local uuid="${1:?Usage: gemini_helper.sh session-resume <uuid> <prompt> [--yolo]}"
  local prompt="${2:?Usage: gemini_helper.sh session-resume <uuid> <prompt> [--yolo]}"
  shift 2
  local extra_flags=("$@")

  # Look up the current index for this UUID
  local index
  index=$(gemini --list-sessions 2>/dev/null | grep "$uuid" | grep -oE '^\s*[0-9]+' | tr -d ' ')

  if [[ -z "$index" ]]; then
    echo "ERROR: session $uuid not found" >&2
    return 1
  fi

  gemini ${MODEL_FLAG[@]+"${MODEL_FLAG[@]}"} -r "$index" -p "$prompt" ${extra_flags[@]+"${extra_flags[@]}"} -o text 2>/dev/null
}

# ─── main ────────────────────────────────────────────────────────────
case "$SUBCMD" in
  check)          cmd_check ;;
  batch)          cmd_batch "$@" ;;
  batch-files)    cmd_batch_files "$@" ;;
  session-start)  cmd_session_start "$@" ;;
  session-resume) cmd_session_resume "$@" ;;
  *)
    echo "Usage: gemini_helper.sh [-m model] <command> [args...]"
    echo ""
    echo "Commands:"
    echo "  check                                  Verify Gemini CLI is installed and authenticated"
    echo "  batch <questions_file>                 Process questions from file (one per line, max 2 concurrent)"
    echo "  batch-files <prompt> <files>            Process multiple files with same prompt (max 2 concurrent)"
    echo "  session-start <prompt> [--yolo]         Start a session, return UUID on first line + response"
    echo "  session-resume <uuid> <prompt> [--yolo] Resume a session by UUID (safe, no index drift)"
    echo ""
    echo "Options:"
    echo "  -m <model>    Override model (e.g. gemini-2.5-flash, gemini-2.5-pro)"
    exit 1
    ;;
esac
