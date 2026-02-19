# Detailed Workflow for Processing Inbox

This document contains the step-by-step workflow for processing files from
`~/Downloads` into the Digital Life System.

---

## Step 0: List Inbox Files (Once)

```bash
ls -la ~/Downloads/*.[pP][dD][fF] 2>/dev/null || echo "No PDFs in Downloads"
```

**Note:** Use case-insensitive pattern `*.[pP][dD][fF]` to match both `.pdf` and `.PDF`.
Only process PDF files unless `$ARGUMENTS` specifies otherwise.

---

## Step 1: READ (One File)

Use the **pdf-analyzer agent** to read and analyze PDF files:

```
Task(
  subagent_type="pdf-analyzer",
  prompt="Analyze this PDF: ~/Downloads/filename.pdf"
)
```

The pdf-analyzer agent (`.claude/agents/pdf-analyzer.md`):
- Extracts text from both text-based and scanned PDFs
- Provides structured analysis with Document Type, Date, Entity, Key Details
- Generates VNS-compliant filename recommendations
- Suggests appropriate Vault path for filing
- Handles foreign language documents with romanization

**Output Format from Agent:**
```
## Document Analysis

**Current Filename:** `[original filename]`

### Content Summary
[2-4 sentence summary]

### Extracted Details
- **Document Type:** [type]
- **Date:** [YYYY-MM-DD]
- **Issuer/Entity:** [name]
- **Subject:** [who/what it's about]
- **Key Reference Numbers:** [if any]
- **Amount:** [if applicable]

### Recommended Filename
`[VNS-compliant filename]`

### Recommended Vault Path
`/00_Vault/[path]/`
```

**Proceed to Step 2** with the agent's analysis.

---

## Step 2: DECIDE (Same File)

Extract from content:
- **Date** (ISO 8601: YYYY-MM-DD)
- **Entity** (Legal Name from CLAUDE.md Section 3.A)
- **Category** (from CLAUDE.md Controlled Vocabulary)
- **Description** (snake_case)

Apply **Decision Algorithm** (CLAUDE.md Section 2):
1. Artifact/Evidence → `00_Vault`
2. Active project work → `10_Projects`
3. Reference material → `30_Resources`
4. Life maintenance → `20_Areas`

**If uncertain:** Add to skip list, move to next file.

---

## Step 2.5: CHECK DUPLICATES (Before Move)

Before moving to Vault, search for potential duplicates:

### A. Search Target Folder

Check if a file with similar date + entity already exists:

```bash
# Example: checking for Amazon receipt on 2025-01-17
ls ~/Documents/00_Vault/03_Financial/Receipts/ 2>/dev/null | grep "2025-01-17.*Amazon"
```

### B. Search by Key Identifiers

Search entire Vault for unique identifiers extracted from the document:

```bash
# Search by order number, confirmation number, case number, etc.
grep -rl "ORDER_NUMBER" ~/Documents/00_Vault/ 2>/dev/null
grep -rl "CONFIRMATION_NUMBER" ~/Documents/00_Vault/ 2>/dev/null
```

**Identifiers to search:**
- Order/Confirmation numbers (e.g., `#113-9218568`, `37927791`)
- Case/Claim numbers (e.g., `25BHSC01570`, `47594630`)
- Invoice/Receipt numbers
- Policy/Account numbers

### C. Handle Duplicates

| Situation | Action |
|-----------|--------|
| **Identical file exists** | Skip, report "Already in Vault at [path]" |
| **Similar file, different version** | Ask user which to keep |
| **No duplicate found** | Proceed to Step 3 (Move) |

