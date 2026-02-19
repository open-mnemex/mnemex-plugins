# Calendar System Reference

## Table of Contents

1. [Calendar Segmentation](#calendar-segmentation)
2. [Field Schema](#field-schema)
3. [Controlled Vocabulary](#controlled-vocabulary)
4. [Advanced Features](#advanced-features)
5. [Corner Cases](#corner-cases)
6. [Troubleshooting](#troubleshooting)

---

## Calendar Segmentation

Use four distinct calendars for separation of concerns:

| Calendar | Emoji | Color | Scope |
|----------|-------|-------|-------|
| **Research** | 🧪 | Red/Orange | Papers, experiments, heavy theory |
| **Development** | 💻 | Blue/Cyan | Coding, debugging, server maintenance |
| **Academic** | 🎓 | Green | Courses, admin, seminars, exams |
| **Life/Admin** | 🏠 | Yellow | Legal, family, housing, finance |

---

## Field Schema

### Summary Format

`[Project_ID] Action_Verb - Specific_Task`

- **Project_ID**: Must match directory name in file system
- **Goal**: Instant visual scanning and Regex-friendly parsing

Examples:
- `[lavicot] Debug - Redstone circuit pathfinding`
- `[IPT_paper] Draft - Methodology section rewrite`
- `[Landlord_Case] Review - Court hearing preparation`

### Description (YAML Front Matter)

Use YAML for machine-readable metadata:

```yaml
---
type: deep_work | shallow_work | meeting | logistics | deadline
tags: [tag1, tag2, tag3]
status: planned | in_progress | completed | migrated
priority: P0 | P1 | P2
energy: high | medium | low
inputs: Link to specs, emails, or raw data
outputs: Commit hash, file link, or decision made
---
Notes:
- Key decision or observation 1
- Key decision or observation 2
```

### Location Format

Use **Full US Standard Address Format** for maps and travel time estimation.
Do not use vague terms like "Office."

Format: `[Building/Room Name], [Street Number] [Street Name], [City], [State] [Zip]`

Examples:
- `Annenberg Center, Room 105, 1200 East California Boulevard, Pasadena, CA 91125`
- `Santa Monica Courthouse, 1725 Main Street, Santa Monica, CA 90401`

### URL Field

The "Source of Truth." Link to the most relevant context anchor:
- **Code**: GitHub Issue/PR URL
- **Papers**: Overleaf Read/Edit URL
- **Local**: `obsidian://open?vault=MyVault&file=Projects/TargetFile`

---

## Controlled Vocabulary

### Research Calendar

- **Projects**: `IPT_paper`, `CVPR2026_redstone`, `lavicot`
- **Tags**: `writing`, `derivation`, `proof`, `lit_review`, `latex`

### Development Calendar

- **Projects**: `mineflayer_bot`, `moral-sim`, `infra_setup`
- **Tags**: `python`, `debugging`, `refactoring`, `networking`, `benchmarking`

### Life/Admin Calendar

- **Projects**: `family_admin`, `landlord_case`, `finance`, `health`
- **Tags**: `legal`, `call`, `email`, `maintenance`, `commute`

---

## Advanced Features

### Attendees

```applescript
with timeout of 15 seconds
    tell application "Calendar"
        tell calendar "Life/Admin"
            set e to make new event with properties {¬
                summary:"[Landlord_Case] Meeting - Mediation session", ¬
                start date:startDate, ¬
                end date:endDate¬
            }
            tell e
                make new attendee with properties {¬
                    email:"mediator@ccr.org", ¬
                    display name:"CCR Mediator"¬
                }
            end tell
        end tell
    end tell
end timeout
```

### Excluded Dates

```applescript
set excludeDate to date "December 25, 2025 at 10:00:00 AM"
set e to make new event with properties {¬
    summary:"[Academic] Daily Standup", ¬
    start date:startDate, ¬
    end date:endDate, ¬
    recurrence:"FREQ=DAILY;COUNT=10", ¬
    excluded dates:{excludeDate}¬
}
```

### Delete Recurring Series

Clear recurrence rule first, then delete:

```applescript
with timeout of 15 seconds
    tell application "Calendar"
        tell calendar "Academic"
            set e to first event whose summary contains "[CS301] Lecture"
            set recurrence of e to ""
            delete e
        end tell
    end tell
end timeout
```

### Delete with Existence Check

```applescript
with timeout of 15 seconds
    tell application "Calendar"
        tell calendar "Life/Admin"
            set matchingEvents to every event whose summary contains "[Landlord_Case]"
            if (count of matchingEvents) > 0 then
                delete matchingEvents
            end if
        end tell
    end tell
end timeout
```

### Get Event Properties

```applescript
tell application "Calendar"
    tell calendar "Research"
        set e to first event where its summary contains "[CVPR2026]"
        set eventTitle to summary of e
        set eventStart to start date of e
        set eventEnd to end date of e
        set eventLocation to location of e
        set eventNotes to description of e
        set eventUID to uid of e
    end tell
end tell
```

### Logging Best Practice

```applescript
with timeout of 15 seconds
    tell application "Calendar"
        tell calendar "Research"
            set logOutput to "=== Calendar Operation ===" & return
            set logOutput to logOutput & "Timestamp: " & (current date) & return
            set logOutput to logOutput & "Calendar: Research" & return

            try
                set e to make new event with properties {¬
                    summary:"[CVPR2026] Analyze - Agent metrics", ¬
                    start date:theStartDate, ¬
                    end date:theEndDate¬
                }
                set logOutput to logOutput & "Action: CREATE" & return
                set logOutput to logOutput & "Event: " & summary of e & return
                set logOutput to logOutput & "UID: " & uid of e & return
                set logOutput to logOutput & "Status: SUCCESS" & return
            on error errMsg number errNum
                set logOutput to logOutput & "Status: FAILED" & return
                set logOutput to logOutput & "Error: " & errMsg & return
                set logOutput to logOutput & "Error Code: " & errNum & return
            end try

            return logOutput
        end tell
    end tell
end timeout
```

---

## Corner Cases

Tested on macOS Sequoia (Dec 2025):

| Corner Case | Result | Notes |
|-------------|--------|-------|
| Multi-day event (3+ days) | Works | Spans correctly across days |
| Special characters (Unicode, emoji, CJK) | Works | Jose, 中文, 🎉 all work |
| Midnight event (00:00) | Works | No edge case issues |
| Very long text (3900+ chars) | Works | No length limit found |
| Recurring event + alarm | Works | FREQ=WEEKLY;COUNT=4 syntax |
| Past events | Works | Can create events in the past |
| 1-minute event | Works | 60 second minimum |
| Zero-duration event | Works | start date = end date allowed |
| Update by UID | Works | Most reliable for duplicates |
| Complex recurrence (BYDAY) | Works | FREQ=WEEKLY;BYDAY=MO,WE;COUNT=8 |
| Excluded dates | Works | Exclude specific dates from series |
| Full address location | Works | Street, city, state, zip |
| Complex URL (query string) | Works | Preserves ?, &, %, # chars |
| Set event status | Fails | Read-only property |
| Delete single alarm | Fails | AppleEvent handler error |
| Bulk delete (list) | Fails | Delete one at a time instead |

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| "Variable not defined" on delete | Use inline: `delete (first event whose...)` |
| Property name error | Check dictionary; use `allday event` not `isAllDay` |
| Event not found | Use `exists` check before accessing |
| "Start date must be before end date" | Update `end date` BEFORE `start date` |
| Script hangs | Always use `with timeout of 15 seconds` |
| Changes not persisting | Ensure modifying the event object, not a copy |

### Timeout Protection

Always use dual timeout protection:
- AppleScript internal: `with timeout of 15 seconds`
- Bash external: 20 second timeout (buffer for script overhead)

```bash
timeout 20 osascript -e 'with timeout of 15 seconds
    tell application "Calendar"
        -- code here
    end tell
end timeout'
```
