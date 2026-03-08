# Claude Code Session JSONL Schema

## File Locations

- Sessions: `~/.claude/projects/<project-path>/<session-id>.jsonl`
- Subagents: `~/.claude/projects/<project-path>/<session-id>/subagents/agent-*.jsonl`
- History index: `~/.claude/history.jsonl` (user inputs + sessionId + project)

## Message Types

### `user` (type: "user")
```
Top keys: parentUuid, isSidechain, userType, cwd, sessionId, version,
          gitBranch, type, message, isMeta, uuid, timestamp
message:  { role: "content", content: <string | block[]> }
```
Content can be:
- `string` — plain user text
- `list` of blocks:
  - `{ type: "text", text: "..." }` — user text
  - `{ type: "tool_result", tool_use_id, content }` — tool execution result (BULKY, often MBs)
  - `{ type: "document", ... }` — cached document content (BULKY)

**Size warning**: `tool_result` and `document` blocks dominate file size (a single block can be 9+ MB).

### `assistant` (type: "assistant")
```
Top keys: parentUuid, isSidechain, userType, cwd, sessionId, version,
          gitBranch, slug, message, requestId, type, uuid, timestamp
message:  { model, id, type, role, content: block[], stop_reason, usage }
usage:    { input_tokens, output_tokens, cache_creation_input_tokens, cache_read_input_tokens }
```
Content blocks:
- `{ type: "text", text: "..." }` — assistant response text
- `{ type: "tool_use", id, name, input: {...} }` — tool invocation
- `{ type: "thinking", thinking: "..." }` — CoT reasoning (full content preserved)

### `custom-title` (type: "custom-title")
Emitted when user runs `/rename <name>`. Contains `customTitle` field.
Overrides the auto-generated slug as the session's display name.

### `progress` (type: "progress")
Hook execution events. `data.type` is typically `"hook_progress"`.

### `file-history-snapshot` (type: "file-history-snapshot")
File modification snapshots with `snapshot` dict.

### `queue-operation` (type: "queue-operation")
Queue management events.

## Key Fields

| Field | Location | Notes |
|---|---|---|
| Thinking/CoT | `assistant.message.content[].thinking` | Full reasoning text |
| Token usage | `assistant.message.usage` | Per-turn input/output/cache |
| Tool calls | `assistant.message.content[].name/input` | Tool name + parameters |
| Tool results | `user.message.content[].type=="tool_result"` | Bulk of file size |
| Timestamps | `msg.timestamp` | Milliseconds epoch |
| Model | `assistant.message.model` | e.g. "claude-opus-4-6" |
| Session slug | `assistant.slug` | Auto-generated name (e.g. "calm-sniffing-manatee") |
| Custom title | `custom-title.customTitle` | User-set name via `/rename` |
| System prompt | NOT stored | Injected at API call time |

## Session Naming

Each session has an auto-generated **slug** (e.g. `calm-sniffing-manatee`) stored in
`assistant` messages. This slug serves as the session's human-readable identifier.

- The slug appears in `claude --resume` session list for identification
- Users can override it with `/rename <name>`, which emits a `custom-title` entry
- Display name priority: `customTitle` > `slug` > UUID
- To find a session by slug: `grep -rl "slug-name" ~/.claude/projects/<project>/*.jsonl`

## history.jsonl (Index File)

Each line: `{ display, pastedContents, timestamp, project, sessionId }`

Use for fast keyword search across all sessions without parsing full JSONL files.

## Size Distribution (Typical)

- `user` type messages: ~90%+ of file size (due to tool_result/document blocks)
- `assistant` type: ~1-5%
- `progress`: ~1%
- Others: <1%
