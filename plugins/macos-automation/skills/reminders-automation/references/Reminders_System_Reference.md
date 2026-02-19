# Reminders System Reference

**Last Updated:** 2025-12-21
**Platform:** macOS Sequoia (15.x) and later

---

## I. Core Philosophy: Task as Data (TaD)

Under this protocol, a reminder is not merely a task; it is a structured
data record stored in a temporal database.
This approach enables systematic task management, priority tracking,
and integration with the broader Digital Life System.

---

## II. List Segmentation

Utilize distinct lists for separation of concerns.

| List | Purpose | Example Tasks |
|------|---------|---------------|
| **Next Actions** | Immediate actionable tasks | Call lawyer, Submit form |
| **Reminders** | General tasks with due dates | Pay bill, Renew license |
| **Someday/Maybe** | Future possibilities | Learn piano, Visit Japan |
| **Shopping** | Purchase items | Groceries, Electronics |
| **等待清单** | Waiting on others | Pending responses, Delegated tasks |

---

## III. Field Schema

### Reminder Properties

| Property | Type | Description |
|----------|------|-------------|
| `name` | text | Task title (required) |
| `body` | text | Notes/details (optional) |
| `due date` | date | When the task is due |
| `allday due date` | date | All-day due date |
| `remind me date` | date | When to trigger notification |
| `priority` | integer | 0 (none), 1 (high), 5 (medium), 9 (low) |
| `flagged` | boolean | Flag status |
| `completed` | boolean | Completion status |
| `completion date` | date | When completed (read-only) |
| `creation date` | date | When created (read-only) |
| `modification date` | date | Last modified (read-only) |
| `id` | text | Unique identifier (read-only) |
| `container` | list | Parent list reference |

### 1. `name` (Text)

**Format:** `[Project_ID] Action_Verb - Specific_Task`

- **Goal:** Instant visual scanning and grep-friendly parsing.
- **Project_ID:** Must match the directory name in your file system (Vault).
- **Examples:**
  - `[Landlord_Case] Call - Schedule mediation session`
  - `[CS301] Submit - Assignment 4`
  - `[health] Book - Dentist appointment`

### 2. `body` (Text / YAML)

Use **YAML Front Matter** for machine-readable metadata, followed by free text.

```yaml
---
type: # (action | waiting | reference | deadline)
tags: [ # tag1, tag2, tag3 ]
context: # (@home | @office | @errands | @phone | @computer)
energy: # (high | medium | low)
time_required: # (5m | 15m | 30m | 1h | 2h+)
---
Notes:
- [Key detail 1]
- [Key detail 2]
```

### 3. Priority Values

| Value | Label | Visual | Use Case |
|-------|-------|--------|----------|
| 0 | None | No indicator | Default tasks |
| 1 | High | `!!!` | Urgent/Critical |
| 5 | Medium | `!!` | Important but not urgent |
| 9 | Low | `!` | Nice to have |

---

## IV. Controlled Vocabulary

Adhere to a strict keyword set for `Project_ID` and `tags`.

### GTD Contexts

- **@home** - Tasks requiring home location
- **@office** - Tasks requiring office/work location
- **@errands** - Tasks while out and about
- **@phone** - Phone calls
- **@computer** - Computer-based tasks
- **@waiting** - Delegated or pending tasks

### Project IDs by Domain

Align with `10_Projects` directory naming and Calendar segmentation:

#### Research

- **Projects**: `LLM_benchmark`, `NeurIPS_submission`, `survey_paper`, `open_source_tool`
- **Tags**: `writing`, `derivation`, `proof`, `lit_review`, `latex`, `experiment`

#### Development

- **Projects**: `mineflayer_bot`, `moral-sim`, `infra_setup`, `home_lab`
- **Tags**: `python`, `debugging`, `refactoring`, `networking`, `benchmarking`, `deploy`

#### Academic

- **Projects**: `CS301`, `MATH201`, `PHYS101`, `ENG102`, `StateU_MS`
- **Tags**: `homework`, `lecture`, `exam`, `study`, `group_project`

#### Life/Admin

- **Projects**: `family_admin`, `Landlord_Case`, `finance`, `health`, `car`, `home`
- **Tags**: `legal`, `call`, `email`, `maintenance`, `commute`, `medical`, `shopping`

---

## V. AppleScript CRUD Operations

All four operations work natively on macOS Sequoia.

