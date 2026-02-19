# Mail System Reference

**Last Updated:** 2026-01-21
**Platform:** macOS Sequoia (15.x) and later

---

## I. Core Philosophy: Inbox as Data Pipeline

Under this protocol, email is treated as a structured data flow:
incoming messages are processed, classified, and actioned systematically.
AppleScript provides programmatic CRUD access to Mail.app,
enabling automation of repetitive tasks and integration with other systems.

---

## II. Account and Mailbox Architecture

### Account Types

Mail.app supports multiple account types with varying AppleScript capabilities:

| Type | Mailbox Creation | Full CRUD | Notes |
|------|------------------|-----------|-------|
| iCloud | Limited | Yes | Mailbox creation may fail (-10000) |
| Google/Gmail | No | Yes | Uses Gmail labels as mailboxes |
| IMAP | Varies | Yes | Depends on server capabilities |
| Exchange | Limited | Yes | Corporate policy may restrict |

### Standard Mailboxes

| Mailbox | iCloud Name | Gmail Name |
|---------|-------------|------------|
| Inbox | `INBOX` | `INBOX` |
| Drafts | `Drafts` | `Drafts` |
| Sent | `Sent Messages` | `Sent Mail` |
| Trash | `Deleted Messages` | `Trash` |
| Junk | `Junk` | `Spam` |
| Archive | `Archive` | `All Mail` |
| Starred | N/A | `Starred` |

---

## III. Message Properties

### Core Properties

| Property | Type | Access | Description |
|----------|------|--------|-------------|
| `id` | integer | read-only | Unique message identifier |
| `subject` | text | read-only | Message subject line |
| `sender` | text | read-only | Sender address and name |
| `content` | text | read-only | Plain text body |
| `source` | text | read-only | Raw MIME source |
| `date received` | date | read-only | Receive timestamp |
| `date sent` | date | read-only | Send timestamp |
| `message size` | integer | read-only | Size in bytes |
| `all headers` | text | read-only | Complete header block |

### Status Properties (Read/Write)

| Property | Type | Description |
|----------|------|-------------|
| `read status` | boolean | Mark as read/unread |
| `flagged status` | boolean | Flag/unflag message |
| `junk mail status` | boolean | Mark as junk/not junk |
| `deleted status` | boolean | Deleted state (read-only) |

### Recipient Properties

| Property | Type | Description |
|----------|------|-------------|
| `to recipients` | list | Primary recipients |
| `cc recipients` | list | Carbon copy recipients |
| `bcc recipients` | list | Blind carbon copy recipients |

---

## IV. CRUD Operations Summary

| Operation | Status | Notes |
|-----------|--------|-------|
| Create (outgoing message) | Full support | `make new outgoing message` |
| Create (draft) | Full support | `save` after creating |
| Read (messages) | Full support | Query by mailbox, search by properties |
| Read (headers) | Full support | Individual headers or all headers |
| Update (read status) | Full support | `set read status of msg to true` |
| Update (flagged status) | Full support | `set flagged status of msg to true` |
| Update (junk status) | Full support | `set junk mail status of msg to true` |
| Move (between mailboxes) | Full support | `move msg to mailbox` |
| Delete | Full support | Moves to Trash |
| Reply/Forward | Full support | `reply msg`, `forward msg` |
| Send | Full support | `send msg` |
| Read attachments | Full support | `mail attachments of msg` |
| Save attachments | Full support | `save att in POSIX file path` |
| Add attachments | Full support | Via `content` object |

---

## V. READ Operations

### List All Accounts

```applescript
tell application "Mail"
    name of every account
end tell
-- Result: {"iCloud", "Google", "idountang@gmail.com", ...}
```

### Get Account Details

```applescript
tell application "Mail"
    repeat with acct in every account
        set acctName to name of acct
        set acctEmail to email addresses of acct
        -- Process each account
    end repeat
end tell
```

### List Mailboxes

```applescript
tell application "Mail"
    tell account "iCloud"
        name of every mailbox
    end tell
end tell
-- Result: {"Archive", "Notes", "INBOX", "Drafts", "Sent Messages", ...}
```

### Count Messages

```applescript
tell application "Mail"
    tell account "Google"
        tell mailbox "INBOX"
            count of messages
        end tell
    end tell
end tell
```

### Get Unread Count

