---
name: wechat-control
description: Control WeChat on macOS via Swift UI automation. Use when the user wants to interact with WeChat — send messages, read chats, scroll through history, open contacts, navigate conversations, or perform any WeChat operation. Trigger on any mention of WeChat, 微信, sending/reading WeChat messages, or browsing WeChat chats.
---

# WeChat Control

Automate WeChat on macOS using a Swift tool (`wechat_tool.swift`) that provides mouse clicks, keyboard input, scrolling, screenshots, and Accessibility API queries. WeChat does not expose a scripting API, so all interaction is visual — **always take screenshots to confirm state before and after actions**.

## Tool

**Pre-compiled binaries (preferred, ~5x faster):**

```bash
BIN=~/.claude/skills/wechat-control/bin
$BIN/wechat_tool <command> [args...]
$BIN/ocr_locate <image_path> [search_text]
```

If binaries don't exist, rebuild with:
```bash
bash ~/.claude/skills/wechat-control/scripts/build.sh
```

Fallback (interpreted, slower): `swift ~/.claude/skills/wechat-control/scripts/wechat_tool.swift <command>`

### Commands

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
| `hover` | `<x> <y>` | Move mouse without clicking (for scroll targeting) |
| `scroll` | `<amount>` | Scroll vertically (positive=up, negative=down) |
| `ax-find` | `[role]` | Find AX elements (e.g. `TextField`, `Button`, `all`) |
| **`ocr`** | `<x,y,w,h> [text]` | **Screenshot + OCR in one step; returns screen coordinates** |
| **`find-click`** | `<text> <x,y,w,h>` | **Screenshot + OCR + click matched text in one step** |

### Compound commands (key optimization)

**`ocr`** — replaces the screenshot → Read image → ocr_locate → manual coord conversion workflow:

```bash
# Find all text in a region (returns screen coordinates directly!)
$BIN/wechat_tool ocr 0,33,200,300
# Output: 搜索 | screen_center:114,65 | screen_bbox:102,59,24,13

# Find specific text
$BIN/wechat_tool ocr 0,33,200,50 "搜索"
```

**`find-click`** — replaces screenshot → OCR → calculate coords → click:

```bash
# Find "搜索" in region and click it — one command!
$BIN/wechat_tool find-click "搜索" 0,33,200,50
# Output: found '搜索' at screen 114,65
#         clicked 114,65
```

**These commands auto-handle Retina 2x scaling** — no manual `pixel/2 + offset` conversion needed.

### OCR tool (`ocr_locate.swift`)

Standalone OCR for existing image files. Uses Apple Vision framework.

```bash
# Find all text in image
$BIN/ocr_locate /tmp/screenshot.png

# Find text containing "搜索"
$BIN/ocr_locate /tmp/screenshot.png "搜索"
```

Output format: `text | bbox:x,y,w,h | center:cx,cy` (pixel coords — **not** screen coords; use `ocr` command instead for screen coords).

**CRITICAL — Retina 2x scaling:** Screenshots on Retina displays
produce 2x pixel images (e.g. 400x300 point crop → 800x600 pixel
image). OCR returns pixel coordinates. To convert to screen points:

```
screen_x = pixel_x / 2
screen_y = pixel_y / 2 + window_y_offset
```

Always verify scale factor: crop a known-size region and compare
image dimensions to the crop point dimensions.

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

### Fullscreen mode

WeChat works normally in fullscreen — screenshots, clicks, search, typing all function correctly. Key differences:

- **Window size changes**: e.g. 864→1728 wide. Always re-run `ax-find Window` after entering/exiting fullscreen.
- **`ax-find Window` returns two windows**: the main window plus a 1728x33 title bar window.
- **All coordinates shift** — never reuse coordinates from normal mode.
- **Enter/exit fullscreen** requires osascript (the `hotkey` tool only supports single modifiers, not Ctrl+Cmd combos):

```bash
# Enter fullscreen
osascript -e '
tell application "WeChat" to activate
delay 0.5
tell application "System Events"
    key code 3 using {control down, command down}
end tell
'

# Exit fullscreen (Ctrl+Cmd+F doesn't work reliably; use menu)
osascript -e '
tell application "System Events"
    tell process "WeChat"
        click menu item "Exit Full Screen" of menu "窗口" of menu bar 1
    end tell
end tell
'
```

