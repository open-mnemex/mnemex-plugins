---
name: mail-automation
description: |
  Automate Apple Mail.app via AppleScript on macOS. Use proactively when user mentions:
  checking email/inbox, sending messages, searching mail, reading attachments,
  organizing messages (flag, archive, delete), or any email-related task.
  Triggers: "check my email", "send email to", "find emails from", "unread count",
  "download attachments", "archive old emails", "flag important messages".
---

# Mail Automation

AppleScript automation for Mail.app on macOS Sequoia.

## Quick Reference

### Read Operations

```applescript
-- Unread count (unified inbox)
tell application "Mail" to unread count of inbox

-- List accounts
tell application "Mail" to name of every account

-- Search by sender
tell application "Mail"
    tell account "Google"
        tell mailbox "INBOX"
            every message whose sender contains "amazon"
        end tell
    end tell
end tell
```

### Send Message

```applescript
tell application "Mail"
    set msg to make new outgoing message with properties {visible:false, subject:"Subject", content:"Body text"}
    tell msg
        make new to recipient with properties {address:"user@example.com"}
    end tell
    send msg
end tell
```

### Move/Flag/Mark Read

```applescript
tell application "Mail"
    tell account "Google"
        tell mailbox "INBOX"
            set msg to first message
            set read status of msg to true
            set flagged status of msg to true
            move msg to mailbox "Archive" of account "Google"
        end tell
    end tell
end tell
```

### Save Attachment

```applescript
tell application "Mail"
    tell account "Google"
        tell mailbox "INBOX"
            set msg to first message
            set att to first mail attachment of msg
            save att in POSIX file "/Users/username/Downloads/" & name of att
        end tell
    end tell
end tell
```

## Required Patterns

### Always Use Timeout

```applescript
with timeout of 30 seconds
    tell application "Mail"
        -- code here
    end tell
end timeout
```

### From Bash (Double Timeout)

```bash
timeout 35 osascript -e 'with timeout of 30 seconds
    tell application "Mail"
        -- code here
    end tell
end timeout'
```

### Error Handling

```applescript
try
    -- operation
on error errMsg number errNum
    return "FAILED: " & errMsg & " (" & errNum & ")"
end try
```

## Standard Mailbox Names

| Provider | Inbox | Sent | Trash | Archive |
|----------|-------|------|-------|---------|
| iCloud | `INBOX` | `Sent Messages` | `Deleted Messages` | `Archive` |
| Gmail | `INBOX` | `Sent Mail` | `Trash` | `All Mail` |

## Limitations

- Cannot create mailboxes on iCloud/Gmail (use web interface)
- `MIME type` property fails (-10000 error) - skip it
- `redirect` and `synchronize` commands may hang - avoid them
- HTML content: use `source` property for raw MIME, `content` returns plain text only

## Full Reference

For complete API details, search patterns, and corner cases:
→ See [Mail_System_Reference.md](references/Mail_System_Reference.md)
