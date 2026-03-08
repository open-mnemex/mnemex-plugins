---
name: codex-cli
description: |
  Delegate tasks to Codex CLI — code review, codebase analysis, batch processing.
  Triggers: "use codex", "ask codex", "codex review", "用codex", "让codex"
---

# Codex CLI Skill

## Quick Reference

| Task | Command |
|------|---------|
| Simple question | `codex exec -s read-only --skip-git-repo-check --ephemeral --color never -o /tmp/out.txt "question" >/dev/null 2>&1 && cat /tmp/out.txt` |
| Code review (built-in) | `codex review 2>/dev/null` |
| Code review (custom) | `codex exec --full-auto --ephemeral --color never -o /tmp/out.txt "Read and review src/*.py for bugs" >/dev/null 2>&1 && cat /tmp/out.txt` |
| Codebase analysis | `codex exec --full-auto --ephemeral --color never -o /tmp/out.txt "Analyze project structure" >/dev/null 2>&1 && cat /tmp/out.txt` |
| Specific model | `codex exec -m gpt-5.1-codex-mini -c model_reasoning_effort=high ...` |
| Health check | `~/.claude/skills/codex-cli/scripts/codex_helper.sh check` |
| Batch questions | `~/.claude/skills/codex-cli/scripts/codex_helper.sh batch questions.txt` |
| Batch files | `~/.claude/skills/codex-cli/scripts/codex_helper.sh batch-files "Review this" f1.py f2.py` |

## Mandatory Flags (Non-Interactive)