### Search is the most reliable way to find contacts

Clicking sidebar items by estimated y-coordinates is fragile. **Prefer searching.**

**Primary method — Enter to jump (fastest, safest):**

1. Click the search bar (the "搜索" text area, ~`win_x + 200, win_y + 35`)
2. `hotkey cmd a` to select any previous search text
3. `type` the contact name
4. `sleep 1.5` (wait for search results to load)
5. `enter` — directly jumps to the first contact match
6. `sleep 1` then **verify chat title via OCR** (mandatory!)
7. If title doesn't match, Escape and retry

```bash
# Example: search and jump
swift $TOOL click 200 69        # click search bar
sleep 0.5
swift $TOOL hotkey cmd a        # select old text
sleep 0.2
swift $TOOL type "联系人名字"
sleep 1.5
swift $TOOL enter               # jump to contact
sleep 1
# MUST verify title before sending
swift $TOOL screenshot 260,34,600,50 /tmp/title.png
swift $OCR /tmp/title.png       # confirm name matches
```

**Fallback — OCR click (when Enter picks wrong result):**

1. After step 4 above, `screenshot` search results
2. Use `swift $OCR` to find the contact under "联系人" section
3. Convert pixel coords to screen points (÷2 for Retina + offset)
4. Click the contact, then verify title

**Key tips:**
- `Cmd+A` before typing replaces old search text efficiently
- **Always verify chat title before typing a message** — sending
  to the wrong person is the #1 batch-send failure mode
- The search bar activation point is the "搜索" text itself,
  not the sidebar edge

### Scroll targeting: hover before scroll, never click

The `scroll` command sends wheel events at the **current cursor position**. If you `click` on the sidebar to position the cursor, it selects a chat item and may shift scroll focus to the right panel. **Always use `hover` to position the cursor without clicking before scrolling:**

```bash
# WRONG — click selects a chat, scroll may target chat area
swift $TOOL click 115 500
swift $TOOL scroll -5

# RIGHT — hover positions cursor, scroll targets sidebar list
swift $TOOL hover 115 500
sleep 0.3
swift $TOOL scroll -5
```

### Prefer 通讯录管理 over chat list for batch contact extraction

Scrolling through the chat list and OCR-ing names from screenshots is slow (~60 screenshots for ~100 contacts) and error-prone (truncated names, misread characters). WeChat's **通讯录管理** (Contact Manager) is far superior:

- Has real names (备注), tags (标签), and structured data
- Can filter by tag (亲人, 大佬, UCLA, etc.)
- Ask the user to open it and screenshot by tag group instead

### Activate before interacting

Always run `activate` before clicking or typing. If WeChat is behind other windows, clicks will go to the wrong app. This is especially important on multi-monitor setups.

### Handling minimized windows: `open -a` not `activate`

The `activate` command (NSRunningApplication.activate) does **NOT** restore minimized WeChat windows. If the window is minimized to the Dock, `activate` succeeds but no window appears and `ax-find Window` returns nothing.

**Solution:** Use `open -a WeChat` instead — this reliably restores minimized windows. Use it as the standard activation method for all cases:

```bash
# WRONG — doesn't restore minimized windows
swift $TOOL activate

# RIGHT — works for minimized, hidden, and normal states
open -a WeChat
sleep 1
swift $TOOL ax-find Window   # now returns the window
```

### Cmd+Q does not quit WeChat

WeChat intercepts Cmd+Q and merely **hides the window** instead of quitting. The process stays alive. To truly quit WeChat for a cold restart test, use:

```bash
kill $(pgrep -x WeChat)
sleep 3
# Verify
pgrep -x WeChat || echo "Quit confirmed"
```

## Common Tasks

### Send a message to a contact

```bash
TOOL=~/.claude/skills/wechat-control/scripts/wechat_tool.swift
OCR=~/.claude/skills/wechat-control/scripts/ocr_locate.swift

# 1. Activate
swift $TOOL activate
sleep 0.3

# 2. Search and jump to contact
swift $TOOL click 200 69             # search bar
sleep 0.5
swift $TOOL hotkey cmd a             # select old search text
sleep 0.2
swift $TOOL type "联系人名字"
sleep 1.5
swift $TOOL enter                    # jump to first match
sleep 1

# 3. MANDATORY: verify chat title before sending
swift $TOOL screenshot 260,34,600,50 /tmp/title.png
swift $OCR /tmp/title.png            # confirm correct contact

# 4. Click input area, type message, send
swift $TOOL click 600 920            # input area (bottom of chat)
sleep 0.3
swift $TOOL type "消息内容"
sleep 0.5
swift $TOOL enter                    # send
sleep 1
```

