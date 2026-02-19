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

User: "户主：汤华聪，账号：6228..."
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

## Usage Examples

```
/capture 记一下这封信...
/capture "Happiness should be viewed microscopically..." — 汤瑞雄
/capture 户主：汤华聪 账号：6228480089674086379
/capture [screenshot of a book recommendation]
```

## Adding New Types

Edit `30_Resources/_capture_registry.md` and add a new section.
Create a `CLAUDE.md` at the destination if one doesn't exist.
The skill will automatically recognize it.
