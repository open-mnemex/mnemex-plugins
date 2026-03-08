# Claude Code CLI Reference

> Reference for `claude -p` non-interactive mode, used as subprocess from within Claude Code.

## Core Command Pattern

```bash
env -u CLAUDECODE claude -p "prompt" \
  --model haiku \
  --effort low \
  --output-format text \
  --tools "" \
  --no-session-persistence \
  > /tmp/out.txt 2>&1
cat /tmp/out.txt
```

## Flag Reference

### Required for Subprocess Use

| Flag | Purpose | Notes |
|------|---------|-------|
| `env -u CLAUDECODE` | Unset env var to avoid nested session error | Without this, `claude` thinks it's already inside Claude Code |
| `> file 2>&1` | Redirect all output to file | Stdout is swallowed by outer Claude Code process |
| `--no-session-persistence` | Don't create session files | Same role as codex's `--ephemeral` |

### Common Flags

| Flag | Values | Default | Purpose |
|------|--------|---------|---------|
| `--model` | `haiku`, `sonnet`, `opus` | Account default | Model alias |
| `--effort` | `low`, `medium`, `high` | `high` | Reasoning effort level |
| `--output-format` | `text`, `json`, `stream-json` | `text` | Output format |
| `--tools ""` | Empty string | All tools | Disable all tools (Q&A mode) |
| `--permission-mode` | `default`, `dontAsk`, `acceptEdits`, `bypassPermissions`, `plan` | `default` | Tool permission mode |
| `--system-prompt` | String | None | Custom system prompt |
| `--json-schema` | JSON schema string | None | Structured output validation |
| `--max-budget-usd` | Number | None | Budget cap per call |
| `--fallback-model` | Model alias | None | Auto-fallback on overload |

### Less Common Flags

| Flag | Purpose |
|------|---------|
| `--max-turns N` | Limit agentic turns |
| `--verbose` | Enable verbose logging |
| `-c, --continue` | Continue most recent conversation |
| `--resume SESSION_ID` | Resume a specific session |

## Output Formats

### `--output-format text` (recommended)
Plain text output. Best for piping and human reading.
```bash
env -u CLAUDECODE claude -p "What is 2+2?" --output-format text --tools "" \
  --no-session-persistence > /tmp/out.txt 2>&1
cat /tmp/out.txt
# 4
```

### `--output-format json`
JSON object with result metadata. Pair with `--json-schema` for structured output.
```bash
env -u CLAUDECODE claude -p "Extract name" --output-format json \
  --json-schema '{"type":"object","properties":{"name":{"type":"string"}},"required":["name"]}' \
  --tools "" --no-session-persistence > /tmp/out.txt 2>&1
cat /tmp/out.txt
# {"name":"John"}
```

### `--output-format stream-json`
Streaming JSONL — one JSON object per line. Useful for real-time processing and token stats.
```bash
env -u CLAUDECODE claude -p "What is 2+2?" --output-format stream-json --tools "" \
  --no-session-persistence > /tmp/out.txt 2>&1
# Parse the result line for token stats:
grep '"type":"result"' /tmp/out.txt | python3 -c "
import sys, json
data = json.loads(sys.stdin.readline())
stats = data.get('stats', data.get('usage', {}))
print(json.dumps(stats, indent=2))
"
```

## Model Aliases & Full Names

| Alias | Full model name | Best for |
|-------|----------------|----------|
| `haiku` | `claude-haiku-4-5-20251001` | Batch ops, simple tasks, cheapest |
| `sonnet` | `claude-sonnet-4-6` | Balanced speed + quality |
| `opus` | `claude-opus-4-6` | Complex reasoning, highest quality |

## Permission Modes

| Mode | Behavior | Analog |
|------|----------|--------|
| `default` | Prompts for tool approval | (interactive only) |
| `dontAsk` | Auto-approve all tools | codex `--full-auto` |
| `acceptEdits` | Auto-approve reads + edits, prompt for bash | — |
| `bypassPermissions` | No permission checks at all | codex `-s danger-full-access` |
| `plan` | Require plan approval before edits | — |

**For non-interactive subprocess**: Use `--tools ""` (no tools) or `--permission-mode dontAsk` (auto-approve).

