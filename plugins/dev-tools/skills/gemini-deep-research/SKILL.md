---
name: gemini-deep-research
description: |
  Use Gemini Deep Research via Chrome browser automation (AppleScript + JS) to conduct in-depth
  web research on any topic. Navigates to gemini.google.com, activates Deep Research mode, submits
  the query, polls for completion every ~10 minutes, and extracts the full research report as Markdown.
  No Chrome extensions needed — only requires Chrome to be running.
  Use this skill whenever the user wants thorough, multi-source web research that goes beyond a simple
  search — things like literature reviews, competitive analysis, technology comparisons, trend reports,
  or any question that benefits from Gemini reading and synthesizing dozens of web pages.
  Triggers (EN): "deep research", "gemini research", "research this topic", "do a deep dive on",
  "comprehensive research", "use gemini to research".
  Triggers (中文): "深度研究", "deep research", "帮我研究", "用gemini查", "深入调查", "调研一下".
---

# Gemini Deep Research via Chrome (AppleScript)

Automate Gemini's Deep Research feature through AppleScript + JavaScript injection.
Deep Research makes Gemini browse dozens of web pages autonomously, synthesize findings,
and produce a structured research report. This is far more thorough than a single web search.

**No Chrome extensions or MCP required** — only needs Google Chrome running and the user
logged into gemini.google.com with a Google One AI Premium (or Workspace) account.

## Core Pattern: AppleScript + JS

All browser interaction uses this pattern:

```bash
osascript -e '
tell application "Google Chrome"
    execute active tab of window 1 javascript "YOUR_JS_HERE"
end tell' 2>/dev/null
```

For navigation:
```bash
osascript -e 'tell application "Google Chrome" to set URL of active tab of window 1 to "https://gemini.google.com/app"' 2>/dev/null
```

## Workflow

### Step 1: Navigate to Gemini

```bash
# Open Gemini in a new tab to avoid overwriting user's current tab
osascript << 'EOF'
tell application "Google Chrome"
    tell window 1
        set newTab to make new tab with properties {URL:"https://gemini.google.com/app"}
        set active tab index to (count of tabs)
    end tell
end tell
EOF
```

Wait 3 seconds for the page to load, then verify:
```bash
sleep 3
osascript -e 'tell application "Google Chrome" to execute active tab of window 1 javascript "document.title"' 2>/dev/null
# Should return "Google Gemini"
```

**Important**: Remember which window and tab index Gemini is in. The user may switch
tabs/windows during the 5-15 minute research period. Always target the specific
window and tab, not just "active tab of window 1".

To track the tab:
```bash
# After opening, record the window and tab index
GEMINI_WINDOW=1
GEMINI_TAB=$(osascript -e 'tell application "Google Chrome" to count of tabs of window 1' 2>/dev/null)
```

Then use `tab $GEMINI_TAB of window $GEMINI_WINDOW` instead of `active tab of window 1`
for all subsequent operations.

### Step 2: Activate Deep Research

Click the "Tools" button, then select "Deep research":

```bash
# Click Tools button
osascript -e '
tell application "Google Chrome"
    execute active tab of window 1 javascript "
        var buttons = document.querySelectorAll(\"button\");
        for (var i = 0; i < buttons.length; i++) {
            if (buttons[i].textContent.trim().includes(\"Tools\")) {
                buttons[i].click(); break;
            }
        }
    "
end tell' 2>/dev/null

sleep 1

# Click Deep research in the dropdown
osascript -e '
tell application "Google Chrome"
    execute active tab of window 1 javascript "
        var items = document.querySelectorAll(\"button, [role=menuitem], [role=option], li, a\");
        for (var i = 0; i < items.length; i++) {
            if (items[i].textContent.trim().toLowerCase().includes(\"deep research\")) {
                items[i].click(); break;
            }
        }
    "
end tell' 2>/dev/null
```

### Step 3: Enter query and submit

