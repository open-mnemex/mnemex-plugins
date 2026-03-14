#!/usr/bin/env bash
# codex_rate_test.sh — empirical rate limit / concurrency test for Codex CLI
# Mirrors gemini_rate_test.sh methodology
set -euo pipefail

PROMPT="What is 2+2? Reply with just the number."
MODEL="gpt-5.1-codex-mini"
CONCURRENCY_LEVELS=(1 2 5 10 15)
ROUNDS=8
ROUND_GAP=15        # seconds between rounds
LEVEL_GAP=180       # seconds between concurrency levels
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUTDIR="/tmp/codex_rate_test_${TIMESTAMP}"
CSV="${OUTDIR}/results.csv"
SUMMARY="${OUTDIR}/summary.txt"

mkdir -p "${OUTDIR}/raw"

echo "=== Codex CLI Rate Limit Test ==="
echo "Model: ${MODEL}"
echo "Prompt: ${PROMPT}"
echo "Concurrency levels: ${CONCURRENCY_LEVELS[*]}"
echo "Rounds per level: ${ROUNDS}"
echo "Output dir: ${OUTDIR}"
echo "Started: $(date)"
echo ""

# CSV header
echo "level,round,slot,wall_sec,exit_code,output" > "$CSV"

# ─── run a single codex call ─────────────────────────────────────────
run_one() {
  local level=$1 round=$2 slot=$3
  local out_file="${OUTDIR}/raw/L${level}_R${round}_S${slot}.txt"
  local start end wall exit_code output

  start=$(date +%s)
  # Use -o FILE for clean output; suppress all stdout/stderr noise
  if codex exec \
    -m "$MODEL" \
    -c model_reasoning_effort=high \
    -s read-only \
    --skip-git-repo-check \
    --ephemeral \
    --color never \
    -o "$out_file" \
    "$PROMPT" >/dev/null 2>&1; then
    exit_code=0
  else
    exit_code=$?
  fi
  end=$(date +%s)
  wall=$((end - start))

  output=""
  if [[ -f "$out_file" ]]; then
    output=$(head -1 "$out_file" | tr -d '\n' | tr ',' ';')
  fi

  echo "${level},${round},${slot},${wall},${exit_code},${output}" >> "$CSV"
  echo "  [L${level} R${round} S${slot}] ${wall}s exit=${exit_code} out='${output}'"
}

# ─── main loop ────────────────────────────────────────────────────────
for level in "${CONCURRENCY_LEVELS[@]}"; do
  echo ""
  echo "========================================"
  echo "Concurrency level: ${level}"
  echo "Starting at: $(date)"
  echo "========================================"

  for round in $(seq 1 "$ROUNDS"); do
    echo ""
    echo "--- Round ${round}/${ROUNDS} (concurrency=${level}) ---"
    round_start=$(date +%s)

    pids=()
    for slot in $(seq 1 "$level"); do
      run_one "$level" "$round" "$slot" &
      pids+=($!)
    done

    # Wait for all slots in this round
    for pid in "${pids[@]}"; do
      wait "$pid" 2>/dev/null || true
    done

    round_end=$(date +%s)
    round_wall=$((round_end - round_start))
    echo "  Round ${round} wall time: ${round_wall}s"

    # Gap between rounds (skip after last round)
    if (( round < ROUNDS )); then
      echo "  Waiting ${ROUND_GAP}s before next round..."
      sleep "$ROUND_GAP"
    fi
  done

  # Gap between levels (skip after last level)
  local last_level="${CONCURRENCY_LEVELS[${#CONCURRENCY_LEVELS[@]}-1]}"
  if [[ "$level" != "$last_level" ]]; then
    echo ""
    echo "Cooldown ${LEVEL_GAP}s before next concurrency level..."
    sleep "$LEVEL_GAP"
  fi
done

echo ""
echo "=== Test Complete ==="
echo "Ended: $(date)"
echo ""

# ─── generate summary ────────────────────────────────────────────────
echo "=== Generating Summary ==="

{
  echo "Codex CLI Rate Limit Test Summary"
  echo "================================="
  echo "Model: ${MODEL}"
  echo "Date: $(date)"
  echo "Codex version: $(codex --version 2>/dev/null || echo unknown)"
  echo ""
  echo "Per-level statistics:"
  echo ""
  printf "%-12s %-10s %-10s %-10s %-10s %-10s %-10s\n" \
    "Concurrency" "Total" "Successes" "Failures" "Avg(s)" "Min(s)" "Max(s)"
  printf "%-12s %-10s %-10s %-10s %-10s %-10s %-10s\n" \
    "-----------" "-----" "---------" "--------" "------" "------" "------"

  for level in "${CONCURRENCY_LEVELS[@]}"; do
    # Extract data for this level from CSV (skip header)
    level_data=$(awk -F',' -v l="$level" 'NR>1 && $1==l {print $4","$5}' "$CSV")
    total=$(echo "$level_data" | wc -l | tr -d ' ')
    successes=$(echo "$level_data" | awk -F',' '$2==0' | wc -l | tr -d ' ')
    failures=$((total - successes))

    if (( total > 0 )); then
      avg=$(echo "$level_data" | awk -F',' '{s+=$1} END {printf "%.1f", s/NR}')
      min_val=$(echo "$level_data" | awk -F',' 'NR==1||$1<m{m=$1} END{print m}')
      max_val=$(echo "$level_data" | awk -F',' 'NR==1||$1>m{m=$1} END{print m}')
    else
      avg="N/A"; min_val="N/A"; max_val="N/A"
    fi

    printf "%-12s %-10s %-10s %-10s %-10s %-10s %-10s\n" \
      "$level" "$total" "$successes" "$failures" "$avg" "$min_val" "$max_val"
  done

  echo ""
  echo "Per-round wall times:"
  echo ""
  for level in "${CONCURRENCY_LEVELS[@]}"; do
    echo "Concurrency ${level}:"
    for round in $(seq 1 "$ROUNDS"); do
      round_data=$(awk -F',' -v l="$level" -v r="$round" \
        'NR>1 && $1==l && $2==r {print $4}' "$CSV")
      if [[ -n "$round_data" ]]; then
        max_wall=$(echo "$round_data" | sort -n | tail -1)
        echo "  Round ${round}: ${max_wall}s (max of ${level} slots)"
      fi
    done
  done

  echo ""
  echo "Raw CSV: ${CSV}"
  echo "Raw outputs: ${OUTDIR}/raw/"
} | tee "$SUMMARY"

echo ""
echo "Summary saved to: ${SUMMARY}"
echo "CSV saved to: ${CSV}"
