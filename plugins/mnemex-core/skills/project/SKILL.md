---
name: project
description: |
  Project lifecycle management for Digital Life System.
  Commands: /project init, /project reorg, /project archive, /project link
  Triggers: "new project", "start project", "organize folder", "archive project",
  "link vault files", "init project", "create project"
---

# Project Lifecycle Management

Manage projects throughout their lifecycle: creation, reorganization, archival, and
Vault linkage.

## Commands

| Command | Description |
|---------|-------------|
| `/project init <keywords>` | Create new project from keywords |
| `/project reorg <path>` | Reorganize existing folder to project structure |
| `/project archive [name]` | Archive completed project |
| `/project link [name]` | Add/update Vault symlinks for project |

---

# `/project init <keywords>`

Create a new project from keywords (e.g., "CES 2026 Las Vegas", "sell MacBook").

## Input

User provides keywords only. Infer ALL details from context:

1. **Year**: Default to current year unless specified
2. **Category**: Infer from one of:
   - `Admin` - Paperwork, applications, renewals
   - `Sale` - Selling items (eBay, Craigslist, trade-in)
   - `Claim` - Insurance, disputes, refunds, chargebacks
   - `Dev` - Software development, personal projects
   - `Research` - Academic research, papers, experiments
   - `Creation` - Creative projects (video, writing, design)
   - `Travel` - Trips, events, conferences
   - `Litigation` - Legal cases, lawsuits
   - `Immigration` - Visa, status changes, green card
   - `Course` - Academic courses, online learning
3. **ProjectName**: Convert to `Snake_Case` (e.g., `CES_LasVegas`)
4. **Definition of Done**: Logical end state
5. **Deliverables**: Expected outputs

## Decision Gate

Validate silently (warn only if fails):
1. **Finite?** - If ongoing, suggest `20_Areas/` instead
2. **Complex?** - If trivial, suggest doing it directly without project overhead

## Execution

### 1. Create Structure

```bash
mkdir -p ~/Documents/10_Projects/YYYY_Category_ProjectName/{01_Input,02_Drafts,03_Output,99_Admin}
```

### 2. Create 00_PLAN.md

```markdown
# Project Plan: [Project Name]

**Created:** YYYY-MM-DD
**Status:** Active
**Tags:** #Category

---

## 1. Definition of Done (以终为始)
> [Inferred end state]

## 2. Deliverables (交付物)
- [ ] [Deliverable 1]
- [ ] [Deliverable 2]

## 3. Vault Linkage (事实链接)
> Files linked from 00_Vault (Use Symlinks `ln -s`)
-

## 4. Key Dates & Deadlines
| Date | Event |
|------|-------|
| YYYY-MM-DD | Project created |

## 5. Project Structure (项目结构)
```
YYYY_Category_ProjectName/
├── 00_PLAN.md
├── 01_Input/          # Source materials, references
├── 02_Drafts/         # Work in progress
├── 03_Output/         # Final deliverables
└── 99_Admin/          # Vault symlinks, admin files
```

## 6. Resources & References
-

## 7. Notes
-

## 8. Log & Next Actions (日志与行动)
- [ ] Project initialized @date(today)
```

### 3. Linkage Ritual

Search `~/Documents/00_Vault/` for relevant files (by date, entity, keywords).
If found, create symlinks in `99_Admin/`:

```bash
cd ~/Documents/10_Projects/YYYY_Category_ProjectName/99_Admin
ln -s "../../../00_Vault/path/to/file.pdf" .
```

Document links in 00_PLAN.md Section 3 (Vault Linkage).

### 4. Update Project Inventory

Add to Active Projects table in `~/Documents/10_Projects/README.md`:

```markdown
| `YYYY_Category_ProjectName/` | [Description] | Active |
```

## Output

Report:
1. Created structure (tree view)
2. Inferred details (Name, Category, Definition of Done, Deliverables)
3. Vault files linked (if any)
4. Suggested next actions

---

# `/project reorg <path>`

Reorganize an existing folder into standard project structure.

## Input

Path to existing folder (can be in Legacy, Downloads, or anywhere).

## Execution Flow

### 1. Analyze Folder Contents

- List all files with sizes and dates
- Use `pdf-analyzer` agent to read PDF contents
- Identify date range of materials
- Extract entities, keywords, case numbers

### 2. Infer Project Metadata

- **Year**: From earliest document date
- **Category**: From content analysis
- **ProjectName**: From dominant theme/entity
- **Status**: Infer if completed or still active

### 3. Ask User for Destination

Display project summary and ask:

```
Project Analysis:
- Date Range: YYYY-MM-DD to YYYY-MM-DD
- Category: [Inferred]
- Name: [Inferred]
- Files: N documents

Is this project ACTIVE or COMPLETED?
- Active → 10_Projects/
- Completed → 99_Archives/
```

### 4. Create Standard Structure

```bash
mkdir -p TARGET/YYYY_Category_ProjectName/{01_Input,02_Drafts,03_Output,99_Admin}
```

### 5. Categorize and Move Files

Sort files into appropriate subfolders:

| File Type | Destination |
|-----------|-------------|
| Source materials, references | `01_Input/` |
| Drafts, work-in-progress | `02_Drafts/` |
| Final outputs, deliverables | `03_Output/` |
| Admin files, receipts, correspondence | `99_Admin/` |

### 6. Rename Files to VNS Format

