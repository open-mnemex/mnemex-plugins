---
name: reflection
description: >
  Post-task reflection that extracts lessons and applies them as
  persistent improvements. Use after completing a complex, multi-step
  task. Triggers: "/reflect", "reflect", "总结经验", "复盘".
---

# Reflection

After a complex task, review the conversation and produce actionable
improvements. Do NOT journal — every insight must result in a
concrete file edit.

## Workflow

### 1. Analyze the Session

Review the conversation and identify:

- **What went well** — efficient patterns worth repeating
- **What went wrong** — errors, wasted steps, wrong assumptions
- **What was discovered** — new facts about the codebase, tools,
  or user preferences

### 2. Classify Each Insight

Each insight belongs to exactly one target:

| Category | Target | When |
|----------|--------|------|
| **Skill improvement** | Edit the relevant `SKILL.md` | Workflow was incomplete, wrong, or could be more efficient |
| **System process** | Edit the relevant `CLAUDE.md` | A rule, convention, or SOP was missing or unclear |
| **General insight** | **Surface to user** | Patterns, preferences, or observations that don't belong in a skill or CLAUDE.md |

General insights must be explicitly presented to the user in the
report. Do NOT silently write them to memory files. Let the user
decide what to do with them.

### 3. Apply Changes

For each insight, **edit the target file directly**:

- **Skill**: Add/update workflow steps, guardrails, or examples
  in the SKILL.md body. If a new script or reference is needed,
  create it in the skill's `scripts/` or `references/` dir.
- **CLAUDE.md**: Add the rule or convention in the appropriate
  section. Keep it concise — one line per rule when possible.
- **General insight**: Do NOT write anywhere. Present in the
  report table with a clear description so the user can act on it.

### 4. Report

Print a summary table to the user:

```
| # | Insight | Action | File |
|---|---------|--------|------|
| 1 | ... | Updated workflow step 3 | latex/SKILL.md |
| 2 | ... | Added naming convention | memory/MEMORY.md |
```

## Rules

- **No empty reflections.** If nothing worth recording, say so and
  stop. Do not create placeholder entries.
- **No duplicates.** Read target files before writing. Update
  existing entries rather than appending redundant ones.
- **Atomic edits.** Each insight → one Edit. Do not rewrite
  entire files.
- **Never write to memory.** General insights go in the report
  for the user to see — not into memory files.
- **Confirm before editing.** Show proposed changes to skills or
  CLAUDE.md and ask the user to approve before writing.