## Structured Output with `--json-schema`

Forces output to conform to a JSON schema. Requires `--output-format json`.

```bash
env -u CLAUDECODE claude -p "Parse: John Smith, age 42, Portland" \
  --output-format json \
  --json-schema '{
    "type": "object",
    "properties": {
      "name": {"type": "string"},
      "age": {"type": "integer"},
      "city": {"type": "string"}
    },
    "required": ["name", "age", "city"]
  }' \
  --tools "" --no-session-persistence > /tmp/out.txt 2>&1
cat /tmp/out.txt
# {"name":"John Smith","age":42,"city":"Portland"}
```

## Extracting Token Stats from stream-json

The `"type":"result"` line in stream-json output contains usage statistics:

```bash
env -u CLAUDECODE claude -p "Hello" --output-format stream-json --tools "" \
  --no-session-persistence > /tmp/stream.txt 2>&1

# Extract stats
python3 -c "
import json
for line in open('/tmp/stream.txt'):
    line = line.strip()
    if not line: continue
    try:
        obj = json.loads(line)
        if obj.get('type') == 'result':
            usage = obj.get('stats', obj.get('usage', {}))
            print(f'Input tokens: {usage.get(\"input_tokens\", \"N/A\")}')
            print(f'Output tokens: {usage.get(\"output_tokens\", \"N/A\")}')
            break
    except json.JSONDecodeError:
        pass
"
```

## Comparison: `claude -p` vs `gemini -p` vs `codex exec`

| Aspect | `claude -p` | `gemini -p` | `codex exec` |
|--------|------------|-------------|-------------|
| Non-interactive flag | `-p "prompt"` | `-p "prompt"` | `"prompt"` (positional) |
| Output format | `--output-format text/json/stream-json` | `-o text/json/stream-json` | `-o FILE` (file only) |
| Suppress noise | `> file 2>&1` (stdout swallowed) | `2>/dev/null` | `>/dev/null 2>&1` + `-o FILE` |
| Auto-approve tools | `--permission-mode dontAsk` | `--yolo` | `--full-auto` |
| Disable tools | `--tools ""` | N/A | `-s read-only` |
| No session files | `--no-session-persistence` | (no sessions) | `--ephemeral` |
| System prompt | `--system-prompt "text"` | N/A | N/A |
| Model flag | `--model haiku/sonnet/opus` | `-m model-name` | `-m model-name` |
| Effort control | `--effort low/medium/high` | N/A | `-c model_reasoning_effort=...` |
| Structured output | `--json-schema '{...}'` | N/A | N/A |
| Budget cap | `--max-budget-usd N` | N/A | N/A |
| Fallback model | `--fallback-model haiku` | N/A | N/A |
| Auth | Anthropic API key / Claude Pro | Google OAuth | OpenAI OAuth |
| Concurrency (safe) | ~5 (untested, conservative) | 2 (429 at 5+) | 5+ (no 429 at 15) |
| Per-call latency | ~5-15s (varies by model) | ~16s (flash) | ~52s (agent bootstrap) |
| Token overhead | Low (direct) | Low (direct) | ~22k/call (agent session) |
| Subprocess env issue | Must `env -u CLAUDECODE` | None | None |

## Known Issues

### CLAUDECODE Environment Variable
When running `claude` from within Claude Code, the `CLAUDECODE` env var causes a "nested session" error. **Always** use `env -u CLAUDECODE` to unset it.

### Stdout Swallowing
The outer Claude Code process captures stdout from subprocesses. Output from `claude -p` will be lost unless redirected to a file. **Always** redirect: `> /tmp/out.txt 2>&1` then `cat /tmp/out.txt`.

### Stdin Prompt
`claude -p` accepts the prompt as a positional argument after `-p`, or via stdin with `-p -`:
```bash
# Positional
claude -p "my question"

# Stdin (useful for long prompts or file content)
echo "my question" | claude -p -
cat file.txt | claude -p "Review this:" -  # prompt + stdin
```

### Session Persistence
By default, `claude -p` creates session files. For batch/scripted use, always add `--no-session-persistence` to avoid filling disk with session data.