```applescript
-- Unified inbox unread count
tell application "Mail"
    unread count of inbox
end tell

-- Per-account unread count
tell application "Mail"
    tell account "Google"
        tell mailbox "INBOX"
            count of (every message whose read status is false)
        end tell
    end tell
end tell
```

### Read Message Properties

```applescript
tell application "Mail"
    tell account "Google"
        tell mailbox "INBOX"
            set msg to first message
            set msgSubject to subject of msg
            set msgSender to sender of msg
            set msgDate to date received of msg
            set msgContent to content of msg
            set msgRead to read status of msg
            set msgFlagged to flagged status of msg
            set msgId to id of msg
        end tell
    end tell
end tell
```

### Read Recipients

```applescript
tell application "Mail"
    tell account "Google"
        tell mailbox "INBOX"
            set msg to first message
            repeat with r in to recipients of msg
                set recipAddr to address of r
                set recipName to name of r
            end repeat
        end tell
    end tell
end tell
```

### Read Individual Headers

```applescript
tell application "Mail"
    tell account "Google"
        tell mailbox "INBOX"
            set msg to first message
            set hdrs to headers of msg
            repeat with hdr in hdrs
                set hdrName to name of hdr
                set hdrContent to content of hdr
            end repeat
        end tell
    end tell
end tell
```

### Search by Subject

```applescript
tell application "Mail"
    tell account "Google"
        tell mailbox "INBOX"
            set matchingMsgs to every message whose subject contains "Invoice"
        end tell
    end tell
end tell
```

### Search by Sender

```applescript
tell application "Mail"
    tell account "Google"
        tell mailbox "INBOX"
            set amazonMsgs to every message whose sender contains "amazon"
        end tell
    end tell
end tell
```

### Search by Date Range

```applescript
set startDate to current date
set time of startDate to 0
set startDate to startDate - (7 * days)

tell application "Mail"
    tell account "Google"
        tell mailbox "INBOX"
            set recentMsgs to every message whose date received is greater than startDate
        end tell
    end tell
end tell
```

### Search All Accounts

```applescript
tell application "Mail"
    repeat with acct in every account
        try
            tell acct
                tell mailbox "INBOX"
                    set matches to every message whose subject contains "urgent"
                    -- Process matches
                end tell
            end tell
        end try
    end repeat
end tell
```

### Accumulate Results in Loop

Variables work normally inside `tell application` blocks without needing `my`:

```applescript
set resultText to ""

tell application "Mail"
    tell account "Google"
        tell mailbox "INBOX"
            set matches to every message whose sender contains "amazon"

            repeat with msg in matches
                set msgSubject to subject of msg
                -- Get date object first, then convert
                set dateObj to date received of msg
                set msgDate to short date string of dateObj
                set resultText to resultText & msgDate & " | " & msgSubject & linefeed
            end repeat
        end tell
    end tell
end tell

return resultText
```

**Note:** The `my` keyword is only required for:
1. **Calling script handlers** - `my handlerName()` (否则发送给目标 app)
2. **Standard Additions with app object parameters** - see next section

### Standard Additions Inside Tell Blocks

Some Standard Additions fail when their **parameter is an app object reference**:

```applescript
tell application "Mail"
    tell mailbox "INBOX" of account "Gmail"
        set msg to message 1

        -- ❌ FAILS: Parameter is app object reference (date received of msg)
        set d to short date string of (date received of msg)

        -- ✅ WORKS: First get value into local variable
        set dateObj to date received of msg
        set d to short date string of dateObj

        -- ✅ WORKS: Use coercion instead (simpler)
        set d to (date received of msg) as text

        -- ✅ WORKS: These don't take app object references
        set x to do shell script "echo hello"
        set now to current date
    end tell
end tell
```

**Rule:** When a Standard Addition takes an expression containing an app object
reference (like `date received of msg`), AppleScript evaluates the entire
expression in the app's context, which fails. Solutions:
1. **Separate operations:** Get value to local variable first, then use Standard Addition
2. **Use coercion:** `as text`, `as string` work directly on app objects

---

## VI. CREATE Operations

### Create New Message (Visible)

```applescript
tell application "Mail"
    set newMessage to make new outgoing message with properties {¬
        visible:true, ¬
        subject:"Meeting Tomorrow", ¬
        content:"Hi,

Let me know if you're available tomorrow at 2pm.

Best,
Daniel"}
    tell newMessage
        make new to recipient with properties {¬
            address:"colleague@example.com", ¬
            name:"John Doe"}
    end tell
end tell
```

