---
name: session-analyzer
description: >
  Analyze Claude Code session history (JSONL conversation logs) to understand
  what happened in past sessions. Use when the user wants to: (1) review or
  understand a past Claude Code session, (2) search across sessions for a
  topic or keyword, (3) view thinking/CoT from a session, (4) analyze token
  usage and costs, (5) list recent sessions, (6) get a summary of what a
  session accomplished.
  Triggers (EN): "analyze session", "what did I do", "session history",
  "past conversations", "review session", "show thinking", "token usage",
  "how much did that cost", "find the session where".
  Triggers (中文): "分析session", "看看之前的对话", "session历史",
  "查session", "回顾session", "看thinking", "token用量", "花了多少钱".
---

# Session Analyzer

Analyze Claude Code session JSONL files efficiently without loading entire files into context.

## Quick Reference

Run the analysis script:

```bash
python3 ~/.claude/skills/session-analyzer/scripts/analyze_session.py <mode> [args]
```

### Modes

| Mode | Purpose | Example |
|---|---|---|
| `index` | List all sessions with date/size/first message | `index --limit 20` |
| `summary` | One-page session overview | `summary <session-id>` |
| `skeleton` | Conversation flow (skip bulky tool_results) | `skeleton <session-id>` |
| `thinking` | Extract all CoT/thinking blocks | `thinking <session-id>` |
| `tools` | Tool usage summary | `tools <session-id> -v` |
| `tokens` | Token usage + cost estimate per turn | `tokens <session-id>` |
| `search` | Search keyword across all sessions | `search "keyword"` |
| `daily` | Cross-session daily summary by date | `daily today`, `daily 2026-02-28`, `daily 2026-02-24:2026-02-28` |

### Session ID Resolution

Accept: full UUID, partial UUID prefix, or full file path.
Sessions live in `~/.claude/projects/<project-path>/<uuid>.jsonl`.

## Workflow

1. **Find the session**: Run `index` to list recent sessions, or `search` to find by keyword
2. **Get overview**: Run `summary <id>` for a quick understanding
3. **Dig deeper**: Use `skeleton`, `thinking`, or `tools` as needed
4. **Cost analysis**: Use `tokens` to see per-turn token usage and cost

## Schema Details

See [references/jsonl_schema.md](references/jsonl_schema.md) for the full JSONL structure.

Key facts:
- System prompt is NOT stored in JSONL (injected at API call time)
- Thinking/CoT IS fully stored in `assistant` message blocks
- `user` messages contain tool_results that dominate file size (90%+)
- `~/.claude/history.jsonl` is a fast index of all user inputs across sessions