### Batch send messages

For sending the same template to many contacts, the proven loop is:

```bash
for each contact (search_name, greeting_name):
  1. click search bar → Cmd+A → type search_name → sleep 1.5
  2. Enter → sleep 1 → OCR verify title
  3. click input → type personalized message → Enter
  4. sleep 1 → next contact
```

**Batch-send guardrails:**
- Verify title for EVERY message — never skip this step
- If title doesn't match, Escape and re-search before sending
- Keep a sent log to track progress and catch errors

### Read chat history

1. Open the target chat, `screenshot` the chat area
2. Click in the chat message area to focus it
3. `scroll 50` to scroll up (increase for more history)
4. `screenshot` and read to see older messages
5. Repeat scroll + screenshot cycle as needed

### Browse multiple chats

For each contact: click in sidebar → `sleep 0.8` → `screenshot` chat area → read and summarize. Searching is more reliable than clicking by position if the contact list has scrolled.

## Handling WeChat in Any State

WeChat can be in three states. Use `open -a WeChat` as the universal entry point — it works for all three:

### State detection

```bash
if ! pgrep -x WeChat > /dev/null; then
    echo "CLOSED"       # Not running at all
else
    open -a WeChat
    sleep 1
    # Check if ax-find returns a window
    if swift $TOOL ax-find Window 2>&1 | grep -q 'window "微信"'; then
        echo "RUNNING"  # Window visible (was minimized or normal)
    else
        echo "CLOSED"   # Process exists but no window (shouldn't happen after open -a)
    fi
fi
```

### Cold start (not running)

1. `open -a WeChat` and `sleep 3` to wait for startup
2. WeChat shows a **small login window** (≈280x380) with a "进入微信" button — it does NOT go directly to the main interface
3. `ax-find Window` to get login window position, then screenshot + OCR to locate "进入微信"
4. Click "进入微信" — the login window closes and the **main window opens at a completely different position and size** (≈864x1084)
5. **Must re-run `ax-find Window`** after this transition to get the new geometry

```bash
# Full cold-start flow
open -a WeChat
sleep 3
swift $TOOL activate
sleep 0.5
swift $TOOL ax-find Window          # Get login window position
swift $TOOL screenshot <region> /tmp/wc_login.png
swift $OCR /tmp/wc_login.png "进入微信"   # Get button coordinates
# Convert pixel coords to screen coords (÷2 for Retina + window offset)
swift $TOOL click <btn_x> <btn_y>
sleep 4
swift $TOOL ax-find Window          # MUST re-check — position changes completely
swift $TOOL screenshot <region> /tmp/wc_main.png    # Verify main interface
```

### Minimized (running but window hidden)

`activate` alone does NOT restore minimized windows. Use `open -a WeChat`:

```bash
open -a WeChat
sleep 1
swift $TOOL ax-find Window          # Window is now restored
```

### Normal (already visible)

`open -a WeChat` also works here — it simply brings the window to front, same as `activate`.

### Re-check window position after state changes

Any major state transition (login → main, window resize, display change) can move the window. Always re-run `ax-find Window` after such transitions instead of relying on previously cached coordinates.

## Important Notes

- **Accessibility permission required**: Terminal/iTerm must be granted Accessibility access in System Settings > Privacy & Security > Accessibility
- **WeChat may not be running**: Use `open -a WeChat` to launch it — see "Handling WeChat When Closed" section above
- **Chat input is invisible to AX API**: WeChat's message input is a custom view not exposed via Accessibility
- **Clipboard is preserved**: The `type` command saves and restores clipboard contents
- **Allow delays**: Add `sleep 0.3-1.0` between actions to give WeChat time to respond
- **Do one thing at a time**: Type → screenshot verify → Enter → screenshot verify. Do NOT chain type + enter without verifying the text appeared in the input field first