### Create with CC and BCC

```applescript
tell application "Mail"
    set newMessage to make new outgoing message with properties {¬
        visible:false, ¬
        subject:"Project Update", ¬
        content:"Please see attached updates."}
    tell newMessage
        make new to recipient with properties {address:"team@example.com"}
        make new cc recipient with properties {address:"manager@example.com"}
        make new bcc recipient with properties {address:"archive@example.com"}
    end tell
end tell
```

### Create with Specific Sender

```applescript
tell application "Mail"
    set newMessage to make new outgoing message with properties {¬
        visible:false, ¬
        sender:"work@example.com", ¬
        subject:"From Work Account", ¬
        content:"Sent from work email."}
    tell newMessage
        make new to recipient with properties {address:"client@example.com"}
    end tell
end tell
```

### Create and Save as Draft

```applescript
tell application "Mail"
    set newMessage to make new outgoing message with properties {¬
        visible:false, ¬
        subject:"Draft for Review", ¬
        content:"This needs review before sending."}
    tell newMessage
        make new to recipient with properties {address:"reviewer@example.com"}
    end tell
    save newMessage
end tell
```

### Add Attachment

```applescript
tell application "Mail"
    set newMessage to make new outgoing message with properties {¬
        visible:true, ¬
        subject:"Document Attached", ¬
        content:"Please find the document attached."}
    tell newMessage
        make new to recipient with properties {address:"recipient@example.com"}
    end tell
    tell content of newMessage
        make new attachment with properties {¬
            file name:"/Users/username/Documents/report.pdf"¬
        } at after last paragraph
    end tell
end tell
```

### Add Multiple Attachments

```applescript
tell application "Mail"
    set newMessage to make new outgoing message with properties {¬
        visible:true, ¬
        subject:"Multiple Files Attached", ¬
        content:"Please find the documents attached."}
    tell newMessage
        make new to recipient with properties {address:"recipient@example.com"}
    end tell
    tell content of newMessage
        make new attachment with properties {¬
            file name:"/Users/username/Documents/file1.pdf"¬
        } at after last paragraph
        make new attachment with properties {¬
            file name:"/Users/username/Documents/file2.xlsx"¬
        } at after last paragraph
    end tell
end tell
```

### Send Message

```applescript
tell application "Mail"
    set newMessage to make new outgoing message with properties {¬
        visible:false, ¬
        subject:"Automated Report", ¬
        content:"Daily report attached."}
    tell newMessage
        make new to recipient with properties {address:"reports@example.com"}
    end tell
    send newMessage
end tell
```

---

## VII. UPDATE Operations

### Mark as Read/Unread

```applescript
tell application "Mail"
    tell account "Google"
        tell mailbox "INBOX"
            set msg to first message
            set read status of msg to true  -- Mark as read
            set read status of msg to false -- Mark as unread
        end tell
    end tell
end tell
```

### Mark All as Read

```applescript
tell application "Mail"
    tell account "Google"
        tell mailbox "INBOX"
            set unreadMsgs to every message whose read status is false
            repeat with msg in unreadMsgs
                set read status of msg to true
            end repeat
        end tell
    end tell
end tell
```

### Flag/Unflag Message

```applescript
tell application "Mail"
    tell account "Google"
        tell mailbox "INBOX"
            set msg to first message
            set flagged status of msg to true   -- Flag
            set flagged status of msg to false  -- Unflag
        end tell
    end tell
end tell
```

### Mark as Junk/Not Junk

```applescript
tell application "Mail"
    tell account "Google"
        tell mailbox "INBOX"
            set msg to first message
            set junk mail status of msg to true   -- Mark as junk
            set junk mail status of msg to false  -- Mark as not junk
        end tell
    end tell
end tell
```

### Move to Another Mailbox

```applescript
tell application "Mail"
    tell account "iCloud"
        set archiveBox to mailbox "Archive"
        tell mailbox "INBOX"
            set msg to first message
            move msg to archiveBox
        end tell
    end tell
end tell
```

### Move Between Accounts

```applescript
tell application "Mail"
    set destMailbox to mailbox "Archive" of account "iCloud"
    tell account "Google"
        tell mailbox "INBOX"
            set msg to first message
            move msg to destMailbox
        end tell
    end tell
end tell
```

---

## VIII. DELETE Operations

### Delete Single Message