```bash
sleep 1

# Type the query into the contenteditable input
osascript -e '
tell application "Google Chrome"
    execute active tab of window 1 javascript "
        var input = document.querySelector(\"[contenteditable=true][aria-label*=prompt], [role=textbox], .ql-editor\");
        if (!input) input = document.querySelector(\"[aria-label=\\\"Enter a prompt for Gemini\\\"]\");
        if (input) {
            input.focus();
            input.textContent = \"YOUR QUERY HERE\";
            input.dispatchEvent(new Event(\"input\", {bubbles: true}));
        }
    "
end tell' 2>/dev/null

sleep 1

# Click the Send button (Enter key simulation does NOT work reliably)
osascript -e '
tell application "Google Chrome"
    execute active tab of window 1 javascript "
        var buttons = document.querySelectorAll(\"button\");
        for (var i = 0; i < buttons.length; i++) {
            var label = buttons[i].getAttribute(\"aria-label\") || buttons[i].textContent.trim();
            if (label.toLowerCase().includes(\"send\") || label.toLowerCase().includes(\"submit\")) {
                buttons[i].click(); break;
            }
        }
    "
end tell' 2>/dev/null
```

**Note**: Simulated `keydown` Enter events do NOT trigger Gemini's submit. Always use
the Send button click approach.

### Step 4: Review research plan and start

After submitting, Gemini shows a research plan (5-10 seconds). Check for it:

```bash
sleep 8
osascript -e '
tell application "Google Chrome"
    execute active tab of window 1 javascript "
        var text = document.body.innerText;
        var hasStartBtn = text.indexOf(\"Start research\") >= 0;
        var hasPlan = text.indexOf(\"Research Websites\") >= 0 || text.indexOf(\"research plan\") >= 0;
        \"plan=\" + hasPlan + \" startBtn=\" + hasStartBtn;
    "
end tell' 2>/dev/null
```

If "Start research" button exists, click it:
```bash
osascript -e '
tell application "Google Chrome"
    execute active tab of window 1 javascript "
        var buttons = document.querySelectorAll(\"button\");
        for (var i = 0; i < buttons.length; i++) {
            if (buttons[i].textContent.trim().includes(\"Start research\")) {
                buttons[i].click(); break;
            }
        }
    "
end tell' 2>/dev/null
```

Briefly tell the user what the research plan covers before starting the poll.

### Step 5: Poll for completion

Deep Research takes 3-15 minutes. Use background sleep + check.

**First check**: 5 minutes after start.
**Subsequent checks**: every 5 minutes.
**Max checks**: 12 (~60 minutes total).

**Important**: Do NOT poll more frequently than every 5 minutes. Frequent polling
wastes context window and provides no benefit — Gemini's progress is slow and
incremental. A 5-minute interval balances responsiveness with efficiency.

**Single-timer rule**: Only ONE background sleep timer may be active at a time.
Wait for the previous timer's notification before launching the next one.

**No idle polling**: While a background timer is running, do NOT perform any
foreground status checks. Each API turn re-sends the full context (~60K cached
tokens). Wait for the timer notification, check once, then either extract the
report or launch one more timer.

```bash
# Run in background
sleep 120 && echo "ready"   # run_in_background for first check
sleep 600 && echo "ready"   # run_in_background for subsequent checks
```

When checking, use the tracked tab (NOT active tab — user may have switched):

```bash
osascript << EOF
tell application "Google Chrome"
    execute tab $GEMINI_TAB of window $GEMINI_WINDOW javascript "
        var text = document.body.innerText;
        var len = text.length;
        var hasExport = text.indexOf('Export') >= 0;
        var stillResearching = text.indexOf('Researching') >= 0 && text.indexOf('websites') >= 0;
        'len=' + len + ' export=' + hasExport + ' researching=' + stillResearching;
    "
end tell
EOF
```

**Completion indicators**:
- `hasExport = true` → report is done (Export button visible)
- `text.length > 10000` + `stillResearching = false` → report is done
- `stillResearching = true` → still in progress, report progress to user
- Same `text.length` for 3+ consecutive checks (~15 min) → **stalled**, trigger fallback (Step 5.1)