**Format:** `YYYY-MM-DD_Category_Entity_Description.ext`

**Rules:**
- Use document date (not file modification date)
- Category: Receipt, Invoice, Statement, Contract, Letter, Report, etc.
- Entity: Company or person name (PascalCase)
- Description: snake_case, concise

### 7. Check for Vault Duplicates

Compare files with Vault using MD5 hash:

```bash
md5 -q file.pdf
```

- If duplicate exists in Vault: Skip or create symlink
- If unique: Keep in project

### 8. Extract Vault-Worthy Files

Identify files that belong in Vault (official documents, receipts, legal):
- Move originals to appropriate Vault location
- Create symlinks back to project

### 9. Generate 00_PLAN.md

Include complete timeline and file inventory.

### 10. Handle Edge Cases

- **Misplaced files** (dates don't match): Flag for manual review
- **Duplicates within folder**: Keep newest, trash others
- **Unknown file types**: Move to `99_Admin/` for manual sorting

## Critical Rules

- NEVER use `rm` - always `mv` to Trash (`~/.Trash/`)
- Compare with Vault before creating duplicates
- Preserve original folder until reorg is verified

---

# `/project archive [name]`

Archive a completed project.

## Input

Project name (optional). If not provided, list projects for selection.

## Execution Flow

### 1. Select Project

If no name provided:

```
Active Projects:
1. 2025_Asset_Sale_Laptop/
2. 2025_Event_Travel_Conference/
3. 2026_Academic_StateU_CS301/

Select project to archive (number or name):
```

### 2. Verify Completion

Check 00_PLAN.md for:
- All deliverables marked complete
- Definition of Done achieved

If incomplete, warn user but allow override.

### 3. Update 00_PLAN.md

```markdown
**Status:** Archived
**Completed:** YYYY-MM-DD
```

Add final log entry:

```markdown
- [x] Project archived @date(today)
```

### 4. Move to Archives

```bash
mv ~/Documents/10_Projects/YYYY_Category_ProjectName/ ~/Documents/99_Archives/
```

### 5. Update Project Inventory

Remove from Active Projects table in `~/Documents/10_Projects/README.md`.
Update status to **Archived** if keeping the row.

## Preservation Policy

- Keep ALL files and folders intact
- Preserve ALL symlinks (they still work after move)
- Do NOT delete any content

---

# `/project link [name]`

Add or update Vault symlinks for a project.

## Input

Project name (optional). Defaults to current directory if in a project.

## Execution Flow

### 1. Identify Project

Determine project from:
- Explicit name argument
- Current working directory
- Interactive selection

### 2. Extract Search Terms

From 00_PLAN.md, extract:
- Date range (Key Dates section)
- Entity names
- Case numbers, claim numbers
- Keywords from Definition of Done

### 3. Search Vault

Search patterns:

```bash
# By entity
find ~/Documents/00_Vault -name "*EntityName*"

# By date range
find ~/Documents/00_Vault -name "YYYY-MM-*"

# By case number
grep -r "CaseNumber" ~/Documents/00_Vault --include="*.md"
```

### 4. Present Candidates

```
Found related files in Vault:

1. 00_Vault/03_Financial/Receipts/2025-01-15_Receipt_Apple_macbook_tradein.pdf
2. 00_Vault/04_Legal/Contracts/2025-01-10_Contract_Apple_device_agreement.pdf

Select files to link (comma-separated numbers, or 'all'):
```

### 5. Create Symlinks

```bash
cd ~/Documents/10_Projects/YYYY_Category_ProjectName/99_Admin
ln -s "../../../00_Vault/path/to/file.pdf" .
```

### 6. Update 00_PLAN.md

Add to Section 3 (Vault Linkage):

```markdown
## 3. Vault Linkage (事实链接)
- [2025-01-15_Receipt_Apple_macbook_tradein.pdf](../../../00_Vault/03_Financial/Receipts/...)
- [2025-01-10_Contract_Apple_device_agreement.pdf](../../../00_Vault/04_Legal/Contracts/...)
```

---

# Project Categories Reference

| Category | Description | Examples |
|----------|-------------|----------|
| Admin | Administrative tasks, applications | Passport renewal, license application |
| Sale | Selling items | MacBook trade-in, eBay listing |
| Claim | Claims, disputes, refunds | Insurance claim, credit card dispute |
| Dev | Software development | Personal app, open source contribution |
| Research | Academic research | Paper writing, experiments |
| Creation | Creative projects | Video production, writing, design |
| Travel | Trips, events, conferences | CES 2026, vacation planning |
| Litigation | Legal cases | Tenant dispute, lawsuit defense |
| Immigration | Visa and status | F1 application, green card |
| Course | Academic courses | StateU CS301, online certification |

---

# VNS Naming Convention (File Level)

**Format:** `YYYY-MM-DD_Category_Entity_Description.ext`

**Controlled Vocabulary (Category):**

| Domain | Categories |
|--------|------------|
| Identity | ID, Passport, Visa, Vital |
| Assets | Deed, Title, Registration, Warranty |
| Financial | Invoice (owed), Receipt (paid), Statement (log), TaxForm |
| Legal | Contract, Notice, Affidavit, Evidence, Letter, Response |
| Medical | Report, Prescription, Record |
| Personal | Letter, Diary, Note |

**Rules:**
- No spaces - use underscores `_`
- PascalCase for Category/Entity
- snake_case for Description
- Use document date, not file modification date
