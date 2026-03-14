---
name: project
description: |
  Project lifecycle management for Digital Life System.
  Commands: /project init, /project reorg, /project archive, /project link
  Triggers: "new project", "start project", "organize folder", "archive project",
  "link vault files", "init project", "create project"
  Triggers (中文): "新项目", "建项目", "整理项目", "重新整理",
  "归档项目", "项目初始化", "整理文件夹"
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

## Project Placement Rules

Projects are placed in one of two locations based on category:

| Category | Location | Reason |
|----------|----------|--------|
| `Research`, `Dev` | `~/Developer/` + symlink in `10_Projects/` | Git repos, heavy deps — keep off iCloud |
| All others | `~/Documents/10_Projects/` | Lightweight document projects — iCloud backup |

**Folder semantics (回到本质):**
- `01_Input/` — what comes in (reference material, read-only)
- `02_Drafts/` — what you create (your intellectual output)
- `03_Output/` — what goes out (final deliverables)
- `99_Admin/` — management overhead (meetings, correspondence,
  submission records — not input, not output, not the work itself)

**Developer-based projects** (Research/Dev):
- Body at `~/Developer/YYYY_Category_ProjectName/`
- Symlink from `~/Documents/10_Projects/YYYY_Category_ProjectName` → Developer path
- Auto `git init` on creation
- Get `_index.md` (pure topology file)
- `02_Drafts/` contains: `code/`, `notes/`, `writing/`,
  `experiments/`, `presentations/`
- `99_Admin/` contains: `meetings/`
- Vault symlinks use **absolute paths** (`~/Documents/00_Vault/...`)

**Document-based projects** (all others):
- Live directly in `~/Documents/10_Projects/YYYY_Category_ProjectName/`
- No `_index.md`, no `02_Drafts/` subfolders
- Vault symlinks use **relative paths** (`../../../00_Vault/...`)

## Submodule Rules (Developer-based only)

Developer-based projects can embed external Git repos as submodules.
Placement follows the standard folder semantics:

| Role | Folder | Example |
|------|--------|---------|
| Read-only reference / baseline | `01_Input/` | Upstream paper's official repo |
| Active development / your code | `02_Drafts/code/` | Your fork or own repo |
| Paper / Overleaf sync | `paper/` (top-level) | Overleaf Git-synced repo |

```bash
# Example: add a fork you're actively modifying
git submodule add https://github.com/YOU/forked-repo.git 02_Drafts/code/forked-repo

# Example: add upstream code as read-only reference
git submodule add https://github.com/author/original-repo.git 01_Input/original-repo
```

Submodules are local, but their **remote URLs** should still appear
in `_index.md` for discoverability (mark with "(submodule)").
`_index.md` also maps any external nodes that live **outside** the
project folder.

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

### 1. Determine Placement

Check the inferred Category against Placement Rules:
- **Research or Dev** → Developer-based
- **All others** → Document-based

### 2. Create Structure

**Developer-based** (Research/Dev):

```bash
# NOTE: Brace expansion fails in non-interactive shells.
# Use explicit mkdir calls instead.
P=~/Developer/YYYY_Category_ProjectName
mkdir -p $P/01_Input
mkdir -p $P/02_Drafts/code
mkdir -p $P/02_Drafts/notes
mkdir -p $P/02_Drafts/writing
mkdir -p $P/02_Drafts/experiments
mkdir -p $P/02_Drafts/presentations
mkdir -p $P/03_Output
mkdir -p $P/99_Admin/meetings
# Initialize Git
cd $P && git init
# Symlink into 10_Projects for unified view
ln -s $P ~/Documents/10_Projects/YYYY_Category_ProjectName
```

**Document-based** (all others):

```bash
P=~/Documents/10_Projects/YYYY_Category_ProjectName
mkdir -p $P/01_Input $P/02_Drafts $P/03_Output $P/99_Admin
```

### 3. Add Submodules (Developer-based only)

Ask the user: "Are there existing repos to bring into this project?"
(e.g., a fork to build on, an upstream baseline, an Overleaf paper repo)

If yes, add them as submodules following the Submodule Rules:
- Fork / active dev / own code → `02_Drafts/code/`
- Read-only reference → `01_Input/`
- Paper repo → `paper/`

