#!/bin/bash
# tmux_cc.sh — Manage AI CLI workers (Claude Code / Gemini) in tmux
# Usage:
#   tmux_cc.sh start <session> <num_panes> [cc|gemini]
#   tmux_cc.sh send <target> <message> [cc|gemini]
#   tmux_cc.sh wait <target> [timeout_sec] [cc|gemini]
#   tmux_cc.sh read <target> [lines]
#   tmux_cc.sh status <session> [cc|gemini]
#   tmux_cc.sh attach <session>
#   tmux_cc.sh stop <session>

set -euo pipefail

cmd="${1:-help}"
shift || true

# --- Detection helpers ---

_is_idle_cc() {
  local target="$1"
  local title
  title=$(tmux display -t "$target" -p '#{pane_title}' \
    2>/dev/null || echo "")
  [[ "$title" == *"✳"* ]]
}

_is_idle_gemini() {
  local target="$1"
  local screen
  screen=$(tmux capture-pane -t "$target" -p 2>/dev/null || echo "")
  # BUSY if "esc to cancel" present; IDLE if only "Type your message"
  if echo "$screen" | grep -q "esc to cancel"; then
    return 1
  fi
  echo "$screen" | grep -q "Type your message"
}

_is_idle() {
  local target="$1"
  local agent="${2:-cc}"
  if [[ "$agent" == "gemini" ]]; then
    _is_idle_gemini "$target"
  else
    _is_idle_cc "$target"
  fi
}

case "$cmd" in

start)
  session="${1:?session name required}"
  num="${2:-2}"
  agent="${3:-cc}"
  tmux new-session -d -s "$session" -x 200 -y 50

  if [[ "$agent" == "gemini" ]]; then
    launch_cmd="gemini --yolo"
  else
    launch_cmd="unset CLAUDECODE && cc"
  fi

  tmux send-keys -t "$session:0.0" "$launch_cmd" Enter
  for ((i=1; i<num; i++)); do
    tmux split-window -h -t "$session"
    tmux send-keys -t "$session:0.$i" "$launch_cmd" Enter
    tmux select-layout -t "$session" tiled
  done

  echo "Waiting for $num $agent instances to start..."
  for ((i=0; i<num; i++)); do
    for ((try=0; try<60; try++)); do
      if _is_idle "$session:0.$i" "$agent"; then
        echo "  Pane $i: ready"
        break
      fi
      sleep 1
    done
  done
  echo "All workers ready."
  ;;

send)
  target="${1:?target pane required (session:window.pane)}"
  shift
  # Parse: last arg is agent type if "cc" or "gemini"
  agent="cc"
  last_arg="${!#}"
  if [[ "$last_arg" == "cc" || "$last_arg" == "gemini" ]]; then
    agent="$last_arg"
    # Remove last arg to get message
    set -- "${@:1:$#-1}"
  fi
  message="$*"

  # Wait for idle before sending
  if ! _is_idle "$target" "$agent"; then
    echo "WARNING: pane $target is busy. Waiting..."
    while ! _is_idle "$target" "$agent"; do
      sleep 0.5
    done
  fi

  if [[ "$agent" == "gemini" ]]; then
    # Gemini Ink TUI: text and Enter must be separate send-keys
    tmux send-keys -t "$target" "$message"
    sleep 0.3
    tmux send-keys -t "$target" Enter
  else
    # CC: long text triggers bracketed paste mode ([Pasted text]),
    # which absorbs the bundled Enter. Send text first, then Enter
    # separately, plus a second Enter to dismiss paste preview.
    tmux send-keys -t "$target" "$message"
    sleep 0.3
    tmux send-keys -t "$target" Enter
    sleep 0.3
    tmux send-keys -t "$target" Enter
  fi

  # Confirm agent started processing (busy state).
  # This guarantees wait() always starts from a known-busy state,
  # preventing false-positive DONE from stale idle detection.
  for ((try=0; try<30; try++)); do
    if ! _is_idle "$target" "$agent"; then
      echo "Sent to $target ($agent)"
      exit 0
    fi
    sleep 0.3
  done
  echo "WARNING: $target did not start processing"
  exit 1
  ;;

wait)
  target="${1:?target pane required}"
  timeout="${2:-120}"
  agent="${3:-cc}"

  # Safety net: brief wait for busy state (send already confirms
  # busy, but this defends against direct wait calls).
  for ((try=0; try<6; try++)); do
    if ! _is_idle "$target" "$agent"; then break; fi
    sleep 0.3
  done

  # Wait for idle to return (= completion)
  for ((try=0; try<timeout*2; try++)); do
    if _is_idle "$target" "$agent"; then
      echo "DONE"
      exit 0
    fi
    sleep 0.5
  done
  echo "TIMEOUT"
  exit 1
  ;;

read)
  target="${1:?target pane required}"
  lines="${2:-30}"
  tmux capture-pane -t "$target" -p -S "-$lines" \
    | grep -v '^$' | tail -"$lines"
  ;;

status)
  session="${1:?session name required}"
  agent="${2:-cc}"
  panes=$(tmux list-panes -t "$session" \
    -F '#{pane_index}' 2>/dev/null || echo "")
  if [ -z "$panes" ]; then
    echo "Session '$session' not found"
    exit 1
  fi
  for p in $panes; do
    if _is_idle "$session:0.$p" "$agent"; then
      state="IDLE"
    else
      state="BUSY"
    fi
    echo "Pane $p: $state"
  done
  ;;

attach)
  session="${1:?session name required}"
  if ! tmux has-session -t "$session" 2>/dev/null; then
    echo "Session '$session' not found"
    exit 1
  fi
  if [ -d "/Applications/Ghostty.app" ]; then
    open -na Ghostty.app --args -e tmux attach -t "$session"
    echo "Opened Ghostty window for session '$session'"
  elif [ -d "/Applications/iTerm.app" ]; then
    osascript -e "
      tell application \"iTerm\"
        activate
        set newWindow to (create window with default profile)
        tell current session of newWindow
          write text \"tmux attach -t $session\"
        end tell
      end tell"
    echo "Opened iTerm2 window for session '$session'"
  else
    osascript -e "
      tell application \"Terminal\"
        activate
        do script \"tmux attach -t $session\"
      end tell"
    echo "Opened Terminal window for session '$session'"
  fi
  ;;

stop)
  session="${1:?session name required}"
  tmux kill-session -t "$session" 2>/dev/null \
    && echo "Session '$session' killed" \
    || echo "Session '$session' not found"
  ;;

*)
  cat <<'USAGE'
Usage: tmux_cc.sh {start|send|wait|read|status|attach|stop}

Commands:
  start  <session> [num] [cc|gemini]    Start workers
  send   <target> <message> [cc|gemini] Send task (waits if busy)
  wait   <target> [timeout] [cc|gemini] Wait for completion
  read   <target> [lines]               Read pane output
  status <session> [cc|gemini]          Check all pane states
  attach <session>                      Open terminal window
  stop   <session>                      Kill session

Completion detection:
  cc:     Window title ✳ = idle, spinner = busy
  gemini: "esc to cancel" = busy, "Type your message" = idle

Gemini TUI note:
  Text and Enter must be sent as separate tmux send-keys calls.
USAGE
  ;;

esac