| Operation | Status | Notes |
|-----------|--------|-------|
| Create | Full support | Use `make new reminder with properties` |
| Read | Full support | Query by ID, name, or properties |
| Update | Full support | Use `set` command on reminder properties |
| Delete | Full support | Use `delete` command |

**Note:** The `whose` clause can timeout on large lists. Prefer ID-based access
for reliability.

---

## VI. CREATE: Make New Reminder

### Basic Reminder

```applescript
with timeout of 15 seconds
    tell application "Reminders"
        tell list "Reminders"
            set r to make new reminder with properties {¬
                name:"[Project] Task description"¬
            }
            return id of r
        end tell
    end tell
end timeout
```

### Full Properties Reminder

```applescript
with timeout of 15 seconds
    tell application "Reminders"
        -- Calculate dates
        set theDueDate to (current date) + (1 * days)
        set hours of theDueDate to 14
        set minutes of theDueDate to 0
        set seconds of theDueDate to 0

        -- Remind 30 minutes before due
        set theRemindDate to theDueDate - (30 * minutes)

        tell list "Reminders"
            set r to make new reminder with properties {¬
                name:"[Landlord_Case] Call - Schedule mediation session", ¬
                body:"---
type: action
tags: [legal, phone]
context: @phone
energy: medium
time_required: 15m
---
Notes:
- Contact CCR for available dates
- Confirm with opposing party availability", ¬
                due date:theDueDate, ¬
                remind me date:theRemindDate, ¬
                priority:1, ¬
                flagged:true¬
            }
            return id of r
        end tell
    end tell
end timeout
```

### All-Day Reminder

```applescript
with timeout of 15 seconds
    tell application "Reminders"
        set theDueDate to (current date) + (2 * days)
        set hours of theDueDate to 0
        set minutes of theDueDate to 0
        set seconds of theDueDate to 0

        tell list "Reminders"
            set r to make new reminder with properties {¬
                name:"[health] Annual checkup due", ¬
                allday due date:theDueDate¬
            }
            return id of r
        end tell
    end tell
end timeout
```

### Create Then Set Properties

Alternative pattern for adding properties after creation:

```applescript
with timeout of 15 seconds
    tell application "Reminders"
        tell list "Reminders"
            set r to make new reminder with properties {¬
                name:"[finance] Review monthly statements"¬
            }
            set body of r to "Check for unusual charges"
            set priority of r to 5
            set flagged of r to false
        end tell
    end tell
end timeout
```

---

## VII. READ: Locate Reminders

### By Unique ID (Most Reliable)

```applescript
tell application "Reminders"
    tell list "Reminders"
        set r to reminder id "x-apple-reminder://E9805061-DA3F-424B-BF7A-6651ADD7867E"
        return {name:name of r, priority:priority of r}
    end tell
end tell
```

### By Name Pattern

```applescript
tell application "Reminders"
    tell list "Reminders"
        first reminder whose name contains "[Landlord_Case]"
    end tell
end tell
```

### By Completion Status

```applescript
tell application "Reminders"
    tell list "Reminders"
        set incompleteReminders to every reminder whose completed is false
        return "Found " & (count of incompleteReminders) & " incomplete reminders"
    end tell
end tell
```

### By Flagged Status

```applescript
tell application "Reminders"
    tell list "Reminders"
        set flaggedReminders to every reminder whose flagged is true
        return "Found " & (count of flaggedReminders) & " flagged reminders"
    end tell
end tell
```

### List All Lists

```applescript
tell application "Reminders"
    name of every list
end tell
-- Result: {"Reminders", "Shopping", "Next Actions", ...}
```

### Get List Properties

```applescript
tell application "Reminders"
    set theList to list "Reminders"
    return {name:name of theList, id:id of theList, color:color of theList}
end tell
```

### Get Reminder Properties

```applescript
tell application "Reminders"
    tell list "Reminders"
        set r to reminder 1
        return {¬
            name:name of r, ¬
            body:body of r, ¬
            priority:priority of r, ¬
            flagged:flagged of r, ¬
            completed:completed of r, ¬
            due date:due date of r, ¬
            remind me date:remind me date of r¬
        }
    end tell
end tell
```

---

## VIII. UPDATE: Modify Reminder

### Update Single Property

```applescript
with timeout of 15 seconds
    tell application "Reminders"
        tell list "Reminders"
            set r to reminder id "x-apple-reminder://..."
            set name of r to "[Landlord_Case] Updated task description"
        end tell
    end tell
end timeout
```

