---
name: wechat-control
description: Control WeChat on macOS via Swift UI automation. Use when the user wants to interact with WeChat — send messages, read chats, scroll through history, open contacts, navigate conversations, or perform any WeChat operation. Trigger on any mention of WeChat, 微信, sending/reading WeChat messages, or browsing WeChat chats.
---

# WeChat Control

Automate WeChat on macOS using a Swift tool (`wechat_tool.swift`) that provides mouse clicks, keyboard input, scrolling, screenshots, and Accessibility API queries. WeChat does not expose a scripting API, so all interaction is visual — **always take screenshots to confirm state before and after actions**.

## Tool

Single script at `scripts/wechat_tool.swift`. Run with:

```bash
TOOL=~/.claude/skills/wechat-control/scripts/wechat_tool.swift
swift $TOOL <command> [args...]
```

Commands:

| Command | Args | Description |
|---------|------|-------------|
| `activate` | — | Bring WeChat to front |
| `screenshot` | `[x,y,w,h] <path>` | Full or cropped screenshot |
| `screen-size` | — | Print screen dimensions |
| `click` | `<x> <y>` | Click at screen coordinates |
| `doubleclick` | `<x> <y>` | Double-click |
| `type` | `<text...>` | Paste text via clipboard + Cmd+V |
| `enter` | — | Press Enter/Return (via osascript) |
| `hotkey` | `<mod> <key>` | Press modifier combo (e.g. `cmd f`) |
| `key` | `<keycode>` | Press key by virtual keycode |
| `scroll` | `<amount>` | Scroll vertically (positive=up, negative=down) |
| `ax-find` | `[role]` | Find AX elements (e.g. `TextField`, `Button`, `all`) |

## Core Workflow: Screenshot-Driven Interaction

**Never hardcode coordinates.** Always derive positions from the current screen state.

### 1. Observe

```bash
swift $TOOL activate
sleep 0.5
swift $TOOL screenshot /tmp/wc.png
```

Then read `/tmp/wc.png` to understand the current WeChat layout — window position, which chat is open, where UI elements are.

### 2. Locate

Use `ax-find Window` first to get exact window position and size — this is the anchor for all coordinates:

```bash
swift $TOOL ax-find Window
# Output: window "微信" pos:145,-1050 size:1068,917
```

