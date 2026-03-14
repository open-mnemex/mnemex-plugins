---
name: gemini-cli
description: |
  Delegate tasks to Gemini CLI — code review, web research, codebase analysis, batch processing.
  Triggers: "use gemini", "ask gemini", "gemini review", "用gemini", "让gemini"
---

# Gemini CLI Skill

## Quick Reference

| Task | Command |
|------|---------|
| Simple question | `gemini -p "question" -o text 2>/dev/null` |
| Code review (stdin) | `cat file.py \| gemini -p "Review this code for bugs and improvements" -o text 2>/dev/null` |
| Code review (tool-based) | `gemini -p "Read and review src/*.py" --yolo -o text 2>/dev/null` |
| Web research | `gemini -p "Search the web for X and summarize findings" --yolo -o text 2>/dev/null` |
| Specific model | `gemini -m gemini-2.5-pro -p "question" -o text 2>/dev/null` |
| JSON output | `gemini -p "question" -o json 2>/dev/null \| jq '.response'` |
| Health check | `~/.claude/skills/gemini-cli/scripts/gemini_helper.sh check` |
| Batch questions | `~/.claude/skills/gemini-cli/scripts/gemini_helper.sh batch questions.txt` |
| Batch files | `~/.claude/skills/gemini-cli/scripts/gemini_helper.sh batch-files "Review this" f1.py f2.py` |
| Document review | `gemini -p "Review path/to/spec.md for issues" --yolo -o text 2>/dev/null` |
| Handwritten PDF | Pre-split with `pdftocairo -jpeg`, then `gemini -p "Transcribe..." < page.jpg` |
| List sessions | `gemini --list-sessions 2>/dev/null` |
| Start tracked session | `gemini_helper.sh session-start "prompt" [--yolo]` |
| Resume by UUID | `gemini_helper.sh session-resume <uuid> "prompt" [--yolo]` |

## Mandatory Flags

- **Always `2>/dev/null`** — suppress "Loaded cached credentials" stderr noise
- **Always `--yolo`** when Gemini needs tools (read files, web search, run commands) — without it, non-interactive mode hangs waiting for tool approval
- **Always `-o text`** for piping — use `-o json` only when structured data is specifically needed

## Execution Modes

### Foreground (default)
Use for single tasks where Claude needs the result before proceeding.
```bash
result=$(gemini -p "Explain this error: $error_msg" -o text 2>/dev/null)
```

### Background
Use for independent tasks that don't block Claude's next step.
Run via Bash tool with `run_in_background: true`.
```bash
gemini -p "Search the web for latest React 19 breaking changes" --yolo -o text 2>/dev/null > /tmp/gemini-research.txt
```

## Workflows

### Code Review
```bash
# Review a single file via stdin (no --yolo needed)
cat src/auth.py | gemini -p "Review this code. Focus on: security issues, error handling, performance. Be specific with line references." -o text 2>/dev/null

# Review multiple files (needs --yolo for file reading)
gemini -p "Read all files in src/api/ and review for consistency, error handling, and security issues" --yolo -o text 2>/dev/null

# Batch review (max 2 concurrent)
~/.claude/skills/gemini-cli/scripts/gemini_helper.sh batch-files "Review this code for bugs, security issues, and improvements" src/*.py
```

### Web Research
```bash
# Always use --yolo for web search tool access
gemini -p "Search the web for how to implement OAuth2 PKCE flow in Python and summarize the best practices" --yolo -o text 2>/dev/null
```

### Codebase Analysis
```bash
# Needs --yolo for file/grep tools
gemini -p "Analyze the project structure in this directory. Identify the main entry points, key abstractions, and dependency graph" --yolo -o text 2>/dev/null
```

### Handwritten PDF / Image Transcription
```bash
# Step 1: Claude pre-converts PDF pages to JPGs (avoid Gemini tool-call overhead)
mkdir -p /tmp/gemini-pdf-pages
pdftocairo -jpeg -r 200 "input.pdf" /tmp/gemini-pdf-pages/page

# Step 2: Batch-transcribe each page image via Gemini multimodal
for img in /tmp/gemini-pdf-pages/page-*.jpg; do
  gemini -p "Transcribe this handwritten page to Markdown. Use LaTeX (\$...\$) for math. Describe diagrams in blockquotes. Output ONLY markdown." -o text 2>/dev/null < "$img"
done > output.md

# Cleanup
rm -rf /tmp/gemini-pdf-pages
```

**Why pre-split:** Giving Gemini the raw PDF via `--yolo` causes it to
spend many internal tool calls (qpdf → pdfseparate → pdftocairo) and
pollutes the output with "thinking" noise. Pre-converting to JPGs lets
Gemini's multimodal vision process each page directly — cleaner output,
fewer tokens, no `--yolo` needed.