```applescript
tell application "Mail"
    tell account "Google"
        tell mailbox "INBOX"
            set msg to first message whose subject contains "Spam"
            delete msg
        end tell
    end tell
end tell
```

### Delete with Existence Check

```applescript
tell application "Mail"
    tell account "Google"
        tell mailbox "INBOX"
            set matchingMsgs to every message whose subject contains "Newsletter"
            if (count of matchingMsgs) > 0 then
                repeat with msg in matchingMsgs
                    delete msg
                end repeat
            end if
        end tell
    end tell
end tell
```

### Empty Trash

```applescript
tell application "Mail"
    tell account "Google"
        tell mailbox "Trash"
            delete every message
        end tell
    end tell
end tell
```

---

## IX. Reply and Forward

### Reply to Message

```applescript
tell application "Mail"
    tell account "Google"
        tell mailbox "INBOX"
            set msg to first message
            set replyMsg to reply msg with opening window
            -- Modify reply content if needed
            -- set content of replyMsg to "Thank you for your message."
        end tell
    end tell
end tell
```

### Reply All

```applescript
tell application "Mail"
    tell account "Google"
        tell mailbox "INBOX"
            set msg to first message
            set replyMsg to reply msg with opening window and reply to all
        end tell
    end tell
end tell
```

### Forward Message

```applescript
tell application "Mail"
    tell account "Google"
        tell mailbox "INBOX"
            set msg to first message
            set fwdMsg to forward msg with opening window
            tell fwdMsg
                make new to recipient with properties {address:"forward@example.com"}
            end tell
        end tell
    end tell
end tell
```

### Reply Without Opening Window

```applescript
tell application "Mail"
    tell account "Google"
        tell mailbox "INBOX"
            set msg to first message
            set replyMsg to reply msg without opening window
            set content of replyMsg to "Thank you, I'll review this shortly."
            tell replyMsg
                make new to recipient with properties {address:"sender@example.com"}
            end tell
            send replyMsg
        end tell
    end tell
end tell
```

---

## X. Attachment Operations

Attachments can be read from received messages and added to outgoing messages.

### Attachment Properties

| Property | Type | Access | Notes |
|----------|------|--------|-------|
| `name` | text | read-only | Filename with extension |
| `file size` | integer | read-only | Size in bytes |
| `downloaded` | boolean | read-only | Whether fully downloaded |
| `MIME type` | text | read-only | **May fail** (-10000 error) |

### Find Messages with Attachments

```applescript
tell application "Mail"
    tell account "Google"
        tell mailbox "INBOX"
            repeat with i from 1 to 50
                set msg to message i
                set attCount to count of mail attachments of msg
                if attCount > 0 then
                    return {index:i, subject:subject of msg, attachments:attCount}
                end if
            end repeat
        end tell
    end tell
end tell
```

### Read Attachment Properties

```applescript
tell application "Mail"
    tell account "Google"
        tell mailbox "INBOX"
            set msg to first message
            set att to first mail attachment of msg

            -- These properties work reliably
            set attName to name of att
            set attSize to file size of att
            set isDownloaded to downloaded of att

            return {name:attName, size:attSize, downloaded:isDownloaded}
        end tell
    end tell
end tell
```

### Save Attachment to Disk

```applescript
tell application "Mail"
    tell account "Google"
        tell mailbox "INBOX"
            set msg to first message
            set att to first mail attachment of msg
            set attName to name of att

            -- Save to specific path
            set savePath to "/Users/username/Downloads/" & attName
            save att in POSIX file savePath

            return "Saved to: " & savePath
        end tell
    end tell
end tell
```

### Save All Attachments from Message

```applescript
tell application "Mail"
    tell account "Google"
        tell mailbox "INBOX"
            set msg to first message whose subject contains "Invoice"
            set saveFolder to "/Users/username/Downloads/"
            set savedFiles to {}

            repeat with att in mail attachments of msg
                set attName to name of att
                set savePath to saveFolder & attName
                save att in POSIX file savePath
                set end of savedFiles to attName
            end repeat

            return savedFiles
        end tell
    end tell
end tell
```

### Batch Download Attachments by Sender

```applescript
tell application "Mail"
    tell account "Google"
        tell mailbox "INBOX"
            set saveFolder to "/Users/username/Downloads/Invoices/"
            set invoiceMsgs to every message whose sender contains "billing"

            repeat with msg in invoiceMsgs
                set attList to mail attachments of msg
                repeat with att in attList
                    if downloaded of att then
                        set attName to name of att
                        save att in POSIX file (saveFolder & attName)
                    end if
                end repeat
            end repeat
        end tell
    end tell
end tell
```