For elements not exposed via AX (WeChat's chat input is a custom view), estimate coordinates from the screenshot. Crop specific regions for better readability:

```bash
swift $TOOL screenshot <win_x>,<win_y>,<win_w>,<win_h> /tmp/wechat.png
```

### 3. Act

Click, type, scroll, etc. based on observed positions.

### 4. Verify

**Always screenshot after every action** to confirm the result before proceeding.

## Critical Lessons (from real testing)

### Enter key: must use osascript, not CGEvent

WeChat's custom input field **ignores CGEvent keyboard events** for the Enter/Return key. The `enter` command uses osascript + System Events (`key code 36`) which WeChat correctly recognizes. CGEvent-based Enter only creates newlines or is silently ignored.

### Input field focus: click before typing

The `type` command (clipboard + Cmd+V) only works if WeChat's input field has focus. **Always click the input area before typing.** The input area is at the bottom of the chat pane, below the toolbar icons (emoji, sticker, file, scissors):

```bash
# Calculate input area position from window bounds
# input_x = win_x + sidebar_width + (chat_width / 2)
# input_y = win_y + win_h - 80  (roughly 80px from bottom)
swift $TOOL click <input_x> <input_y>
sleep 0.3
swift $TOOL type "message"
sleep 0.5
swift $TOOL enter
```

### Multi-monitor support

WeChat may be on any monitor. Detect displays and use absolute coordinates:

```bash
# Get all displays (in Swift tool or inline swift)
swift -e '
import CoreGraphics
var ids = [CGDirectDisplayID](repeating: 0, count: 10)
var count: UInt32 = 0
CGGetActiveDisplayList(10, &ids, &count)
for i in 0..<Int(count) {
    let b = CGDisplayBounds(ids[i])
    print("Display \(i): origin=(\(Int(b.origin.x)),\(Int(b.origin.y))) size=\(Int(b.width))x\(Int(b.height))")
}
'
```

External monitors use negative y-coordinates (e.g. y=-1050 for a monitor above the main display). All tool commands (click, screenshot) support negative coordinates. The `ax-find Window` output gives the exact position regardless of which monitor.

### Search is the most reliable way to find contacts

Clicking sidebar items by estimated y-coordinates is fragile. **Prefer searching:**

1. Click the search bar at top of sidebar (approximately `win_x + 110, win_y + 27`)
2. `type` the contact name
3. `sleep 1.5` (wait for search results to load)
4. `screenshot` the search results to see the layout
5. Click the contact under the "联系人" (Contacts) section — NOT the "搜索网络结果" section
6. `screenshot` to confirm the correct chat opened (check title bar)
7. Press Escape or click away to close search overlay when done

### Activate before interacting

Always run `activate` before clicking or typing. If WeChat is behind other windows, clicks will go to the wrong app. This is especially important on multi-monitor setups.

## Common Tasks

### Send a message to a contact

```bash
TOOL=~/.claude/skills/wechat-control/scripts/wechat_tool.swift

# 1. Activate and find window
swift $TOOL activate
sleep 0.5
swift $TOOL ax-find Window          # Get window position

# 2. Search for contact
swift $TOOL click <search_bar_x> <search_bar_y>
sleep 0.3
swift $TOOL type "联系人名字"
sleep 1.5
swift $TOOL screenshot <region> /tmp/search.png    # Verify search results

# 3. Click the contact under "联系人" section
swift $TOOL click <contact_x> <contact_y>
sleep 0.8
swift $TOOL screenshot <region> /tmp/chat.png      # Verify correct chat opened

# 4. Click input area, type message, send
swift $TOOL click <input_x> <input_y>
sleep 0.3
swift $TOOL type "消息内容"
sleep 0.5
swift $TOOL screenshot <region> /tmp/input.png     # Verify text in input field
swift $TOOL enter
sleep 0.8
swift $TOOL screenshot <region> /tmp/sent.png      # Verify sent (green bubble)
```

### Read chat history

1. Open the target chat, `screenshot` the chat area
2. Click in the chat message area to focus it
3. `scroll 50` to scroll up (increase for more history)
4. `screenshot` and read to see older messages
5. Repeat scroll + screenshot cycle as needed

### Browse multiple chats

For each contact: click in sidebar → `sleep 0.8` → `screenshot` chat area → read and summarize. Searching is more reliable than clicking by position if the contact list has scrolled.

## Handling WeChat When Closed

WeChat may not be running. Always handle this:

1. Launch with `open -a WeChat` and `sleep 3` to wait for startup
2. After launch, WeChat shows a **small login window** (≈280x380) with a "进入微信" button — it does NOT go directly to the main interface
3. Take a screenshot to confirm the login screen, then click "进入微信"
4. After clicking, the main window opens at a **completely different position and size** (≈1068x917), possibly on a different monitor
5. **Must re-run `ax-find Window`** after this transition to get the new window geometry

```bash
# Full startup flow
open -a WeChat
sleep 3
swift $TOOL activate
sleep 0.5
swift $TOOL ax-find Window          # Get login window position
swift $TOOL screenshot <region> /tmp/wc_login.png   # Verify login screen
# Click "进入微信" button (center-x, ~78% down the login window)
swift $TOOL click <btn_x> <btn_y>
sleep 3
swift $TOOL ax-find Window          # MUST re-check — window position changes completely
swift $TOOL screenshot <region> /tmp/wc_main.png    # Verify main interface loaded
```

### Re-check window position after state changes

Any major state transition (login → main, window resize, display change) can move the window. Always re-run `ax-find Window` after such transitions instead of relying on previously cached coordinates.

## Important Notes

- **Accessibility permission required**: Terminal/iTerm must be granted Accessibility access in System Settings > Privacy & Security > Accessibility
- **WeChat may not be running**: Use `open -a WeChat` to launch it — see "Handling WeChat When Closed" section above
- **Chat input is invisible to AX API**: WeChat's message input is a custom view not exposed via Accessibility
- **Clipboard is preserved**: The `type` command saves and restores clipboard contents
- **Allow delays**: Add `sleep 0.3-1.0` between actions to give WeChat time to respond
- **Do one thing at a time**: Type → screenshot verify → Enter → screenshot verify. Do NOT chain type + enter without verifying the text appeared in the input field first
