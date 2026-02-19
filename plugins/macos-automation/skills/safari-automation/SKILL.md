---
name: safari-automation
description: |
  Automate Apple Safari via AppleScript on macOS. Use proactively when user mentions:
  opening URLs, getting page content, managing tabs/windows, executing JavaScript,
  saving to reading list, or any Safari browser-related task.
  Triggers: "open this URL", "get page title", "list all tabs", "close tab",
  "run JavaScript on page", "add to reading list", "what tabs are open",
  "extract text from webpage", "take page screenshot".
---

# Safari Automation

AppleScript automation for Safari on macOS Sequoia.

## Quick Reference

### Navigation

```applescript
-- Open URL in new tab
tell application "Safari"
    activate
    tell front window
        set current tab to (make new tab with properties {URL:"https://example.com"})
    end tell
end tell

-- Open URL in new window
tell application "Safari"
    make new document with properties {URL:"https://example.com"}
end tell

-- Reload current page (no JS required)
tell application "Safari"
    set URL of current tab of front window to URL of current tab of front window
end tell
```

### Read Page Info

```applescript
-- Get current tab URL and title
tell application "Safari"
    set pageURL to URL of current tab of front window
    set pageTitle to name of current tab of front window
end tell

-- Get page source
tell application "Safari"
    set pageSource to source of front document
end tell

-- Get page text content (no JS required)
tell application "Safari"
    set pageText to text of front document
end tell
```

### Tab/Window Management

```applescript
-- List all tabs (all windows)
tell application "Safari"
    set tabList to {}
    repeat with w in windows
        repeat with t in tabs of w
            set end of tabList to {name of t, URL of t}
        end repeat
    end repeat
    return tabList
end tell

-- Close current tab
tell application "Safari" to close current tab of front window

-- Close specific tab by index
tell application "Safari" to close tab 2 of front window

-- Switch to tab by index
tell application "Safari"
    set current tab of front window to tab 3 of front window
end tell

-- Close all tabs except current
tell application "Safari"
    tell front window
        set currentURL to URL of current tab
        repeat with t in (reverse of tabs)
            if URL of t is not currentURL then close t
        end repeat
    end tell
end tell
```

### JavaScript Execution

**Prerequisite:** Safari → Settings → Developer → ☑ Allow JavaScript from Apple Events

```applescript
-- Execute JS and get result
tell application "Safari"
    do JavaScript "document.title" in front document
end tell

-- Click element by selector
tell application "Safari"
    do JavaScript "document.querySelector('button.submit').click()" in front document
end tell

-- Get element text
tell application "Safari"
    do JavaScript "document.querySelector('h1').innerText" in front document
end tell

-- Fill form field
tell application "Safari"
    do JavaScript "document.querySelector('#email').value = 'user@example.com'" in front document
end tell

-- Scroll page
tell application "Safari"
    do JavaScript "window.scrollTo(0, document.body.scrollHeight)" in front document
end tell
```

### Reading List

```applescript
-- Add current page to reading list
tell application "Safari"
    add reading list item (URL of front document)
end tell

-- Add with title and preview
tell application "Safari"
    add reading list item "https://example.com" with title "Example" and preview text "Description here"
end tell
```

### Screenshots

```bash
# Full screen
screencapture -x ~/Desktop/screenshot.png

# Safari window only
screencapture -l$(osascript -e 'tell app "Safari" to id of window 1') ~/Desktop/safari.png

# Selection (interactive)
screencapture -s ~/Desktop/selection.png
```

Options: `-x` silent, `-w` window picker, `-s` selection, `-l<windowid>` specific window

## Core Patterns

### Always Use Timeout

```applescript
with timeout of 30 seconds
    tell application "Safari"
        -- operations here
    end tell
end timeout
```

### From Bash (Double Timeout)

```bash
timeout 35 osascript -e 'with timeout of 30 seconds
    tell application "Safari"
        -- operations here
    end tell
end timeout'
```

### Error Handling

```applescript
try
    tell application "Safari"
        -- operation
    end tell
on error errMsg number errNum
    return "FAILED: " & errMsg & " (" & errNum & ")"
end try
```

### Wait for Page Load

```applescript
-- Simple delay (no JS required)
tell application "Safari"
    open location "https://example.com"
    delay 2
end tell

-- With JS readyState check (requires JS permission)
tell application "Safari"
    open location "https://example.com"
    delay 1
    repeat while (do JavaScript "document.readyState" in front document) is not "complete"
        delay 0.5
    end repeat
end tell
```

## Extracting Page Content

### Get All Links

```applescript
tell application "Safari"
    do JavaScript "
        Array.from(document.querySelectorAll('a[href]'))
            .map(a => a.href)
            .filter(h => h.startsWith('http'))
            .join('\\n')
    " in front document
end tell
```

### Get Table Data as CSV

```applescript
tell application "Safari"
    do JavaScript "
        Array.from(document.querySelectorAll('table tr'))
            .map(row => Array.from(row.cells).map(c => c.innerText).join(','))
            .join('\\n')
    " in front document
end tell
```

### Get Main Text Content

```applescript
-- No JS required
tell application "Safari"
    set pageText to text of front document
end tell

-- With JS (more control)
tell application "Safari"
    do JavaScript "document.body.innerText" in front document
end tell
```

## Web Automation Example

Search YouTube and open videos:

```applescript
-- 1. Open search results
tell application "Safari"
    activate
    open location "https://www.youtube.com/results?search_query=cat"
end tell

delay 3  -- Wait for page load

-- 2. Extract video links
tell application "Safari"
    set videoLinks to do JavaScript "
        Array.from(document.querySelectorAll('a#video-title'))
            .slice(0, 3)
            .map(a => a.href)
            .join('\\n')
    " in front document
end tell

-- 3. Open in new tabs
tell application "Safari"
    tell front window
        repeat with videoURL in paragraphs of videoLinks
            make new tab with properties {URL:videoURL}
        end repeat
    end tell
end tell
```

## Limitations

- **JavaScript requires permission**: Safari → Settings → Developer → Allow JavaScript from Apple Events
- **No direct cookie access**: Use JS `document.cookie` for accessible cookies
- **No network request interception**: Cannot modify XHR/fetch requests
- **No private browsing control**: Cannot open/detect private windows via AppleScript
- **JS execution context**: Scripts run in page context, no access to extension APIs
- **Reading list**: Can only add items, cannot list or remove
- **Downloads**: Cannot control or monitor downloads

## Full Reference

For complete Safari AppleScript dictionary and JavaScript bridge details:
→ See [references/Safari_Reference.md](references/Safari_Reference.md)