### Attachment Limitations

| Operation | Status | Notes |
|-----------|--------|-------|
| Read `name` | ✅ Works | Filename with extension |
| Read `file size` | ✅ Works | Size in bytes |
| Read `downloaded` | ✅ Works | Boolean status |
| Read `MIME type` | ❌ Fails | AppleEvent handler failed (-10000) |
| Save to disk | ✅ Works | Use `save att in POSIX file path` |
| Add to outgoing | ✅ Works | Via `content` object |
| Read from drafts | ⚠️ Partial | Only `name` property works |

---

## XI. Rules Management

### List All Rules

```applescript
tell application "Mail"
    name of every rule
end tell
```

### Get Rule Properties

```applescript
tell application "Mail"
    set r to first rule
    set ruleName to name of r
    set ruleEnabled to enabled of r
end tell
```

### Create Rule

```applescript
tell application "Mail"
    set newRule to make new rule with properties {¬
        name:"Archive Newsletters", ¬
        enabled:true}
    -- Note: Rule conditions and actions require additional configuration
end tell
```

### Delete Rule

```applescript
tell application "Mail"
    delete rule "Archive Newsletters"
end tell
```

### Enable/Disable Rule

```applescript
tell application "Mail"
    set enabled of rule "News From Apple" to false
end tell
```

---

## XII. Signatures

### List Signatures

```applescript
tell application "Mail"
    name of every signature
end tell
-- Result: {"Signature #1", "Signature #2", ...}
```

### Get Signature Content

```applescript
tell application "Mail"
    set sig to signature "Signature #1"
    set sigContent to content of sig
end tell
```

### Use Signature in Message

```applescript
tell application "Mail"
    set sig to signature "Signature #1"
    set newMessage to make new outgoing message with properties {¬
        visible:true, ¬
        subject:"Test", ¬
        content:"Message body here."}
    set message signature of newMessage to sig
end tell
```

---

## XIII. Account Operations

### Check for New Mail

```applescript
tell application "Mail"
    check for new mail
end tell
```

### Check Specific Account

```applescript
tell application "Mail"
    check for new mail for account "Google"
end tell
```

### Synchronize Account

**Note:** This command may hang in automation contexts.

```applescript
tell application "Mail"
    tell account "iCloud"
        synchronize
    end tell
end tell
```

---

## XIV. Date Manipulations

```applescript
-- Current date/time
set now to current date

-- Start of today
set todayStart to current date
set time of todayStart to 0

-- Last 7 days
set weekAgo to (current date) - (7 * days)

-- Last 30 days
set monthAgo to (current date) - (30 * days)

-- Specific date
set targetDate to date "December 1, 2025 at 12:00:00 AM"
```

---

## XV. Example: Process Inbox by Sender

```applescript
tell application "Mail"
    tell account "Google"
        tell mailbox "INBOX"
            -- Archive all Amazon notifications older than 7 days
            set archiveBox to mailbox "All Mail" of account "Google"
            set cutoffDate to (current date) - (7 * days)

            set amazonMsgs to every message whose ¬
                sender contains "amazon" and ¬
                date received is less than cutoffDate

            repeat with msg in amazonMsgs
                set read status of msg to true
                move msg to archiveBox
            end repeat

            return (count of amazonMsgs) & " messages archived"
        end tell
    end tell
end tell
```

---

## XVI. Example: Daily Email Report

```applescript
tell application "Mail"
    set reportText to "=== Daily Email Report ===" & return
    set reportText to reportText & "Generated: " & (current date) & return & return

    repeat with acct in every account
        set acctName to name of acct
        try
            tell acct
                tell mailbox "INBOX"
                    set totalCount to count of messages
                    set unreadCount to count of (every message whose read status is false)
                    set reportText to reportText & acctName & ": " & ¬
                        unreadCount & " unread / " & totalCount & " total" & return
                end tell
            end tell
        end try
    end repeat

    return reportText
end tell
```

---

## XVII. Corner Cases

All tested on macOS Sequoia (Dec 2025):