### Update Priority

```applescript
with timeout of 15 seconds
    tell application "Reminders"
        tell list "Reminders"
            set r to reminder id "x-apple-reminder://..."
            set priority of r to 1  -- High priority
        end tell
    end tell
end timeout
```

### Mark as Completed

```applescript
with timeout of 15 seconds
    tell application "Reminders"
        tell list "Reminders"
            set r to first reminder whose name contains "[Project]"
            set completed of r to true
            return {completed:completed of r, completion_date:completion date of r}
        end tell
    end tell
end timeout
```

### Update Due Date

```applescript
with timeout of 15 seconds
    tell application "Reminders"
        tell list "Reminders"
            set r to reminder id "x-apple-reminder://..."

            -- Calculate new due date
            set newDueDate to (current date) + (7 * days)
            set hours of newDueDate to 17
            set minutes of newDueDate to 0

            set due date of r to newDueDate
        end tell
    end tell
end timeout
```

### Update Remind Me Date

```applescript
with timeout of 15 seconds
    tell application "Reminders"
        tell list "Reminders"
            set r to reminder id "x-apple-reminder://..."

            set newRemindDate to (current date) + (1 * days)
            set hours of newRemindDate to 9
            set minutes of newRemindDate to 30

            set remind me date of r to newRemindDate
        end tell
    end tell
end timeout
```

---

## IX. DELETE: Remove Reminder

### Delete by ID

```applescript
with timeout of 15 seconds
    tell application "Reminders"
        tell list "Reminders"
            delete reminder id "x-apple-reminder://..."
        end tell
    end tell
end timeout
```

### Delete by Name Pattern (Inline)

```applescript
with timeout of 15 seconds
    tell application "Reminders"
        tell list "Reminders"
            delete (first reminder whose name contains "[TEST]")
        end tell
    end tell
end timeout
```

### Delete Multiple Reminders

```applescript
with timeout of 30 seconds
    tell application "Reminders"
        tell list "Reminders"
            set targetReminders to every reminder whose name contains "[OLD]"
            repeat with r in targetReminders
                delete r
            end repeat
            return "Deleted reminders"
        end tell
    end tell
end timeout
```

### Delete Completed Reminders

```applescript
with timeout of 30 seconds
    tell application "Reminders"
        tell list "Reminders"
            set completedReminders to every reminder whose completed is true
            repeat with r in completedReminders
                delete r
            end repeat
        end tell
    end tell
end timeout
```

---

## X. List Management

### Create New List

```applescript
with timeout of 15 seconds
    tell application "Reminders"
        set newList to make new list with properties {name:"My New List"}
        return {name:name of newList, id:id of newList}
    end tell
end timeout
```

### Delete List

```applescript
with timeout of 15 seconds
    tell application "Reminders"
        delete list "My New List"
    end tell
end timeout
```

### Move Reminder Between Lists

**Important:** Use the `move` command, not `set container`.

```applescript
with timeout of 15 seconds
    tell application "Reminders"
        set sourceList to list "Shopping"
        set destList to list "Reminders"
        set r to first reminder of sourceList whose name contains "[Item]"
        move r to destList
    end tell
end timeout
```

### Get Account Information

```applescript
tell application "Reminders"
    set accountNames to name of every account
    return accountNames
end tell
-- Result: {"iCloud"}
```

---

## XI. Date Manipulations

```applescript
-- Current date/time
set now to current date

-- Tomorrow at 9am
set tomorrow to (current date) + (1 * days)
set hours of tomorrow to 9
set minutes of tomorrow to 0
set seconds of tomorrow to 0

-- Next Monday at 9am
set nextMonday to current date
repeat until weekday of nextMonday is Monday
    set nextMonday to nextMonday + (1 * days)
end repeat
set hours of nextMonday to 9
set minutes of nextMonday to 0
set seconds of nextMonday to 0

-- Add durations
set laterTime to now + (30 * minutes)
set laterTime to now + (2 * hours)
set laterTime to now + (7 * days)

-- Reminder alarm (30 minutes before due)
set reminderTime to dueDate - (30 * minutes)
```

---

## XII. Example Record

**List:** Reminders

| Property | Value |
|----------|-------|
| **Name** | `[Landlord_Case] Call - Schedule mediation session` |
| **Due Date** | `2025-12-22 14:00:00` |
| **Remind Me Date** | `2025-12-22 13:30:00` |
| **Priority** | `1` (High) |
| **Flagged** | `true` |