### Step 5.1: Stall detection and fallback

If `text.length` is unchanged for 3 consecutive checks (~15 min), Gemini is likely stuck
in its thinking loop without producing a final report. This happens especially with
complex cross-disciplinary queries that cause Gemini to browse 80+ websites.

**Fallback procedure:**
1. **First, try refreshing the page** — Gemini may have finished but the UI is stuck:
   ```bash
   osascript -e 'tell application "Google Chrome" to reload tab '"$GEMINI_TAB"' of window '"$GEMINI_WINDOW"'' 2>/dev/null
   sleep 5
   ```
   After refresh, check again for completion indicators (`Export` button, `Share & export`).
   If the report now appears, proceed to Step 6 extraction as normal.
2. If refresh doesn't help, extract all available content via JS chunk method (Method C in Step 6):
   ```bash
   > /tmp/gemini_report_raw.txt
   for i in 0 8000 16000 24000 32000 40000; do
     osascript -e "tell application \"Google Chrome\" to execute tab $GEMINI_TAB of window $GEMINI_WINDOW javascript \"document.body.innerText.substring($i, $((i+8000)))\"" >> /tmp/gemini_report_raw.txt
   done
   ```
3. The extracted content contains Gemini's thinking notes + browsed URLs — these are valuable even without a final report
4. Use `WebSearch` to supplement with targeted queries based on the thinking content and browsed URLs
5. Compile a manual report combining Gemini's browsed sources + web search results
6. Inform the user that Gemini stalled and the report was manually compiled

**If tab was lost** (window/tab index changed), find Gemini by scanning all windows/tabs:
```bash
osascript << 'EOF'
tell application "Google Chrome"
    set winCount to count of windows
    repeat with w from 1 to winCount
        set tabCount to count of tabs of window w
        repeat with i from 1 to tabCount
            if title of tab i of window w contains "Gemini" then
                return w & "-" & i
            end if
        end repeat
    end repeat
    return "not found"
end tell
EOF
```

### Step 6: Extract the report

Once complete, use Gemini's built-in "Copy contents" button to get clean report text.
This requires a **real mouse click** (CGEvent) — JS `.click()` does NOT work because
`navigator.clipboard.writeText()` requires a trusted user gesture.

Use the `wechat_tool` from the macos-automation plugin for real mouse clicks:

```bash
BIN=~/.claude/skills/wechat-control/bin
# If not available, use the full path:
# BIN=~/Developer/2026_Dev_Mnemex/02_Drafts/code/mnemex-plugins/plugins/macos-automation/skills/wechat-control/bin
```

#### Method A: OCR + real click (most reliable)

```bash
# 1. Activate Chrome and switch to Gemini tab
osascript -e 'tell application "Google Chrome" to activate' -e 'delay 0.3' \
  -e 'tell application "Google Chrome" to set active tab index of window 1 to '"$GEMINI_TAB" 2>/dev/null
sleep 0.5

# 2. Click "Share & Export" — get position via JS, click via CGEvent
POS=$(osascript -e '
tell application "Google Chrome"
    execute active tab of window 1 javascript "
        window.scrollTo(0, 0);
        var buttons = document.querySelectorAll(\"button\");
        for (var i = 0; i < buttons.length; i++) {
            if (buttons[i].textContent.trim() === \"Share & Export\") {
                var r = buttons[i].getBoundingClientRect();
                window.screenX + \"|\" + window.screenY + \"|\" + (window.outerHeight - window.innerHeight) + \"|\" + Math.round(r.x + r.width/2) + \"|\" + Math.round(r.y + r.height/2);
                break;
            }
        }
    "
end tell' 2>/dev/null)
IFS='|' read -r sX sY tH bX bY <<< "$POS"
$BIN/wechat_tool click $((sX + bX)) $((sY + tH + bY))
sleep 1.5

# 3. OCR-locate "Copy contents" in the dropdown and click it
$BIN/wechat_tool find-click "Copy contents" $((sX + bX - 100)),$((sY + tH + bY)),200,200
sleep 1.5

# 4. Save from clipboard
pbpaste > /tmp/gemini_report_raw.txt
```