### Document / Spec Review
```bash
# Let Gemini read the file directly (--yolo), no need to pipe via stdin
gemini -p "Review path/to/spec.md for ambiguities, technical issues, and missing details" --yolo -o text 2>/dev/null
```

### Batch Processing
```bash
# Create a questions file
cat > /tmp/questions.txt << 'EOF'
What is the CAP theorem?
Explain CRDT data structures
Compare Raft vs Paxos consensus
EOF

# Process with max 2 concurrent (optimal throughput)
~/.claude/skills/gemini-cli/scripts/gemini_helper.sh batch /tmp/questions.txt
```

## Usage Monitoring

Check Gemini CLI quota remaining per model via the Google Code Assist API:

```bash
ACCESS_TOKEN=$(python3 -c "import json; d=json.load(open('$HOME/.gemini/oauth_creds.json')); print(d['access_token'])") && curl -s "https://cloudcode-pa.googleapis.com/v1internal:retrieveUserQuota" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"project":"any"}' 2>&1 | python3 -c "
import json, sys, datetime
d = json.load(sys.stdin)
buckets = d.get('buckets', [])
# Deduplicate vertex variants
seen = {}
for b in buckets:
    mid = b.get('modelId','')
    if '_vertex' in mid:
        continue
    seen[mid] = b
print(f'Gemini CLI Quota ({len(seen)} models)')
print()
for mid, b in sorted(seen.items()):
    pct = (b.get('remainingFraction', 0)) * 100
    reset = b.get('resetTime', '')
    if reset:
        t = datetime.datetime.fromisoformat(reset.replace('Z','+00:00')).astimezone()
        reset_str = t.strftime('%m/%d %H:%M')
    else:
        reset_str = '?'
    bar = '█' * int(pct // 5) + '░' * (20 - int(pct // 5))
    print(f'  {mid:30s} [{bar}] {pct:5.1f}% left  (resets {reset_str})')
"
```

