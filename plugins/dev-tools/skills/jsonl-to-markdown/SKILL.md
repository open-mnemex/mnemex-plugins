---
name: jsonl-to-markdown
description: >
  Convert Claude Code JSONL conversation logs (.jsonl) into human-readable Markdown documents.
  Use when the user wants to: (1) export or view a Claude Code conversation as readable text,
  (2) convert a .jsonl conversation log to Markdown, (3) make a conversation log human-readable,
  (4) share or archive a Claude Code session. Triggers on requests involving .jsonl conversation
  files, conversation export, or session log formatting.
---

# JSONL to Markdown Converter

Convert Claude Code `.jsonl` conversation logs into structured, readable Markdown.

## Usage

```bash
uv run scripts/convert_conversation.py <input.jsonl> <output.md> [--no-user]
```

- `--no-user`: Exclude user messages (keep only assistant, tool calls, results, progress)

The script uses only Python stdlib — no dependencies needed.

## Locating Conversation Logs

Claude Code stores logs at:
```
~/.claude/projects/<project-path-with-dashes>/*.jsonl
```

List available logs:
```bash
ls -lht ~/.claude/projects/<project-path>/*.jsonl
```

## Output Format

Each conversation is grouped into logical **turns** (user message -> assistant response -> tool calls/results). The Markdown includes:

- **Session metadata**: ID, timestamps, record counts
- **Turn headers**: `## Turn N — timestamp`
- **User messages**: `### User` (omitted with `--no-user`)
- **Assistant text**: `### Assistant (model-name)`
- **Thinking blocks**: Collapsible `<details>` sections
- **Tool calls**: Blockquoted with name and all parameters
- **Tool results**: Full output in code blocks, errors marked `[ERROR]`
- **Progress**: MCP timing, agent updates (collapsed), hook events
- **Token usage**: Per-turn input/output/cache stats

## JSONL Record Types

| Type | Rendering |
|------|-----------|
| `user` (text) | User message |
| `user` (tool_result) | Tool result with full output |
| `assistant` (text) | Assistant message |
| `assistant` (thinking) | Collapsible thinking block |
| `assistant` (tool_use) | Tool call with parameters |
| `progress` (mcp) | MCP tool timing |
| `progress` (agent) | Collapsed count of agent updates |
| `progress` (hook) | Hook event |
| `system` | Turn duration, errors |
| `queue-operation` | Background task notifications |
| `file-history-snapshot` | Silently skipped |