#### Method B: JS select + Cmd+C (fallback, if wechat_tool unavailable)

```bash
osascript << EOF
tell application "Google Chrome"
    activate
    set active tab index of window $GEMINI_WINDOW to $GEMINI_TAB
    delay 0.5
    execute active tab of window $GEMINI_WINDOW javascript "
        var responses = document.querySelectorAll('.response-container-content, [class*=model-response], message-content');
        var target = null; var maxLen = 0;
        for (var i = 0; i < responses.length; i++) {
            if (responses[i].innerText.length > maxLen) { maxLen = responses[i].innerText.length; target = responses[i]; }
        }
        if (target) {
            var range = document.createRange();
            range.selectNodeContents(target);
            var sel = window.getSelection();
            sel.removeAllRanges();
            sel.addRange(range);
        }
    "
end tell
delay 0.3
tell application "System Events"
    keystroke "c" using command down
end tell
delay 0.5
EOF
pbpaste > /tmp/gemini_report_raw.txt
```

#### Why two methods?

| Method | Pros | Cons |
|--------|------|------|
| **A: Copy contents** | Clean output, no UI artifacts | Needs `wechat_tool` for real mouse click |
| **B: JS select + Cmd+C** | Works without extra tools | May include some extra text from response container |

Both produce ~40-50KB of clean report content. Method A is preferred when available.

#### Method C: JS chunk extraction (fallback for partial/stuck reports)

When Gemini is stuck (Step 5.1) or Methods A/B fail to capture full content, extract
the page text in 8KB chunks via JS. This reliably captures thinking notes, browsed
URLs, and any partial report — even when CSS selectors in Method B miss the Deep
Research thinking panel.

```bash
> /tmp/gemini_report_raw.txt
for i in 0 8000 16000 24000 32000 40000; do
  osascript -e "tell application \"Google Chrome\" to execute tab $GEMINI_TAB of window $GEMINI_WINDOW javascript \"document.body.innerText.substring($i, $((i+8000)))\"" >> /tmp/gemini_report_raw.txt
done
wc -c /tmp/gemini_report_raw.txt
```

**Why this works when Method B fails**: Method B's CSS selectors
(`.response-container-content`, `[class*=model-response]`) don't match the Deep
Research thinking panel. `document.body.innerText` captures everything visible on the
page regardless of DOM structure.

### Step 7: Clean up and save as Markdown

Process the raw text into structured Markdown:

1. **Strip UI artifacts**: Remove sidebar text (chat history, gem names), navigation buttons,
   "Opens in a new window" lines, "Gemini is AI and can make mistakes" footer
2. **Identify the report body**: Starts after "Gemini said" / research completion marker,
   ends before the Sources list
3. **Preserve structure**: The report already uses heading hierarchy — convert to Markdown
   headings (# for title, ## for sections, ### for subsections)
4. **Preserve tables**: Convert any tabular data to Markdown tables
5. **Extract sources**: Collect all URLs and source titles from the Sources section
6. **Add metadata header**

Save location: user-specified path, or default to `~/Documents/30_Resources/`
Filename format: `YYYY-MM-DD_research_topic-slug.md`

```markdown
---
source: Gemini Deep Research
date: YYYY-MM-DD
query: "the original research question"
---

# [Report Title]

[Report content with original structure preserved]

## Sources

- [Source Title](URL)
- ...
```

## Edge Cases

- **Login required**: If page shows login, tell user to log in manually and retry
- **Quota exceeded**: Inform user and suggest waiting
- **Tab lost during polling**: Scan all windows/tabs for "Gemini" in title
- **Very long reports (>50KB)**: The Select All + Copy approach handles this well
- **Research fails mid-way**: Capture error text and report to user
- **Multiple Gemini tabs**: Track the specific tab index opened in Step 1
