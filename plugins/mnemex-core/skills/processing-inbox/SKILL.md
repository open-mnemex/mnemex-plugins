---
name: processing-inbox
description: This skill should be used when the user wants to "process inbox",
  "file documents", "organize downloads", "archive PDFs", "process downloads",
  or needs to route files from ~/Downloads to the Digital Life System (00_Vault,
  10_Projects, 20_Areas, 30_Resources) following VNS naming conventions.
---

# Processing Inbox to Digital Life System

This skill provides the workflow for processing files from `~/Downloads` into the
Digital Life System, a structured document management architecture with strict
naming conventions and routing rules.

## Overview

The Digital Life System organizes files into four primary domains:

| Domain | Purpose | Example Content |
|--------|---------|-----------------|
| `00_Vault` | Immutable facts, evidence, SSOT | Receipts, IDs, Contracts, Tax Forms |
| `10_Projects` | Active work with deadlines | Course materials, Litigation files |
| `20_Areas` | Personal capabilities/systems | Notes, configs, skill development |
| `30_Resources` | External collected materials | Books, papers, course slides |

## When to Use This Skill

- User asks to "process inbox" or "file documents"
- User wants to organize files from Downloads
- User mentions archiving PDFs or receipts
- User needs to route a document to the correct domain
- User invokes the `/process-inbox` command

## Core Decision Algorithm

When processing a file, apply this decision tree:

1. **Is it Evidence or a Fact?** (Receipt, ID, Contract, Tax Form)
   - YES → `00_Vault` (Apply VNS naming)

2. **Is it for a Current Task with a deadline?** (Course work, litigation)
   - YES → `10_Projects`

3. **Is it my own creation / part of my skills?** (Personal notes, configs)
   - YES → `20_Areas`

4. **Is it external material I'm collecting?** (Books, papers, logos)
   - YES → `30_Resources`

## VNS Naming Convention (Vault Only)

**Format:** `YYYY-MM-DD_Category_Entity_description.ext`

**Rules:**
- **Date:** ISO 8601 format (YYYY-MM-DD)
- **Category:** From controlled vocabulary (see `~/Documents/CLAUDE.md` Section 3.B)
- **Entity:** Legal name in PascalCase (`Last_First`, not "Dad")
- **Description:** snake_case, concise
- **No spaces:** Use underscores only

**Common Categories:**

| Domain | Categories |
|--------|------------|
| Financial | `Invoice`, `Receipt`, `Statement`, `TaxForm` |
| Legal | `Contract`, `Notice`, `Evidence`, `Record`, `Application` |
| Medical | `Report`, `Prescription`, `Record` |
| Identity | `ID`, `Passport`, `Visa`, `Vital` |

## Processing Protocol

```text
FOR EACH FILE:
  1. ANALYZE   → Use pdf-analyzer agent to read and analyze PDF
  2. VALIDATE  → Confirm agent's recommendations (date, entity, category, path)
  3. DEDUP     → Check for duplicates in target folder AND search by identifiers
  4. MOVE      → Rename and relocate using recommended filename
  5. REPORT    → Confirm to user
```

### Duplicate Check (Step 3)

Before moving to Vault, MUST check for duplicates:

1. **Search target folder** by date + entity pattern
2. **Search entire Vault** by key identifiers (order #, case #, confirmation #)
3. **If duplicate found:** Compare and ask user; skip if identical
4. **If no duplicate:** Proceed to move

### PDF Analysis with Agent

Must use the **pdf-analyzer agent** (`~/Documents/.claude/agents/pdf-analyzer.md`) to analyze PDFs:

```
Task(subagent_type="pdf-analyzer", prompt="Analyze: /path/to/file.pdf")
```

The agent returns structured output with:
- Content summary (2-4 sentences)
- Extracted details (date, entity, amounts, reference numbers)
- VNS-compliant filename recommendation
- Recommended Vault path

**Skip-and-Ask Rule:** If uncertain about a file, skip it and continue.
Collect questions and ask at the end of processing.

## Key References

For detailed workflow steps, legal document guidelines, and lessons learned:
- **Workflow details:** [references/workflow.md](references/workflow.md)

For complete naming rules, directory structure, and controlled vocabulary:
- **System documentation:** `~/Documents/CLAUDE.md`

## Safety Rules

1. **NEVER delete files.** Never use `rm` command.
2. **Uncertain files** → Move to `~/Documents/__To_Review/`
3. **Secrets/credentials** → Warn user, do not commit to Vault

## Post-Processing Actions

After all files are processed:

1. **Ask collected questions** for skipped files
2. **Search for project linkages** using identifiers (case #, claim #, entity)
3. **Update filing records:**
   - Append to `20_Areas/00_Meta_System/Vault_Filing_Log.md`
   - Update project status in `10_Projects/README.md` if applicable
4. **Read personal context when needed:**
   - `10_Projects/README.md` for active project inventory
   - `00_Vault/README.md` for entity folder names and routing

## User Hints

The skill accepts optional hints via `$ARGUMENTS`:

| Hint Example | Meaning |
|--------------|---------|
| `for Doe_Jane medical` | Files belong to Doe_Jane, medical domain |
| `to 10_Projects/2025_Litigation_Landlord` | Route all files to specific project |
| `*.pdf only` | Only process PDF files |
| `entity:TangHuacong domain:Financial` | Pre-specify entity and domain |