**Body Field:**

```yaml
---
type: action
tags: [legal, phone]
context: @phone
energy: medium
time_required: 15m
---
Notes:
- Contact CCR for available dates
- Confirm with opposing party availability
```

---

## XIII. Logging Best Practice

Always include detailed logging with error handling:

```applescript
with timeout of 15 seconds
    tell application "Reminders"
        tell list "Reminders"
            set logOutput to "=== Reminders Operation ===" & return
            set logOutput to logOutput & "Timestamp: " & (current date) & return
            set logOutput to logOutput & "List: Reminders" & return

            try
                set r to make new reminder with properties {¬
                    name:"[Project] New task", ¬
                    priority:1¬
                }
                set logOutput to logOutput & "Action: CREATE" & return
                set logOutput to logOutput & "Reminder: " & name of r & return
                set logOutput to logOutput & "ID: " & id of r & return
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

## XIV. Corner Cases

All tested on macOS Sequoia (Dec 2025):

| Corner Case | Result | Notes |
|-------------|--------|-------|
| Special characters (Unicode, emoji, CJK) | Works | 中文, 🎉, José all work |
| Very long text (4000+ chars) | Works | No length limit found |
| Empty body | Works | Returns `missing value` |
| Spaces-only name | Works | Trimmed to empty string |
| Past due dates | Works | Can create reminders with past dates |
| All-day reminder | Works | Use `allday due date` property |
| Update priority | Works | Values: 0, 1, 5, 9 |
| Complete/uncomplete | Works | Sets `completion date` automatically |
| Move between lists | Works | Use `move` command |
| Create new list | Works | `make new list` |
| Delete list | Works | `delete list` |
| Recurrence | Not available | Not exposed via AppleScript |
| Location-based reminders | Not available | Not exposed via AppleScript |
| Subtasks | Not available | Not exposed via AppleScript |
| Tags (native) | Not available | Use body field with YAML instead |

---

## XV. Limitations

The following Reminders features are **NOT** accessible via AppleScript:

1. **Recurrence Rules** - Cannot create or modify recurring reminders
2. **Location-Based Triggers** - Cannot set geofence reminders
3. **Subtasks** - Cannot create or manage hierarchical tasks
4. **Native Tags** - Cannot access the built-in tagging system
5. **Images/Attachments** - Cannot add or read attachments
6. **URL Field** - Not available (unlike Calendar)
7. **Messaging Trigger** - Cannot set "when messaging" triggers

**Workarounds:**
- Use the `body` field with YAML for tags and metadata
- Create recurring reminders manually in the Reminders app
- Use Shortcuts.app for more advanced automation

---

## XVI. Troubleshooting

| Issue | Solution |
|-------|----------|
| AppleEvent timed out (-1712) | Restart Reminders app; use shorter queries |
| "whose" clause slow | Use ID-based access for reliability |
| Property not found | Check available properties list (Section III) |
| Can't set container | Use `move` command instead |
| Changes not persisting | Ensure modifying the reminder object, not a copy |
| Empty name created | Spaces-only names are trimmed to empty |

### Timeout Protection

Always use dual timeout protection:

- AppleScript internal: `with timeout of 15 seconds`
- Bash external: 20 second timeout (buffer for script overhead)

```bash
# From command line with timeout
osascript -e 'with timeout of 15 seconds
    tell application "Reminders"
        -- code here
    end tell
