---
name: capture
description: |
  Universal content capture into the Digital Life System.
  Use when the user says: "记一下", "capture", "/capture",
  "记录", "存一下", "save this", or provides content to file
  (letters, quotes, bank info, articles, book recs, etc.).
  Triggers (中文): "记一下", "帮我记", "存一下", "收藏".
  Triggers (EN): "capture", "save this", "record this", "note this".
---

# /capture — Universal Content Capture

One command to capture anything into the Digital Life System.

## How It Works

1. **Detect type** from content + user hint
2. **Look up rules** in the registry
3. **Route** to the correct destination
4. **Update linkages** (project plan + CLAUDE.md Section 9 if needed)

## Quick Reference

| Type | Domain | Destination |
|------|--------|-------------|
| `letter` | Vault | `07_Personal/{sender_or_recipient}/` |
| `legal_note` | Vault | `07_Personal/{Owner}/` |
| `account` | Areas | `20_Areas/Finance_Planning/accounts_registry.md` |
| `quote` | Resources | `30_Resources/Quotes/Quotes.md` |
| `book` | Resources | `30_Resources/Lists/Reading_List.md` |
| `show` | Resources | `30_Resources/Lists/Watch_List.md` |
| `article` | Resources | `30_Resources/Articles/` |
| `tool` | Resources | `30_Resources/Lists/Tools.md` |
| `music` | Resources | `30_Resources/Lists/Music_Podcasts.md` |
| `course` | Resources | `30_Resources/Lists/Courses.md` |
| `travel` | Resources | `30_Resources/Lists/Travel_List.md` |
| `wishlist` | Resources | `30_Resources/Lists/Wishlist.md` |
| `puzzle` | Resources | `30_Resources/Lists/Puzzles.md` |
| `paper` | Resources | `30_Resources/Lists/Paper_List.md` |
| `concept` | Resources | `30_Resources/Concepts/` |

> **Full type definitions, templates, and field rules** are in
> `30_Resources/_capture_registry.md`.
> Each destination folder has its own `CLAUDE.md` with local rules.
> This is **Progressive Disclosure** — you only load what you need.

## Workflow

### Step 1: Detect Type

Infer from content and keywords. If ambiguous, ask.

```
User: "记一下，这是爸爸通过律师带出来的口信..."
→ type = letter (律师会见口信)

User: "户主：某联系人，账号：6228..."
→ type = account

User: ""The best time to plant a tree..." — Warren Buffett"
→ type = quote
```

### Step 2: Read Registry

Read the type definition from `30_Resources/_capture_registry.md`.
Read the destination's `CLAUDE.md` for local formatting rules.

### Step 3: Route & Write

- **append mode**: Add to existing file (quotes, books, tools...)
- **new_file mode**: Create a new file (articles, letters, concepts)
- **update mode**: Update existing record (accounts)

### Step 4: Update Linkages (Vault types only)

For types that route to `00_Vault`:

1. **Read `00_Vault/README.md`** for entity folder names and routing
2. **Search active projects** for related identifiers
3. **Update project `00_PLAN.md`** (Section 5 structure + Section 8 log)
4. **Append to `20_Areas/00_Meta_System/Vault_Filing_Log.md`**

For types that route to `20_Areas` or `30_Resources`:
- No linkage update needed.

## Diagram Capture (图表捕获)

When the source content contains a diagram, chart, flowchart,
timeline, or any visual structure:

1. **Create `.drawio.svg`** — one file that is both:
   - A renderable SVG image (any markdown viewer)
   - An editable draw.io source (VSCode / draw.io desktop)
   - Full drawio XML is embedded in the SVG `content` attribute
2. **Embed in the `.md` article** with `![alt](filename.drawio.svg)`
3. **Do NOT create** separate `.drawio`, `.excalidraw`, or Mermaid
4. **Output**: two files per article with diagrams:
   ```
   YYYY-MM-DD_title.md            ← article text + embedded SVG
   YYYY-MM-DD_title.drawio.svg   ← diagram (render + edit)
   ```

### Color Scheme

| Role | Fill | Stroke |
|------|------|--------|
| Title | `#fff2cc` | `#d6b656` |
| Category A (e.g. products) | `#d5e8d4` | `#82b366` |
| Category B (e.g. academic) | `#dae8fc` | `#6c8ebf` |
| Neutral (e.g. months) | `#f5f5f5` | `#666666` |
| Summary / takeaways | `#e1d5e7` | `#9673a6` |

### SVG Structure

```xml
<svg ... content="&lt;mxfile...&gt;...drawio XML...&lt;/mxfile&gt;">
  <!-- Pure SVG shapes for rendering -->
  <rect ... /><text ... />
</svg>
```

The `content` attribute holds the URL-encoded drawio XML.
Draw.io reads this for editing; browsers render the SVG shapes.

## Usage Examples

```
/capture 记一下这封信...
/capture "Happiness should be viewed microscopically..." — 某作者
/capture 户主：某联系人 账号：EXAMPLE_ACCOUNT_ID
/capture [screenshot of a book recommendation]
/capture [screenshot of a flowchart] ← creates .md + .drawio.svg
```

## Adding New Types

Edit `30_Resources/_capture_registry.md` and add a new section.
Create a `CLAUDE.md` at the destination if one doesn't exist.
The skill will automatically recognize it.