```bash
git submodule add <repo-url> <target-folder>/<repo-name>
```

### 4. Create _index.md (Developer-based only)

A pure topology file — maps this project's external nodes
(repos, platforms, services). Contains ONLY pointers,
no status or planning content. Like `index.js` — just re-exports.

```markdown
# [Project Name]

- Code: ~/Developer/repo-name
- Paper: ~/Developer/overleaf/project-name
- Website: ~/Developer/project-name.github.io
```

Only include pointers that actually exist.
Remove lines that don't apply.
Ask the user what external nodes this project connects to.

### 5. Create 00_PLAN.md

```markdown
# Project Plan: [Project Name]

**Created:** YYYY-MM-DD
**Status:** Active
**Tags:** #Category

---

## 1. Current Status (当前状态)
*最后更新：YYYY-MM-DD*

**现在卡在哪里**：项目刚初始化
**下一步**：[Inferred first action]

## 2. Definition of Done (以终为始)
> [Inferred end state]

## 3. Deliverables (交付物)
- [ ] [Deliverable 1]
- [ ] [Deliverable 2]

## 4. Decision Log (决策日志)

### YYYY-MM-DD — 项目启动
**背景**：[Why this project was created]
**决策**：[Initial approach chosen]

## 5. Vault Linkage (事实链接)
> Files linked from 00_Vault (Use Symlinks `ln -s`)
-

## 6. Key Dates & Deadlines
| Date | Event |
|------|-------|
| YYYY-MM-DD | Project created |

## 7. Resources & References
-

## 8. Log & Next Actions (日志与行动)
- [ ] Project initialized @date(today)
```

### 6. Linkage Ritual

Search `~/Documents/00_Vault/` for relevant files (by date, entity, keywords).
If found, create symlinks in `99_Admin/`:

**Document-based** (relative paths):

```bash
cd ~/Documents/10_Projects/YYYY_Category_ProjectName/99_Admin
ln -s "../../../00_Vault/path/to/file.pdf" .
```

**Developer-based** (absolute paths):

```bash
cd ~/Developer/YYYY_Category_ProjectName/99_Admin
ln -s ~/Documents/00_Vault/path/to/file.pdf .
```

Document links in 00_PLAN.md Section 5 (Vault Linkage).

### 7. Update Project Inventory

Add to Active Projects table in `~/Documents/10_Projects/README.md`:

```markdown
| `YYYY_Category_ProjectName/` | [Description] | Active |
```

## Output

Report:
1. Created structure (tree view)
2. Inferred details (Name, Category, Definition of Done, Deliverables)
3. Project placement (Developer-based or Document-based)
4. Vault files linked (if any)
5. Suggested next actions

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

Display project summary. Apply Placement Rules based on Category:
- Active Research/Dev → `~/Developer/` + symlink
- Active (other) → `~/Documents/10_Projects/`
- Completed → `~/Documents/99_Archives/`

```
Project Analysis:
- Date Range: YYYY-MM-DD to YYYY-MM-DD
- Category: [Inferred]
- Name: [Inferred]
- Files: N documents
- Placement: [Developer-based / Document-based]

Is this project ACTIVE or COMPLETED?
- Active → [Developer or 10_Projects based on category]
- Completed → 99_Archives/
```

### 4. Create Standard Structure

Follow the same Placement Rules as `/project init`:
- Research/Dev: create in `~/Developer/`, symlink, git init, _index.md
- Others: create in `~/Documents/10_Projects/`

### 4b. Scan for Existing Repos (Developer-based only)

Search `~/Developer/` for repos related to this project by keywords:

```bash
ls -d ~/Developer/*/ | grep -i "<keywords>"
```

For each match, check `git remote -v` to understand the repo's role,
then offer as submodule candidate. Map to standard locations per
Submodule Rules (code → `02_Drafts/code/`, paper → `paper/`,
reference → `01_Input/`).

### 5. Categorize and Move Files

Sort files into appropriate subfolders:

| File Type | Destination |
|-----------|-------------|
| Source materials, references | `01_Input/` (incoming, read-only) |
| Your notes, code, writing, experiments | `02_Drafts/` (your creation) |
| Final outputs, deliverables | `03_Output/` (outgoing) |
| Meeting notes, receipts, correspondence | `99_Admin/` (overhead) |