end timeout'
```

### Restart Reminders App

If the app becomes unresponsive:

```applescript
tell application "Reminders" to quit
delay 3
tell application "Reminders" to activate
delay 5
```

---

## XVII. Performance Notes

### Benchmark Results (macOS Sequoia, Jan 2026)

**Test Environment:** Lists with 1-343 items, each test run 3x, fresh restart between test groups.

#### Fresh State Performance (after restart)

| Operation | List Size | Time | Notes |
|-----------|-----------|------|-------|
| `reminder 1` (index) | 343 | 0.21-0.28s | **Fastest, stable** |
| `reminder 100` (index) | 343 | 0.20-0.21s | Position-independent |
| `reminder 340` (index) | 343 | 0.21-0.28s | Position-independent |
| `every reminder` | 343 | 0.19-0.21s | Fast bulk fetch |
| `whose name is` | 343 | 3.0-3.1s | Stable, 10x slower than index |
| `whose name contains` | 343 | 2.9-3.5s | Similar to `is` when fresh |
| `whose name contains` | 101 | 3.9-4.2s | Scales with size |
| `whose name contains` | 3 | 0.7-0.8s | Fast on tiny lists |
| `reminder id "xxx"` | 343 | 0.14-9.7s | **Highly variable, cache-dependent** |

#### Degradation Over Time (Critical Finding)

`whose name contains` degrades with consecutive operations:

| Run | Time | Status |
|-----|------|--------|
| 1-6 | 2.8-3.1s | Normal |
| 7 | 7.76s | Degrading |
| 9-10 | 11.4-11.7s | **Near timeout** |

After restart: back to 3.1-3.5s (recovered).

### Key Findings (Corrected)

1. **Index access is true O(1)**: `reminder N` is ~0.25s regardless of list size or position

2. **`whose name is` ≈ `whose name contains` when fresh**: Both ~3s on 343 items
   - Previous claim that `contains` is 5x slower was **incorrect**
   - The slowdown was due to app degradation, not the operation itself

3. **The real performance killer is degradation**:
   - Reminders app has memory/cache issues
   - Performance degrades after 5-6 consecutive `whose` queries
   - Can go from 3s to 12s+ without restart

4. **ID-based access is unreliable**:
   - First access: 3-10s (cold)
   - Cached access: 0.14s (fast)
   - Not recommended as primary access method

5. **List size does affect `whose` queries**:
   - 3 items: 0.7-0.8s
   - 101 items: 3.9-4.2s
   - 343 items: 2.9-3.5s (fresh) → 11-12s (degraded)

### Best Practices

**DO:**

```applescript
-- 1. Use index access for single items
tell application "Reminders"
    tell list "Reminders"
        set r to reminder 1
        name of r
    end tell
end tell

-- 2. Fetch all and filter locally for searches
tell application "Reminders"
    tell list "Reminders"
        set allReminders to every reminder
        repeat with r in allReminders
            if name of r contains "keyword" then
                -- process r
            end if
        end repeat
    end tell
end tell
```

**DON'T:**

```applescript
-- Avoid consecutive whose queries (causes degradation)
repeat with keyword in keywordList
    first reminder whose name contains keyword  -- Will get slower each time!
end repeat
```

### Decision Tree

```
Single item access?
├─ Yes → Know the index?
│        ├─ Yes → Use `reminder N` (fastest)
│        └─ No  → Use `every reminder`, filter locally
└─ No (bulk operation)?
   ├─ One-time query → `whose` is OK
   └─ Multiple queries → Fetch all once, filter locally
                         OR restart app between batches
```

### Restart Protocol

**When to restart:**
- Before batch operations (5+ queries)
- When operations exceed 5s
- After any timeout error

**Bash (recommended):**

```bash
pkill -x Reminders; sleep 3; open -a Reminders; sleep 5
```

**AppleScript:**

```applescript
tell application "Reminders" to quit
delay 3
tell application "Reminders" to activate
delay 5
```

### Performance Summary Table

| Scenario | Recommended Method | Expected Time |
|----------|-------------------|---------------|
| Get item by position | `reminder N` | 0.2-0.3s |
| Get all items | `every reminder` | 0.2s |
| Find by exact name (one-time) | `whose name is` | 3s |
| Find by partial name (one-time) | `whose name contains` | 3s |
| Find multiple items | Fetch all + local filter | 0.2s + loop |
| Batch operations (5+) | Restart first, then operate | varies |

---

## XVIII. Sources

- [Apple Reminders Scripting Guide](https://developer.apple.com/library/archive/documentation/AppleApplications/Conceptual/RemindersScriptingGuide/)
- [MacScripter Forums](https://www.macscripter.net/)
- Tested on macOS Sequoia 15.x (December 2025)

---

## Changelog

| Date | Change |
|------|--------|
| 2025-12-21 | Created initial version with full CRUD testing |
| 2025-12-21 | Documented all available properties |
| 2025-12-21 | Added corner case testing results |
| 2025-12-21 | Added limitations and workarounds section |
| 2026-01-30 | Added comprehensive performance benchmarks (Section XVII) |
| 2026-01-30 | Added Project IDs by Domain to Controlled Vocabulary (Section IV) |
| 2026-01-30 | **Corrected** performance benchmarks after rigorous re-testing |
| 2026-01-30 | Added degradation findings: `whose` queries slow down over time |
| 2026-01-30 | Corrected: `whose is` ≈ `whose contains` when fresh (not 5x diff) |