**API details:**
- Endpoint: `POST https://cloudcode-pa.googleapis.com/v1internal:retrieveUserQuota`
- Auth: Bearer token from `~/.gemini/oauth_creds.json` → `access_token`
- Body: `{"project":"any"}` (project name doesn't affect personal quota)
- Returns: `buckets[]` with `modelId`, `remainingFraction`, `resetTime` per model
- Token refreshes via `gemini` login; if 401, run `gemini` interactively to re-auth

## Rate Limits (Summary)

| Concurrency | Performance | Recommendation |
|-------------|------------|----------------|
| 1 (serial) | 16s/req | Safe baseline |
| **2** | **7.6s/req** | **Use this** |
| 3 | ~10s/req | Acceptable |
| 5+ | Unstable | Avoid |
| 10+ | May hang | Never |

- 1 prompt = 2+ API requests (router + main model)
- AI Pro: ~750 effective prompts/day, ~60 prompts/min
- 429s are silently retried (5s→10s→20s→30s backoff, 10 attempts)
- Full details: [references/rate-limits.md](references/rate-limits.md)

## Model Selection

| Scenario | Model flag | Why |
|----------|-----------|-----|
| General tasks | (omit, use auto) | Router picks the best model |
| Batch operations | `-m gemini-2.5-flash` | Most lenient quota, fast |
| Complex reasoning | `-m gemini-2.5-pro` | Higher quality, separate quota pool |
| Quota pressure on flash | `-m gemini-2.5-pro` | Uses independent sub-quota |

## Thinking / COT Control

Configure via `~/.gemini/settings.json` under `modelConfigs.customAliases`.

### Gemini 3 series — `thinkingLevel`

| Level | Thinking Tokens | Behavior |
|-------|----------------|----------|
| `LOW` | **0** (stable) | Thinking OFF — no reasoning tokens |
| `MEDIUM` | 0 ~ 10k (unstable) | Model decides dynamically — unreliable |
| `HIGH` | ~1k+ (stable, scales with complexity) | **CLI default** — always reasons |

```json
// ~/.gemini/settings.json — set Gemini 3 to LOW thinking
{
  "modelConfigs": {
    "customAliases": {
      "chat-base-3": {
        "extends": "chat-base",
        "modelConfig": {
          "generateContentConfig": {
            "thinkingConfig": { "thinkingLevel": "LOW" }
          }
        }
      }
    }
  }
}
```

### Gemini 2.5 series — `thinkingBudget` (token count)

| Value | Effect |
|-------|--------|
| `0` | Thinking OFF (not supported on 2.5 Pro) |
| `-1` | Dynamic (model decides) |
| `1024` | Cap at 1024 thinking tokens |
| `8192` | CLI default |
| `24576` | Flash max / `32768` Pro max |

```json
// ~/.gemini/settings.json — set 2.5 Flash to 2048 thinking budget
{
  "modelConfigs": {
    "customAliases": {
      "chat-base-2.5": {
        "extends": "chat-base",
        "modelConfig": {
          "generateContentConfig": {
            "thinkingConfig": { "thinkingBudget": 2048 }
          }
        }
      }
    }
  }
}
```

### Per-agent override (without changing global default)

```json
{
  "modelConfigs": {
    "overrides": [
      {
        "match": { "overrideScope": "codebaseInvestigator" },
        "modelConfig": {
          "generateContentConfig": {
            "thinkingConfig": { "thinkingBudget": 4096 }
          }
        }
      }
    ]
  }
}
```

**Tips:**
- Use `LOW` / `thinkingBudget: 0` for fast tasks (code review, simple Q&A) to save tokens and latency
- Use `HIGH` / high budget for complex reasoning (architecture design, debugging)
- Avoid `MEDIUM` — behavior is unpredictable
- Check thinking tokens in JSON output: `gemini -p "..." -o json 2>/dev/null | jq '.stats.models[].tokens.thoughts'`

## Resuming Sessions

**NEVER use `-r latest`** — if multiple callers create sessions concurrently, `latest` may point to the wrong session. Always resume by UUID via the helper script.

### Safe resume via helper (recommended)

```bash
H=~/.claude/skills/gemini-cli/scripts/gemini_helper.sh

# Start a new tracked session — first line of output is the UUID
output=$($H session-start "Analyze this codebase for security issues" --yolo)
uuid=$(echo "$output" | head -1)
response=$(echo "$output" | tail -n +2)

# Resume by UUID (safe — immune to index drift from other sessions)
$H session-resume "$uuid" "Now fix the SQL injection you found" --yolo

# Resume again
$H session-resume "$uuid" "Add input validation tests for the fix" --yolo
```

### Raw CLI (only for interactive/manual use)

```bash
# List available sessions
gemini --list-sessions 2>/dev/null

# Resume by index (only safe when no concurrent callers)
gemini -r 3 -p "follow-up" -o text 2>/dev/null

# Resume interactively
gemini -r 3 -i "Continue where we left off"

# Delete a session by index
gemini --delete-session 3 2>/dev/null
```

**Key notes:**
- Sessions are per-project (scoped to the working directory)
- `session-start` returns UUID on line 1, response on subsequent lines — always capture the UUID
- `session-resume` looks up UUID → current index internally, so it's safe even if other sessions are created between calls
- Invalid session index exits with code 42 (no visible error when stderr suppressed)
- `--delete-session` with invalid index exits 0 silently

## Multi-Step Orchestration (Claude directing Gemini)

Use the helper's `session-start` / `session-resume` to run Gemini as a worker through a multi-step workflow. The UUID ensures you always resume the correct session, even if other callers create sessions concurrently.

```bash
H=~/.claude/skills/gemini-cli/scripts/gemini_helper.sh

# Step 1: Start session, capture UUID
output=$($H session-start "Read src/app.py. List all functions and what they do. Do NOT make changes yet." --yolo)
uuid=$(echo "$output" | head -1)
response=$(echo "$output" | tail -n +2)
# Claude reviews $response here...

# Step 2: Resume by UUID — safe, no index drift
$H session-resume "$uuid" "Good. Now add type hints to all functions. Apply changes directly." --yolo
# Claude reads the file to verify...

# Step 3: Resume again
$H session-resume "$uuid" "Now refactor format_receipt to use f-strings. Apply changes." --yolo
```

**Pattern:** Each `session-resume` call looks up the UUID → current index, so it always hits the right session. Gemini retains full context of prior steps.

**Tips:**
- Always capture UUID from `session-start` output (first line)
- Always include `--yolo` when Gemini needs to read/write files
- Keep each step's prompt focused on one task — easier to review and retry
- Verify results between steps (read the file, run tests) before giving the next instruction
- If a step goes wrong, re-issue `session-resume` with corrected instructions

## Anti-Patterns

| Don't | Why | Do instead |
|-------|-----|------------|
| Fire 5+ concurrent `gemini -p` | Causes 429 avalanche, may hang | Cap at 2 concurrent |
| Omit `--yolo` with tool-using prompts | Hangs waiting for approval | Always `--yolo` when tools needed |
| Omit `2>/dev/null` | Stderr noise pollutes output | Always suppress stderr |
| Use `-o json` by default | Same latency, harder to pipe | Use `-o text`, `-o json` only for structured parsing |
| Poll `/stats` from scripts | Interactive-only command | Track quota manually or check daily % in interactive session |
| Run `gemini` without `-p` in scripts | Enters interactive mode | Always use `-p` for non-interactive |
| Retry immediately on slow response | Slowness IS the 429 retry | Wait it out; reduce concurrency |
| Use `-r latest` in scripts | Index drift if concurrent sessions created | Use `session-start` + `session-resume` with UUID |
