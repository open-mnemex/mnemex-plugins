# Safari AppleScript Reference

Complete reference for Safari automation on macOS Sequoia.

## Table of Contents

1. [Application Properties](#application-properties)
2. [Window Properties](#window-properties)
3. [Tab Properties](#tab-properties)
4. [Document Properties](#document-properties)
5. [JavaScript Bridge](#javascript-bridge)
6. [Common Patterns](#common-patterns)
7. [Error Handling](#error-handling)
8. [Known Issues](#known-issues)

---

## Application Properties

```applescript
tell application "Safari"
    name               -- "Safari"
    version            -- "18.x"
    frontmost          -- boolean

    -- Collections
    windows            -- list of browser windows
    documents          -- list of documents (one per tab)
end tell
```

## Window Properties

```applescript
tell application "Safari"
    tell front window
        name           -- title of current tab
        index          -- window index (1-based)
        bounds         -- {x, y, width, height}
        visible        -- boolean
        miniaturized   -- boolean (minimized)
        zoomed         -- boolean (maximized)

        -- Tab access
        tabs           -- list of all tabs
        current tab    -- the active tab
    end tell
end tell
```

## Tab Properties

```applescript
tell application "Safari"
    tell tab 1 of front window
        name           -- page title
        URL            -- current URL
        source         -- HTML source (read-only)
        text           -- visible text content
        visible        -- is this the current tab?
        index          -- tab index (1-based)
    end tell
end tell
```

## Document Properties

Each tab has a corresponding document:

```applescript
tell application "Safari"
    tell front document
        name           -- page title
        URL            -- current URL
        source         -- HTML source
        text           -- visible text

        -- Methods
        do JavaScript "..."  -- execute JS, return result
    end tell
end tell
```

**Note:** `front document` = current tab of front window. Use `document 2` etc. for other tabs.

## JavaScript Bridge

### Basic Execution

```applescript
tell application "Safari"
    do JavaScript "expression" in front document
end tell
```

### Return Types

| JS Type | AppleScript Type |
|---------|------------------|
| string | text |
| number | number/real |
| boolean | boolean |
| null/undefined | missing value |
| object/array | text (JSON) |

### Multiline JavaScript

```applescript
tell application "Safari"
    do JavaScript "
        (function() {
            var result = [];
            // ... processing
            return JSON.stringify(result);
        })()
    " in front document
end tell
```

### Async Operations

```applescript
-- Wait for async operation
tell application "Safari"
    do JavaScript "
        new Promise(resolve => {
            fetch('/api/data')
                .then(r => r.json())
                .then(d => resolve(JSON.stringify(d)));
        })
    " in front document
end tell
```

**Warning:** AppleScript may timeout on long async operations. Use reasonable timeouts.

## Common Patterns

### Check if Safari is Running

```applescript
if application "Safari" is running then
    tell application "Safari" to ...
end if
```

### Create Window if None Exists

```applescript
tell application "Safari"
    if (count of windows) = 0 then
        make new document
    end if
end tell
```

### Find Tab by URL

```applescript
tell application "Safari"
    repeat with w in windows
        repeat with t in tabs of w
            if URL of t contains "github.com" then
                set current tab of w to t
                set index of w to 1
                return
            end if
        end repeat
    end repeat
end tell
```

### Wait for Element

```applescript
tell application "Safari"
    repeat 20 times
        set found to do JavaScript "document.querySelector('#myElement') !== null" in front document
        if found then exit repeat
        delay 0.5
    end repeat
end tell
```

### Capture Screenshot via JS

```applescript
-- Note: Cannot directly screenshot, but can trigger print/save
tell application "Safari"
    activate
    delay 0.5
end tell

tell application "System Events"
    keystroke "s" using {command down, shift down}  -- Safari's Export as PDF
end tell
```

## Error Handling

### Common Error Codes

| Code | Meaning | Solution |
|------|---------|----------|
| -1728 | Object not found | Check window/tab exists |
| -1719 | Invalid index | Tab/window index out of range |
| -2753 | JavaScript error | Check JS syntax |
| -1712 | Timeout | Increase timeout or simplify operation |

### Robust Error Wrapper

```applescript
on safariDo(jsCode)
    try
        with timeout of 30 seconds
            tell application "Safari"
                if (count of windows) = 0 then
                    return "ERROR: No Safari windows open"
                end if
                return do JavaScript jsCode in front document
            end tell
        end timeout
    on error errMsg number errNum
        return "ERROR " & errNum & ": " & errMsg
    end try
end safariDo
```

## Known Issues

### 1. `allow JavaScript from Apple Events` Requirement

Safari requires explicit permission for AppleScript JS execution:
- Safari → Settings → Advanced → Show features for web developers
- Develop menu → Allow JavaScript from Apple Events

### 2. Cross-Origin Restrictions

JavaScript executed via AppleScript is still subject to CORS:
```applescript
-- This will FAIL for cross-origin requests:
do JavaScript "fetch('https://other-domain.com/api')" in front document
```

### 3. Private Browsing Detection

Cannot detect or control private windows:
```applescript
-- No property exists for this
-- Workaround: private windows have no history
```

### 4. Reading List Limitations

```applescript
-- Can add:
add reading list item "https://example.com"

-- CANNOT:
-- - List reading list items
-- - Remove items
-- - Check if URL is in reading list
```

### 5. Downloads

No AppleScript access to:
- Download status
- Download location
- Download history

### 6. Bookmarks

Limited access:
```applescript
-- Cannot reliably access or modify bookmarks via AppleScript
-- Use Bookmarks.plist for read-only access (~/Library/Safari/Bookmarks.plist)
```

### 7. Extension Context

JavaScript runs in page context, not extension context:
- No access to browser APIs (chrome.*, safari.extension.*)
- No access to content scripts
- No access to extension storage

## Performance Tips

1. **Batch JavaScript operations** - Multiple `do JavaScript` calls are slow
2. **Use delays wisely** - Too many delays slow automation; too few cause race conditions
3. **Minimize window/tab enumeration** - Cache results when possible
4. **Use specific selectors** - `querySelector` is faster than DOM traversal
