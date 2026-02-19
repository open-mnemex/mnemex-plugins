---
name: calendar-automation
description: |
  Automate Apple Calendar.app via AppleScript on macOS. Use proactively when user mentions:
  creating events, checking schedule, updating meetings, deleting appointments,
  setting reminders/alarms, recurring events, or any calendar-related task.
  Triggers: "schedule a meeting", "add to calendar", "create event", "block time",
  "check my calendar", "what's on my schedule", "move the meeting", "cancel appointment",
  "set up weekly standup", "remind me before".
---

# Calendar Automation

Create, read, update, and delete events in Apple Calendar.app using AppleScript.

## Quick Reference

### Create Event

```applescript
set theStartDate to (current date) + (1 * days)
set hours of theStartDate to 14
set minutes of theStartDate to 0
set seconds of theStartDate to 0
set theEndDate to theStartDate + (2 * hours)

with timeout of 15 seconds
    tell application "Calendar"
        tell calendar "Personal"
            set e to make new event with properties {¬
                summary:"Meeting title", ¬
                start date:theStartDate, ¬
                end date:theEndDate, ¬
                location:"123 Main St, City, CA 90000", ¬
                description:"Notes here"¬
            }
            return uid of e
        end tell
    end tell
end timeout
```

### Read Events

```applescript
-- List calendars
tell application "Calendar" to name of every calendar

-- Find by summary
tell application "Calendar"
    tell calendar "Personal"
        first event whose summary contains "Meeting"
    end tell
end tell

-- Today's events
set theStart to current date
set hours of theStart to 0
set minutes of theStart to 0
set seconds of theStart to 0
set theEnd to theStart + (1 * days) - 1

tell application "Calendar"
    tell calendar "Personal"
        every event where its start date >= theStart and end date <= theEnd
    end tell
end tell
```

### Update Event

```applescript
with timeout of 15 seconds
    tell application "Calendar"
        tell calendar "Personal"
            set e to first event whose summary contains "Meeting"
            set summary of e to "Updated title"
            set location of e to "New location"
            -- IMPORTANT: Update end date BEFORE start date
            set end date of e to newEndDate
            set start date of e to newStartDate
        end tell
    end tell
end timeout
```

### Delete Event

```applescript
with timeout of 15 seconds
    tell application "Calendar"
        tell calendar "Personal"
            delete (first event whose summary contains "Meeting")
        end tell
    end tell
end timeout
```

## Event Properties

| Property | Type | Notes |
|----------|------|-------|
| `summary` | text | Event title (required) |
| `start date` | date | Start datetime (required) |
| `end date` | date | End datetime (required) |
| `description` | text | Event notes |
| `location` | text | Standard street address for Maps integration (see Location Format section) |
| `url` | text | Link to related resource |
| `allday event` | boolean | Use this, not `isAllDay` |
| `uid` | text | Unique ID (read-only) |

## Date Calculations

```applescript
-- Tomorrow at 2pm
set d to (current date) + (1 * days)
set hours of d to 14
set minutes of d to 0
set seconds of d to 0

-- Next Monday at 9am
set nextMonday to current date
repeat until weekday of nextMonday is Monday
    set nextMonday to nextMonday + (1 * days)
end repeat
set hours of nextMonday to 9
set minutes of nextMonday to 0

-- Durations
set later to now + (30 * minutes)
set later to now + (2 * hours)
set later to now + (7 * days)
```

## Recurrence (RFC 5545)

```applescript
-- Weekly on Mon/Wed, 8 times
set recurrence of e to "FREQ=WEEKLY;BYDAY=MO,WE;COUNT=8"

-- First Monday of each month, 6 times
set recurrence of e to "FREQ=MONTHLY;BYDAY=1MO;COUNT=6"

-- Every 2 weeks until date
set recurrence of e to "FREQ=WEEKLY;INTERVAL=2;UNTIL=20261231T235959Z"
```

## Alarms

```applescript
tell e
    make new display alarm with properties {trigger interval:-15}  -- 15 min before
    make new mail alarm with properties {trigger interval:-60}     -- 1 hour before
end tell
```

## Critical Rules

1. **Always use timeout**: Wrap Calendar operations in `with timeout of 15 seconds`
2. **Update order**: Set `end date` BEFORE `start date` when rescheduling
3. **Delete syntax**: Use inline `delete (first event whose...)` to avoid variable errors
4. **Property name**: Use `allday event`, not `isAllDay`
5. **Bulk delete fails**: Delete events one at a time, not as a list
6. **Always list calendars first**: Run `tell application "Calendar" to name of every calendar`
   before assuming a calendar exists (e.g., "Personal" may not exist)
7. **No localized date strings**: Never use `date "2026年1月23日"` — set components separately

## Location Format (Apple Maps Integration)

Apple Calendar uses Apple Maps for location recognition.
To ensure the location shows a map preview and enables navigation:

**Required format**: `Street Number + Street Name, City, State ZIP`

| Format | Example | Recognized? |
|--------|---------|-------------|
| Standard address | `420 Westwood Plaza, Los Angeles, CA 90095` | ✅ Yes |
| Descriptive name | `UCLA Samueli School of Engineering, Los Angeles, CA` | ❌ No |
| Building only | `Boelter Hall` | ❌ No |
| Internal address | `7400 Boelter Hall` | ❌ No |

**For universities/campuses**: Buildings have two address systems:
- Internal: `Room# + Building Name` (for mail/internal navigation)
- Street: Standard address (for Apple Maps)

**Workflow to find standard address**:
1. Search: `[Building Name] street address`
2. Check official contact page for street address
3. Verify ZIP code is complete (e.g., `90095` not omitted)

## AoE (Anywhere on Earth) Time Zone

Academic deadlines often use AoE (UTC-12). Convert to local time before creating events.

**Conversion formula** (for Los Angeles):
- **PST (Nov–Mar)**: 23:59 AoE = **next day 03:59 PST** (+4 hours, +1 day)
- **PDT (Mar–Nov)**: 23:59 AoE = **next day 04:59 PDT** (+5 hours, +1 day)

**Example**: "Jan 28, 23:59 AoE" → Create event at **Jan 29, 03:59 PST**

```applescript
-- Convert "Jan 28, 23:59 AoE" to local time (PST)
set d to current date
set year of d to 2026
set month of d to 1
set day of d to 29      -- Next day
set hours of d to 3     -- 03:59 for PST (or 04:59 for PDT)
set minutes of d to 59
set seconds of d to 0
```

**Best practice**: Include original AoE time in event description for reference:
```
Original: Jan 28, 23:59 AoE (UTC-12)
Local: Jan 29, 03:59 PST
```

## Calendar Naming Convention

Follow the Event as Data (EaD) protocol when creating events:

**Summary format**: `[Project_ID] Action_Verb - Specific_Task`

Examples:
- `[CS301] Submit - Assignment 4`
- `[Landlord_Case] Call - Schedule mediation`
- `[mineflayer_bot] Debug - Pathfinding module`

**For detailed reference**: See [references/calendar_reference.md](references/calendar_reference.md).
