---
name: reminders-automation
description: |
  Automate Apple Reminders.app via AppleScript on macOS. Use proactively when user mentions:
  creating tasks/reminders, checking todo lists, marking tasks complete, setting due dates,
  managing reminder lists, or any task management via Reminders.
  Triggers: "remind me to", "add a reminder", "create task", "check my reminders",
  "mark as done", "what's on my todo list", "set due date", "flag this task".
---

# Reminders Automation

Automate Apple Reminders.app via AppleScript on macOS Sequoia (15.x).

## Quick Reference

### List Names

| List | Purpose |
|------|---------|
| **Next Actions** | Immediate actionable tasks |
| **Reminders** | General tasks with due dates |
| **Someday/Maybe** | Future possibilities |
| **Shopping** | Purchase items |
| **等待清单** | Waiting on others |

### Priority Values

| Value | Meaning |
|-------|---------|
| 0 | None (default) |
| 1 | High (!!!) |
| 5 | Medium (!!) |
| 9 | Low (!) |

### Naming Convention

Format: `[Project_ID] Action_Verb - Specific_Task`

Examples:
- `[Landlord_Case] Call - Schedule mediation session`
- `[health] Book - Dentist appointment`

## Core Operations

**Always wrap in timeout:**

```applescript
with timeout of 15 seconds
    tell application "Reminders"
        -- operations here
    end tell
end timeout
```

### Create Reminder

```applescript
tell application "Reminders"
    tell list "Reminders"
        make new reminder with properties {name:"[Project] Task", priority:1}
    end tell
end tell
```

With due date (tomorrow 2pm):

```applescript
tell application "Reminders"
    set d to (current date) + 1 * days
    set hours of d to 14
    set minutes of d to 0
    set seconds of d to 0
    tell list "Reminders"
        make new reminder with properties {name:"Task", due date:d}
    end tell
end tell
```

### Read Reminders

```applescript
-- List all lists
tell application "Reminders" to name of every list

-- Count incomplete
tell application "Reminders"
    tell list "Reminders"
        count of (every reminder whose completed is false)
    end tell
end tell

-- Find by name pattern
tell application "Reminders"
    tell list "Reminders"
        first reminder whose name contains "[Project]"
    end tell
end tell
```

### Update Reminder

```applescript
tell application "Reminders"
    tell list "Reminders"
        set r to first reminder whose name contains "[Project]"
        set completed of r to true
        -- or: set priority of r to 1
        -- or: set due date of r to (current date) + 7 * days
    end tell
end tell
```

### Delete Reminder

```applescript
tell application "Reminders"
    tell list "Reminders"
        delete (first reminder whose name contains "[TEST]")
    end tell
end tell
```

### Move Between Lists

```applescript
tell application "Reminders"
    set r to first reminder of list "Shopping" whose name contains "Item"
    move r to list "Reminders"
end tell
```

## Date Patterns

```applescript
-- Tomorrow 9am
set d to (current date) + 1 * days
set hours of d to 9
set minutes of d to 0

-- Next Monday 9am
set d to current date
repeat until weekday of d is Monday
    set d to d + 1 * days
end repeat
set hours of d to 9

-- Remind 30 min before due
set remindDate to dueDate - 30 * minutes
```

## Limitations (Not Available via AppleScript)

- Recurrence rules
- Location-based triggers
- Subtasks
- Native tags (use body field with YAML instead)
- Images/attachments

## Full Reference

For complete documentation including YAML body format, error handling patterns,
corner cases, and all properties, see [references/Reminders_System_Reference.md](references/Reminders_System_Reference.md).