| Corner Case | Result | Notes |
|-------------|--------|-------|
| Special characters (Unicode, emoji, CJK) | Works | Subject and content support full Unicode |
| Very long content (6500+ chars) | Works | No length limit found |
| HTML content | Partial | `content` returns plain text only |
| Raw MIME source | Works | Use `source` property |
| Multiple attachments | Works | Iterate `mail attachments of msg` |
| Message by ID | Works | Use `message id <number>` |
| Nested mailboxes | Works | Use path: `mailbox "Parent/Child"` |
| Create mailbox (iCloud) | Fails | AppleEvent handler error (-10000) |
| Create mailbox (Gmail) | Fails | Labels managed via Gmail web |
| Redirect message | Hangs | Opens window requiring interaction |
| Synchronize account | Hangs | May block indefinitely |
| Bulk delete (list) | Works | Iterate and delete individually |
| Save attachment | Works | `save att in POSIX file path` |
| Attachment `name` | Works | Filename with extension |
| Attachment `file size` | Works | Size in bytes |
| Attachment `downloaded` | Works | Boolean status |
| Attachment `MIME type` | Fails | AppleEvent handler error (-10000) |
| Add attachment to outgoing | Works | Via `content` object |
| Attachment in draft | Partial | Only `name` property accessible |
| String concat in loop | Works | Variables work without `my` |
| List append in loop | Works | Variables work without `my` |
| Handler call in tell | Fails | Must use `my handlerName()` |
| `short date string of (app ref)` | Fails | Separate: get date first, then convert |
| `do shell script` in tell | Works | No `my` needed (no app ref parameter) |
| `current date` in tell | Works | No `my` needed (no app ref parameter) |
| Gmail message reference | Works | Messages stored in "All Mail", INBOX is view |

---

## XVIII. Troubleshooting

| Issue | Solution |
|-------|----------|
| "Can't get mailbox" | Check mailbox name matches exactly (case-sensitive) |
| "AppleEvent handler failed" | Operation not supported by account type |
| "doesn't understand message" (-1708) | Use `my handlerName()` for script handlers |
| "Can't make...into type specifier" (-1700) | Separate Standard Addition from app reference |
| Script hangs | Use `with timeout of 15 seconds` wrapper |
| No attachment content | Attachments may need to be downloaded first |
| Empty content | Message may be HTML-only; check `source` property |
| Wrong account for drafts | Drafts go to default account; specify sender |

### Timeout Protection

Always use timeout for Mail operations (Mail.app can be slow):

```applescript
with timeout of 30 seconds
    tell application "Mail"
        -- Your code here
    end tell
end timeout
```

---

## XIX. Integration Patterns

### With Calendar

```applescript
-- Create calendar event from email
tell application "Mail"
    tell account "Google"
        tell mailbox "INBOX"
            set msg to first message whose subject contains "Meeting"
            set meetingSubject to subject of msg
            set meetingSender to sender of msg
        end tell
    end tell
end tell

tell application "Calendar"
    tell calendar "Work"
        make new event with properties {¬
            summary:meetingSubject, ¬
            start date:(current date) + 1 * days, ¬
            end date:(current date) + 1 * days + 1 * hours, ¬
            description:"From: " & meetingSender}
    end tell
end tell
```

### With Reminders

```applescript
-- Create reminder from email
tell application "Mail"
    tell account "Google"
        tell mailbox "INBOX"
            set msg to first message whose flagged status is true
            set reminderTitle to "Follow up: " & subject of msg
        end tell
    end tell
end tell

tell application "Reminders"
    tell list "Inbox"
        make new reminder with properties {¬
            name:reminderTitle, ¬
            due date:(current date) + 1 * days}
    end tell
end tell
```

---

## XX. Sources

- [Apple Mail Scripting Guide](https://developer.apple.com/library/archive/documentation/AppleApplications/Conceptual/MailScriptingGuide/)
- [MacScripter Forums](https://www.macscripter.net/)
- AppleScript Language Guide

---

## Changelog

| Date | Change |
|------|--------|
| 2026-01-21 | Corrected: variables work without `my`; only handlers require it |
| 2026-01-21 | Clarified: Standard Additions fail only with app object ref params |
| 2026-01-20 | Added `short date string` workaround (separate ops or `as text`) |
| 2025-12-21 | Added Section X: Attachment Operations (read, save, add) |
| 2025-12-21 | Added attachment corner cases and limitations |
| 2025-12-20 | Created initial version with full CRUD documentation |
| 2025-12-20 | Added corner case testing results |
| 2025-12-20 | Added integration patterns with Calendar and Reminders |
