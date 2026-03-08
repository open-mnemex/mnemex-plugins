---
name: claude-code-cli
description: |
  Delegate tasks to Claude Code CLI subprocess — batch processing, parallel model queries, structured output.
  Triggers: "use claude-p", "claude subprocess", "用claude-p", "claude批量"
---

# Claude Code CLI Skill

## Quick Reference

| Task | Command |
|------|---------|
| Simple question | `env -u CLAUDECODE claude -p "question" --output-format text --tools "" --no-session-persistence > /tmp/out.txt 2>&1 && cat /tmp/out.txt` |
| With model | `env -u CLAUDECODE claude -p "question" --model haiku --output-format text --tools "" --no-session-persistence > /tmp/out.txt 2>&1 && cat /tmp/out.txt` |
| Tool-using task | `env -u CLAUDECODE claude -p "Read src/*.py and review" --permission-mode dontAsk --no-session-persistence > /tmp/out.txt 2>&1 && cat /tmp/out.txt` |
| Structured output | `env -u CLAUDECODE claude -p "Extract name and age" --output-format json --json-schema '{"type":"object","properties":{"name":{"type":"string"},"age":{"type":"integer"}},"required":["name","age"]}' --tools "" --no-session-persistence > /tmp/out.txt 2>&1 && cat /tmp/out.txt` |
| Low effort batch | `env -u CLAUDECODE claude -p "question" --model haiku --effort low --output-format text --tools "" --no-session-persistence > /tmp/out.txt 2>&1 && cat /tmp/out.txt` |
| With system prompt | `env -u CLAUDECODE claude -p "question" --system-prompt "You are a code reviewer" --output-format text --tools "" --no-session-persistence > /tmp/out.txt 2>&1 && cat /tmp/out.txt` |
| Health check | `~/.claude/skills/claude-code-cli/scripts/claude_code_helper.sh check` |
| Batch questions | `~/.claude/skills/claude-code-cli/scripts/claude_code_helper.sh batch questions.txt` |
| Batch files | `~/.claude/skills/claude-code-cli/scripts/claude_code_helper.sh batch-files "Review this" f1.py f2.py` |

## Mandatory Flags

- **Always `env -u CLAUDECODE`** — avoids "nested session" error when running from within Claude Code
- **Always `> /tmp/file.txt 2>&1`** — stdout is swallowed by outer Claude Code process; must redirect to file then `cat`
- **Always `--no-session-persistence`** — no session files for batch/scripted use
- **`--tools ""`** for Q&A tasks — disables tools, pure text completion (fastest)
- **`--permission-mode dontAsk`** when Claude needs tools (read files, run commands) — without it, non-interactive mode hangs waiting for approval

## Execution Modes

### Foreground (default)
Use for single tasks where Claude needs the result before proceeding.
```bash
tmpfile=$(mktemp /tmp/claude_XXXXX.txt)
env -u CLAUDECODE claude -p "Explain this error: $error_msg" \
  --model haiku --output-format text --tools "" \
  --no-session-persistence > "$tmpfile" 2>&1
result=$(cat "$tmpfile"); rm -f "$tmpfile"
```

### Background
Use for independent tasks that don't block Claude's next step.
Run via Bash tool with `run_in_background: true`.
```bash
env -u CLAUDECODE claude -p "Review src/auth.py for security issues" \
  --permission-mode dontAsk --no-session-persistence \
  > /tmp/claude-review.txt 2>&1
```

## Workflows

### Code Review
```bash
# Review a single file (tools needed to read file)
env -u CLAUDECODE claude -p "Read and review src/auth.py for security issues, error handling, and performance. Be specific with line references." \
  --permission-mode dontAsk --no-session-persistence \
  > /tmp/review.txt 2>&1 && cat /tmp/review.txt

# Review via stdin (no tools needed)
cat src/auth.py | env -u CLAUDECODE claude -p "Review this code for bugs and improvements" \
  --output-format text --tools "" --no-session-persistence \
  > /tmp/review.txt 2>&1 && cat /tmp/review.txt

# Batch review (max 5 concurrent)
~/.claude/skills/claude-code-cli/scripts/claude_code_helper.sh batch-files \
  "Review this code for bugs, security issues, and improvements" src/*.py
```

### Structured Output
```bash
# Extract structured data with JSON schema validation
env -u CLAUDECODE claude -p "Extract the person's name, age, and city from: John Smith, 42, lives in Portland" \
  --output-format json \
  --json-schema '{"type":"object","properties":{"name":{"type":"string"},"age":{"type":"integer"},"city":{"type":"string"}},"required":["name","age","city"]}' \
  --tools "" --no-session-persistence \
  > /tmp/structured.txt 2>&1 && cat /tmp/structured.txt
```

### Batch Processing
```bash
# Create a questions file
cat > /tmp/questions.txt << 'EOF'
What is the CAP theorem?
Explain CRDT data structures
Compare Raft vs Paxos consensus
EOF

# Process with max 5 concurrent
~/.claude/skills/claude-code-cli/scripts/claude_code_helper.sh batch /tmp/questions.txt
```

### With Custom System Prompt
```bash
env -u CLAUDECODE claude -p "Review this function for thread safety" \
  --system-prompt "You are a concurrency expert. Focus only on race conditions, deadlocks, and thread safety issues." \
  --output-format text --tools "" --no-session-persistence \
  > /tmp/out.txt 2>&1 && cat /tmp/out.txt
```

## Rate Limits (Summary)

| Concurrency | Performance | Recommendation |
|-------------|------------|----------------|
| 1 (serial) | Baseline | Safe default |
| **5** | **~4x throughput** | **Use this** |
| 10 | ~5-6x | Acceptable for Pro |
| 15+ | Diminishing returns | Only if needed |

- Auth: Anthropic API key or Claude Pro subscription
- Rate limits depend on tier (Pro, Team, API)
- Can run multiple `claude -p` subprocesses concurrently
- No empirical rate test done yet — start conservative at 5

## Model Selection

| Scenario | Model flag | Why |
|----------|-----------|-----|
| General tasks | (omit, uses default) | Uses account default model |
| Batch operations | `--model haiku` | Fastest, cheapest, sufficient for simple tasks |
| Standard quality | `--model sonnet` | Good balance of speed and quality |
| Complex reasoning | `--model opus` | Highest quality |
| Budget-sensitive | `--model haiku --effort low` | Minimum cost per call |
| With fallback | `--model sonnet --fallback-model haiku` | Auto-fallback on overload |

## Anti-Patterns

| Don't | Why | Do instead |
|-------|-----|------------|
| Omit `env -u CLAUDECODE` | "Nested session" error | Always unset CLAUDECODE env var |
| Omit `> file 2>&1` redirect | Stdout swallowed, no output | Always redirect to file then cat |
| Omit `--no-session-persistence` in batch | Creates session files per call | Always use for scripted/batch |
| Omit `--tools ""` for Q&A | Agent may invoke tools unnecessarily | Disable tools for pure text tasks |
| Omit `--permission-mode dontAsk` for tool tasks | Hangs waiting for approval | Always set when tools needed |
| Fire 20+ concurrent calls | May hit API rate limits | Cap at 5, increase if no errors |
| Forget to `cat` the output file | Result is in file, not stdout | Always `> file 2>&1 && cat file` |
| Use `--output-format json` without `--json-schema` | Gets unstructured JSON wrapper | Pair json format with schema, or use text |
| Pipe output directly (no redirect) | Output lost due to outer process | Always redirect to file first |