### 5b. PDF Parsing Convention (MinerU)

When a PDF needs to be converted to searchable Markdown (e.g., for
reference materials in `01_Input/`), use MinerU (`mineru` CLI) and
follow this structure:

```
DocumentName.pdf              ← original PDF stays here
DocumentName/                 ← parsed output in sibling folder
├── DocumentName.md           ← Markdown conversion
└── images/                   ← extracted images, renamed descriptively
    ├── fig1_descriptive_name.jpg
    └── fig2_descriptive_name.jpg
```

**Rules:**
- The folder name matches the PDF filename (without `.ext`)
- Original PDF and its parsed folder live side by side
- Never mix parsed output (`.md` + `images/`) directly alongside
  unrelated PDFs — always contain them in a subfolder
- Rename extracted images from hashes to descriptive names
  (e.g., `challenge1_inclined_obstacle_terrain.jpg` not `b91d1c...jpg`)
- Markdown image paths use relative `images/` references

```bash
# Example workflow
mineru -p input.pdf -o /tmp/mineru_output -m auto -l en
# Then copy .md + images/ into the sibling folder, rename images
```

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
For Developer-based projects, also generate `_index.md`.

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

If no name provided, list all active projects. Mark Developer-based
projects in the list:

```
Active Projects:
1. 2025_Asset_Sale_Laptop/
2. 2025_Event_Travel_Conference/
3. 2026_Research_SciCraft/  [Developer-based]

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

**Document-based projects:**

```bash
mv ~/Documents/10_Projects/YYYY_Category_ProjectName/ ~/Documents/99_Archives/
```

**Developer-based projects:**

```bash
# 1. Zip the project (preserves full Git history)
cd ~/Developer
zip -r YYYY_Category_ProjectName.zip YYYY_Category_ProjectName/
# 2. Move zip to Archives
mv YYYY_Category_ProjectName.zip ~/Documents/99_Archives/
# 3. Remove symlink from 10_Projects
rm ~/Documents/10_Projects/YYYY_Category_ProjectName
# 4. Remove original from Developer
rm -rf ~/Developer/YYYY_Category_ProjectName
```

### 5. Update Project Inventory

Remove from Active Projects table in `~/Documents/10_Projects/README.md`.
Update status to **Archived** if keeping the row.

## Preservation Policy

- For Document-based: keep ALL files and symlinks intact
- For Developer-based: zip preserves complete Git history and all files
- Do NOT delete any content without archiving first

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

Detect if project is Developer-based (body in `~/Developer/`) or
Document-based (body in `~/Documents/10_Projects/`).

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

**Document-based** (relative paths):

```bash
cd ~/Documents/10_Projects/YYYY_Category_ProjectName/99_Admin
ln -s "../../../00_Vault/path/to/file.pdf" .
```

**Developer-based** (absolute paths):

```bash
cd ~/Developer/YYYY_Category_ProjectName/99_Admin
ln -s ~/Documents/00_Vault/path/to/file.pdf .
```

### 6. Update 00_PLAN.md

Add to Section 5 (Vault Linkage):

```markdown
## 5. Vault Linkage (事实链接)
- [filename.pdf](path/to/vault/file.pdf)
```

---

# Project Categories Reference

Categories follow the 7 Pillars hierarchy. Use the most specific
subtype that applies.

| Pillar | Subtypes | Placement | Description |
|--------|----------|-----------|-------------|
| **Legal** | `Litigation`, `Immigration` | Document | Law, contracts, government filings |
| **Asset** | `Sale` | Document | Buy/sell/maintain valuables |
| **Admin** | `Claim` | Document | Forms, compliance, bureaucracy |
| **Research** | — | **Developer** | Papers, experiments, discovery |
| **Dev** | — | **Developer** | Code, systems, engineering |
| **Academic** | `Course` | Document | Courses with grades |
| **Event** | `Travel`, `Creation` | Document | Trips, conferences, creative projects |

**Naming:** Use the subtype when it applies (`2025_Litigation_...`),
fall back to the pillar (`2025_Legal_...`) when no subtype fits.

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
