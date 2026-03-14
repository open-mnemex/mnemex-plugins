---
name: tmux-orchestrator
description: >-
  Orchestrate multiple AI CLI agents (Claude Code, Gemini CLI) in
  parallel via tmux. Launch workers in tmux panes, dispatch tasks,
  detect completion, and collect results. Supports both CC (title-
  based ✳ detection) and Gemini (screen-based "esc to cancel"
  detection). Use when the user wants to: (1) run multiple Claude
  Code or Gemini sessions in parallel, (2) dispatch tasks to AI
  workers, (3) fan-out work across multiple AI instances,
  (4) coordinate multi-agent workflows.
  Triggers (EN): "tmux orchestrate", "parallel CC", "multi agent",
  "fan out tasks", "tmux workers", "dispatch to CC", "dispatch to
  gemini", "parallel gemini".
  Triggers (中文): "tmux编排", "并行CC", "多agent", "分发任务",
  "多个Claude Code", "并行gemini".
---

# Tmux Orchestrator

Orchestrate multiple AI CLI workers (Claude Code / Gemini CLI)
in tmux panes from a single "commander" session.

## Helper Script

`scripts/tmux_cc.sh` — all commands accept an optional agent type
(`cc` or `gemini`, default `cc`):

```bash
S=~/.claude/skills/tmux-orchestrator/scripts/tmux_cc.sh

$S start  <session> [num] [cc|gemini]
$S attach <session>
$S send   <target> <message> [cc|gemini]
$S wait   <target> [timeout] [cc|gemini]
$S read   <target> [lines]
$S status <session> [cc|gemini]
$S stop   <session>
```

Target format: `session:window.pane` (e.g., `workers:0.0`).

## Agent-Specific Behavior

### Claude Code (`cc`)

- **Start**: `unset CLAUDECODE && cc`
- **Send**: text and Enter as **separate** send-keys calls
  (long text triggers bracketed paste mode, needs extra Enter)
  ```bash
  tmux send-keys -t T 'message'
  sleep 0.3
  tmux send-keys -t T Enter
  sleep 0.3
  tmux send-keys -t T Enter   # dismiss paste preview
  ```
- **Idle detect**: window title contains `✳`
- **Busy detect**: window title has spinner (`⠂`,`⠐`)
- **Interrupt**: `tmux send-keys -t T Escape`

### Gemini CLI (`gemini`)

- **Start**: `gemini --yolo` (auto-approve all actions)
- **Send**: text and Enter as **separate** send-keys calls
  (Ink TUI swallows Enter when bundled with text)
  ```bash
  tmux send-keys -t T 'message'
  sleep 0.3
  tmux send-keys -t T Enter
  ```
- **Idle detect**: `capture-pane` contains `Type your message`
  and does NOT contain `esc to cancel`
- **Busy detect**: `capture-pane` contains `esc to cancel`
- **Interrupt**: `tmux send-keys -t T Escape`
- **Exit**: `pkill -f gemini` (C-c only clears input,
  does not exit)

## Workflow

### 1. Create workspace & start workers

```bash
TASK="code_review"
WS="/tmp/workspace/$TASK"
mkdir -p "$WS"

$S start workers 3 cc       # 3 Claude Code panes
$S attach workers            # open terminal window for user
$S start gworkers 2 gemini  # 2 Gemini panes
$S attach gworkers
```

### 2. Dispatch tasks (file output pattern)

**Always instruct workers to write results to files** — never
rely on `capture-pane` / `$S read` for structured output.
Append an output directive to every prompt:

```bash
$S send gworkers:0.0 "Analyze code in /tmp/app.py. \
Write your COMPLETE analysis to $WS/worker_0.md \
in Markdown format with a summary table at the top." gemini
```

Template suffix to append to all prompts:
```
IMPORTANT: Write your COMPLETE result to <path>.md
in Markdown format. Include all technical details,
code snippets, and a summary table at the top.
```

Worker naming convention: `worker_0.md`, `worker_1.md`, …
or descriptive names like `reviewer_A.md`, `load_test.md`.

`send` auto-waits if target is busy.

### 3. Wait + verify files

```bash
$S wait gworkers:0.0 120 gemini
# Verify output file exists and has content:
ls -la "$WS"/*.md && wc -l "$WS"/*.md
```

Use `$S read` only for quick status checks or debugging,
**not** for collecting final results.

### 4. Summarize & cleanup

Read the output files directly (they are clean Markdown).
Write a `summary.md` to the workspace if aggregating
multiple workers' results.

```bash
$S stop workers
```

## Direct tmux Commands

```bash
# --- Claude Code ---
tmux send-keys -t T 'message' Enter
tmux display -t T -p '#{pane_title}'  # ✳ = idle

# --- Gemini CLI ---
tmux send-keys -t T 'message'         # text first
sleep 0.3
tmux send-keys -t T Enter             # Enter separately
tmux capture-pane -t T -p | grep "esc to cancel"  # busy?

# --- Common ---
tmux capture-pane -t T -p -S -50 | tail -20   # read output
tmux capture-pane -t T -p -S -         # full scrollback
tmux send-keys -t T Escape             # interrupt
tmux send-keys -t T C-u                # clear input
tmux send-keys -t T BTab               # cycle CC permissions
```

## Critical Rules

1. **One task per pane at a time.** Text sent while busy
   appends to the input buffer, producing garbled prompts.
2. **Always confirm idle before sending.** Use `$S send`
   (auto-waits) or check manually.
3. **Parallel = multiple panes**, not multiple sends to one.
4. **Always use file output.** Every prompt MUST instruct
   the worker to write results to a specific file path.
   Never rely on `capture-pane` for structured results —
   it is lossy, truncated, and mixed with TUI artifacts.
5. **Workspace convention:** Create `/tmp/workspace/<task>/`
   before dispatching. All worker outputs and the final
   `summary.md` go there.
6. **After `start`, always run `$S attach <session>`** to
   open a terminal window for the user to monitor workers.
   Detects Ghostty > iTerm2 > Terminal.app automatically.