**Tip:** Compare file sizes and key details (date, amount, reference #) to determine
if files are truly identical or different versions of the same document.

---

## Step 3: MOVE (Same File)

**If Vault:** Apply VNS naming (CLAUDE.md Section 3.B):
```bash
mv "source_path" "dest_path/YYYY-MM-DD_Category_Entity_description.ext"
```

**If Project/Resource/Area:** Move with descriptive name.

**Symlinks:** If SSOT applies (CLAUDE.md Section 7), create symlinks for
secondary owners with `_Link` suffix.

---

## Step 4: REPORT (Same File)

```text
✓ [filename] → [destination] (renamed to [new_name])
```

---

## Step 5: NEXT FILE

Repeat Steps 1-4 for each file.

---

## Finalization

### A. Ask Collected Questions

Present all skipped files and ask user for guidance.

### B. Project Linkage (Dynamic Search)

For each file moved to `00_Vault`, search for related projects:

1. **Extract Identifiers** from the filed document:
   - Claim/Case numbers (e.g., `47594630`, `25BHSC01570`)
   - Entity names (e.g., `Smith_John`, `Doe_Jane`)
   - Vendor/Company names (e.g., `Chase`, `Acme`)
   - Keywords from description

2. **Search 10_Projects/** for matches:
   ```bash
   grep -rl "IDENTIFIER" ~/Documents/10_Projects/ --include="*.md" 2>/dev/null
   ```

3. **If match found:**
   - Update the matched project's `00_PLAN.md`:
     - **Section 5 (项目结构):** Add file to reference list with Vault symlink path
     - **Section 8 (Log):** Add dated entry noting the document received/filed
   - Record linkage in report

4. **If no match:**
   - Just file to Vault, no linkage needed
   - Record "(no active project)" in Section 9

### C. Update Root CLAUDE.md

1. Section 9 (Recent Vault Filings): Add entry for each filed document
2. Section 4 (Active Projects): Update status if document changes project state

### D. Report Summary

```text
═══════════════════════════════════════════════════════════════
INBOX PROCESSING COMPLETE
───────────────────────────────────────────────────────────────
Files processed: X
  → Vault:     X (with Y project linkages)
  → Projects:  X
  → Resources: X
  → Skipped:   X (questions pending)

Project Updates:
  • [Project Name]: [What was updated]
═══════════════════════════════════════════════════════════════
```

---

## Legal Document Guidelines (04_Legal)

### Category Selection for Legal Documents

| Document Type | Category | Example Filename |
|---------------|----------|------------------|
| Court minute order / trial record | `Record` | `2025-12-22_Record_Court_25BHSC01570_trial_minute_order.pdf` |
| Official court notice | `Notice` | `2025-11-21_Notice_LASC_digital_evidence_guide.pdf` |
| Filed forms (SC-100, SC-120) | `Application` | `2025-07-21_Application_SC100_plaintiff_claim.pdf` |
| Signed agreements | `Contract` | `2025-12-16_Contract_CCR_mediation_confidentiality.pdf` |
| Witness statements | `Affidavit` | `2025-12-01_Affidavit_Doe_declaration.pdf` |
| Photos, screenshots, chat logs | `Evidence` | `2025-07-15_Evidence_WhatsApp_threat_screenshot.pdf` |

### Entity Naming for Court Documents

- **Court-issued documents:** Use `Court` as entity
- **Case-specific documents:** Include case number in description
- **Multi-party cases:** File under `Case_<number>_<shortname>/` folder

### Status-Changing Documents

When a document indicates **case status change**, MUST update:

1. **Project CLAUDE.md** — Status field and add outcome section
2. **Project LOG_Timeline.md** — Add dated entry with details
3. **Root CLAUDE.md Section 4** — Update Active Projects table
4. **Root CLAUDE.md Section 9** — Add to Recent Vault Filings

**Status-changing examples:**
- Trial minute order (judgment entered)
- Appeal decision
- Settlement agreement
- Case dismissal

### Deadline Tracking

For legal documents with deadlines, note in project CLAUDE.md:

```markdown
**Key Deadlines:**
- [ ] Notice of Appeal: 30 days from judgment (YYYY-MM-DD)
- [ ] Response to Motion: 15 days from service (YYYY-MM-DD)
```

---

## Safety Rules

- **NEVER delete files. NEVER use `rm` command.**
- If a file is junk or unclear, move to `~/Documents/__To_Review/`:
  ```bash
  mkdir -p ~/Documents/__To_Review/
  mv "source" ~/Documents/__To_Review/
  ```

---

## Lessons Learned

**2025-12-29 — Case-Insensitive PDF Extension Matching:**
- Use `*.[pP][dD][fF]` instead of `*.pdf` to match both `.pdf` and `.PDF`
- macOS filesystem is case-insensitive, but shell glob patterns are case-sensitive

**2026-01-17 — Use pdf-analyzer Agent for PDFs:**
- The pdf-analyzer agent (`.claude/agents/pdf-analyzer.md`) provides structured analysis
- Returns VNS-compliant filename and Vault path recommendations
- Handles foreign language documents with romanization
- Workflow: `Agent Analyze → Validate → Move`

**2025-12-26 — Read Tool as Fallback:**
- The Read tool handles both text-based and scanned PDFs with built-in OCR
- Use as fallback if pdf-analyzer agent is unavailable
- Simpler workflow but requires manual filename generation

**2025-12-22 — Court Minute Order Processing:**
- Trial minute orders use `Record` category (not `Notice` or `Evidence`)
- Judgment outcomes require updating BOTH project files AND root CLAUDE.md
- Consider appeal deadlines when filing adverse judgments

**2025-12-30 — MinerU for Large Books/Documents:**
- For large PDFs (>10MB), especially books, use MinerU to extract first few pages
- Command: `mineru -p file.pdf -o /tmp/mineru_output -s 0 -e 4` (pages 0-4)
- Read the generated `.md` file to identify title, author, publication date
- Clean up temp files after: `rm -rf /tmp/mineru_output`
- Books go to `30_Resources/CS_Books/` with naming: `YYYY_Author_title_in_snake_case.pdf`

**2025-12-22 — Dynamic Project Linkage:**
- Don't rely on static Case Mapping Table
- Always search `10_Projects/` for identifiers (claim #, case #, entity, vendor)
- Use `grep -rl "IDENTIFIER" ~/Documents/10_Projects/` to find related projects
- If no match found, just file to Vault — no linkage needed

**2026-01-29 — Bidirectional Project Linkage:**
- Vault filing is incomplete until linked project is also updated
- When project match found, MUST update project's `00_PLAN.md`:
  - Section 5 (项目结构): Add file reference with Vault path
  - Section 8 (Log): Add dated log entry
- This is bidirectional: Vault ↔ Project both track the relationship

**2026-01-31 — Duplicate Check Before Filing:**
- MUST check for duplicates before moving files to Vault
- Two-pronged search: (1) target folder by date+entity, (2) entire Vault by identifiers
- Identifiers include: order #, confirmation #, case #, invoice #, policy #
- If identical file exists, skip and report; if different version, ask user
- Prevents duplicate receipts/documents from cluttering the Vault