- **Always `>/dev/null 2>&1`** — codex exec dumps verbose agent trace (thinking, tool calls) to stdout/stderr
- **Always `-o FILE`** — captures only the final agent message cleanly to a file
- **Always `--ephemeral`** — no session files cluttering disk
- **Always `--color never`** — no ANSI escapes in captured output
- **`-s read-only`** for Q&A tasks — no tool approval needed, sandboxed
- **`--full-auto`** when Codex needs tools (read files, run commands) — without it, non-interactive mode hangs waiting for approval
- **`--skip-git-repo-check`** when running outside a git repo
- **`-c model_reasoning_effort=high`** when using `gpt-5.1-codex-mini` (doesn't support `xhigh`)

## Execution Modes

### Foreground (default)
Use for single tasks where Claude needs the result before proceeding.
```bash
tmpfile=$(mktemp /tmp/codex_XXXXX.txt)
codex exec -s read-only --skip-git-repo-check --ephemeral --color never \
  -o "$tmpfile" "Explain this error: $error_msg" >/dev/null 2>&1
result=$(cat "$tmpfile"); rm -f "$tmpfile"
```

### Background
Use for independent tasks that don't block Claude's next step.
Run via Bash tool with `run_in_background: true`.
```bash
codex exec --full-auto --ephemeral --color never \
  -o /tmp/codex-research.txt "Search codebase for security issues" >/dev/null 2>&1
```

## Workflows

### Code Review (Built-in)
```bash
# Review uncommitted changes (must be in a git repo)
codex review 2>/dev/null

# Review against a base branch
codex review --base main 2>/dev/null

# Review a specific commit
codex review --commit abc123 2>/dev/null

# Custom review instructions
codex review "Focus on security issues and error handling" 2>/dev/null
```

### Code Review (Custom via exec)
```bash
# Review files with full tool access
codex exec --full-auto --ephemeral --color never \
  -o /tmp/review.txt \
  "Read all files in src/api/ and review for consistency, error handling, and security issues" \
  >/dev/null 2>&1 && cat /tmp/review.txt

# Batch review (max 5 concurrent)
~/.claude/skills/codex-cli/scripts/codex_helper.sh batch-files \
  "Review this code for bugs, security issues, and improvements" src/*.py
```

### Codebase Analysis
```bash
# Needs --full-auto for file/command tools
codex exec --full-auto --ephemeral --color never \
  -o /tmp/analysis.txt \
  "Analyze the project structure. Identify main entry points, key abstractions, and dependency graph" \
  >/dev/null 2>&1 && cat /tmp/analysis.txt
```

### Batch Processing
```bash
# Create a questions file
cat > /tmp/questions.txt << 'EOF'
What is the CAP theorem?
Explain CRDT data structures
Compare Raft vs Paxos consensus
EOF

# Process with max 5 concurrent (optimal throughput)
~/.claude/skills/codex-cli/scripts/codex_helper.sh batch /tmp/questions.txt
```

## Sandbox Modes

| Mode | Flag | Behavior |
|------|------|----------|
| Read-only | `-s read-only` | Can read files, cannot write or run commands |
| Workspace write | `-s workspace-write` | Can read/write in project dir, sandboxed commands |
| Full access | `-s danger-full-access` | Unrestricted (dangerous) |
| Full auto | `--full-auto` | Alias for `-a on-request -s workspace-write` |

**Default for Q&A**: `-s read-only` (safest, no approval needed)
**Default for tool-using tasks**: `--full-auto` (sandboxed but autonomous)

## Usage Monitoring

Check Codex rate limits and remaining quota via the ChatGPT backend API:

```bash
ACCESS_TOKEN=$(python3 -c "import json; d=json.load(open('$HOME/.codex/auth.json')); print(d['tokens']['access_token'])") && curl -s "https://chatgpt.com/backend-api/wham/usage" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" 2>&1 | python3 -c "
import json, sys, datetime
d = json.load(sys.stdin)
rl = d['rate_limit']
p = rl['primary_window']
s = rl['secondary_window']
crp = (d.get('code_review_rate_limit') or {}).get('primary_window') or {}
def fmt_reset(secs):
    h, m = divmod(secs // 60, 60)
    return f'{h}h{m}m'
def fmt_ts(ts):
    return datetime.datetime.fromtimestamp(ts).strftime('%m/%d %H:%M')
print(f'Plan: {d[\"plan_type\"]}  |  Account: {d[\"email\"]}')
print()
print(f'5h limit:      {100 - p[\"used_percent\"]}% left  (resets in {fmt_reset(p[\"reset_after_seconds\"])}  @ {fmt_ts(p[\"reset_at\"])})')
print(f'Weekly limit:  {100 - s[\"used_percent\"]}% left  (resets in {fmt_reset(s[\"reset_after_seconds\"])}  @ {fmt_ts(s[\"reset_at\"])})')
if crp:
    print(f'Code review:   {100 - crp[\"used_percent\"]}% left  (resets in {fmt_reset(crp[\"reset_after_seconds\"])}  @ {fmt_ts(crp[\"reset_at\"])})')
"
```

**API details:**
- Endpoint: `https://chatgpt.com/backend-api/wham/usage`
- Auth: Bearer token from `~/.codex/auth.json` → `tokens.access_token`
- Returns: `primary_window` (5h rolling), `secondary_window` (weekly), `code_review_rate_limit`
- Token refreshes automatically via codex login; if 401, run `codex login`

## Rate Limits (Summary)

| Concurrency | Avg/req | Throughput | Errors | Verdict |
|-------------|---------|------------|--------|---------|
| 1 (serial) | 52s | 1x | 0 | Baseline |
| 2 | 54s | 1.4x | 0 | Good |
| **5** | **49s** | **4x** | **0** | **Optimal** |
| 10 | 54s | 5x | 0 | Works fine |
| 15 | 55s | 8.5x | 0 | Works fine |

- **No rate limit errors at any concurrency level** (264 requests, 0 failures)
- Per-slot latency flat ~50-55s regardless of concurrency (agent bootstrap dominates)
- Each call uses ~22k tokens due to agent reading SOUL.md/USER.md on boot
- Auth: OpenAI OAuth (ChatGPT Pro)
- Full details: [references/rate-limits.md](references/rate-limits.md)

## Model Selection

| Scenario | Model flag | Why |
|----------|-----------|-----|
| General tasks | (omit, uses `gpt-5.3-codex`) | Default, highest quality |
| Batch operations | `-m gpt-5.1-codex-mini` | Cheapest, fastest, add `-c model_reasoning_effort=high` |
| Complex reasoning | `-m gpt-5.3-codex` | Quality + xhigh reasoning |
| Code review | (omit) | Built-in `codex review` uses default model |

## Anti-Patterns

| Don't | Why | Do instead |
|-------|-----|------------|
| Omit `-o FILE` in scripts | stdout has verbose agent trace | Always use `-o FILE` + `>/dev/null 2>&1` |
| Omit `--ephemeral` in batch | Creates session files for every call | Always `--ephemeral` for batch/scripted use |
| Use `xhigh` reasoning with mini | Returns 400 error | Use `-c model_reasoning_effort=high` |
| Run codex exec without `-s` or `--full-auto` | Hangs waiting for tool approval | Always specify sandbox mode |
| Fire 20+ concurrent calls | Diminishing returns above 15 | Cap at 5 for best throughput/overhead ratio |
| Use `-p` for prompts | `-p` is profile flag in codex, not prompt | Use positional arg: `codex exec "prompt"` |
| Omit `--skip-git-repo-check` outside repos | Fails with git repo error | Always add when running from arbitrary dirs |
