---
name: slidev4paper
description: >
  Create Slidev presentations from academic papers. Scaffolds a
  multi-file Slidev project, downloads figures from arXiv HTML,
  writes narrative slide content, launches dev server, and reviews
  each slide via browser automation.
  Triggers (EN): "make slides for paper", "present this paper",
  "slidev presentation", "paper presentation", "create slides
  from paper".
  Triggers (中文): "做PPT", "论文报告", "做slides", "论文演示",
  "Slidev演示".
---

# Slidev for Paper Presentations

Create polished Slidev presentations from academic papers following
a proven end-to-end workflow.

## Prerequisites

- Node.js (for npx/npm)
- Chrome + Claude-in-Chrome extension (for visual review)
- `cloudflared` (optional, for public sharing via Cloudflare Tunnel)

## Workflow Overview

```
1. Analyze papers → extract narrative arc
2. Scaffold Slidev project (multi-file)
3. Download figures from arXiv HTML
4. Write slide content
5. Add footer (global-bottom.vue) with per-section citations
6. Add overflow scroll CSS for dense slides
7. Launch dev server + review each slide in browser
8. Iterate on layout/content
9. (Optional) Share via Cloudflare Tunnel
```

## Step 1: Paper Analysis & Narrative Design

Before writing any slides, identify the **story arc** across papers:

- What problem does each paper expose?
- What's the logical ordering? (problem → analysis → solution)
- What connects them? (shared theme, progressive depth, contrast)

### Narrative Patterns

| Pattern | When to Use | Example |
|---------|-------------|---------|
| **Progressive** | Papers build on each other | Problem → Diagnosis → Fix |
| **Contrastive** | Papers take opposing views | Method A vs Method B |
| **Converging** | Papers attack same problem differently | Three angles, one goal |

## Step 2: Project Scaffolding

### Directory Structure

Place presentations under the project's `02_Drafts/presentations/`:

```
02_Drafts/presentations/YYYY-MM-DD_topic/
├── slides.md           # Entry point: frontmatter + title + src imports
├── global-bottom.vue   # Footer: per-section paper citation + page number
├── style.css           # Global CSS (overflow scroll, etc.)
├── vite.config.ts      # Vite overrides (allowedHosts for tunnel)
├── pages/
│   ├── 01_intro.md     # Background / motivation
│   ├── 02_paper1.md    # Paper 1 deep dive
│   ├── 03_paper2.md    # Paper 2 deep dive
│   ├── ...
│   └── 0N_synthesis.md # Cross-paper synthesis + conclusion
├── public/
│   └── images/
│       ├── paper1/     # Figures per paper
│       └── paper2/
├── package.json
└── node_modules/
```

### Initialize

```bash
cd <presentation-dir>
npm init -y
npm install @slidev/cli @slidev/theme-default
```

### Entry File: slides.md

The first slide's **content** must appear after the frontmatter in
`slides.md` (not in a separate file), otherwise Slidev renders a
blank first slide.

```markdown
---
theme: default
title: "Presentation Title"
info: |
  Description of the presentation
drawings:
  persist: false
transition: slide-left
mdc: true
---

# Title Here

## Subtitle

Content of the title slide goes here.

---
src: ./pages/01_intro.md
---

---
src: ./pages/02_paper1.md
---
```

**Critical:** Each `src:` import needs its own `---` fences.

## Step 3: Download Figures from arXiv

### Check for HTML Version

Most recent arXiv papers have HTML versions at:
`https://arxiv.org/html/<paper-id>v<version>`

Images are at paths like:
`https://arxiv.org/html/<id>/extracted/media/<filename>`

### Download Script Pattern

```bash
PAPER_ID="2503.03321v1"
DEST="public/images/paper_name"
mkdir -p "$DEST"

# Download specific figures (check HTML source for filenames)
for fig in x1.png x2.png x3.png; do
  curl -sL -o "$DEST/$fig" \
    "https://arxiv.org/html/${PAPER_ID}/extracted/media/$fig"
done

# Verify all downloads are valid images
file "$DEST"/*
```

### Reference in Slides

```markdown
<img src="/images/paper_name/x2.png"
     class="mx-auto w-4/5 rounded shadow" />
```

Use `/images/...` (absolute from `public/`).

## Step 4: Slide Content Patterns

### Paper Title Slide

```markdown
# Paper N: Short Name

## Full Title (Venue Year)

**Author et al., Affiliation**

<br>

### Core Question

> The key research question in blockquote form?

<div class="mt-4 text-sm opacity-70">
arXiv: XXXX.XXXXX
</div>
```

### Two-Column Layout

```markdown
<div class="grid grid-cols-2 gap-6">
<div>

### Left Column Title

- Point 1
- Point 2

</div>
<div>

<img src="/images/paper/fig.png" class="rounded shadow" />

</div>
</div>
```

### Key Insight Box (with v-click reveal)

```markdown
<v-click>

<div class="mt-4 p-3 bg-blue-50 rounded dark:bg-blue-900/30">

**Key Insight:** Description of the insight.

</div>

</v-click>
```

### Takeaway / Implication Box

```markdown
<v-click>

<div class="mt-6 p-3 bg-amber-50 rounded dark:bg-amber-900/30">

**Takeaway for [Domain]:** Practical implication.

</div>

</v-click>
```

### Color-Coded Comparison Cards

```markdown
<div class="mt-4 grid grid-cols-3 gap-4 text-sm">
<div class="p-2 bg-green-50 rounded dark:bg-green-900/30">

**Advantage 1**

</div>
<div class="p-2 bg-green-50 rounded dark:bg-green-900/30">

**Advantage 2**

</div>
<div class="p-2 bg-green-50 rounded dark:bg-green-900/30">

**Advantage 3**

</div>
</div>
```

### Contrast Boxes (Paper vs Paper)

```markdown
<div class="grid grid-cols-2 gap-8 mt-8">
<div class="p-4 bg-red-50 rounded dark:bg-red-900/30">

### Paper A says:

Key point from paper A

</div>
<div class="p-4 bg-blue-50 rounded dark:bg-blue-900/30">

### Paper B says:

Key point from paper B

</div>
</div>
```

### Synthesis / Comparison Table

```markdown
<div class="text-sm mt-2">

| | **Paper 1** | **Paper 2** | **Paper 3** |
|---|---|---|---|
| **Dimension 1** | ... | ... | ... |
| **Dimension 2** | ... | ... | ... |

</div>
```

### LaTeX Equations

Slidev supports KaTeX natively:

```markdown
$$
\text{RAPT}_m^{(l)} = \frac{\bar{a}_m^{(l)} / |m|}
                             {\bar{a}_{\text{all}}^{(l)} / |all|}
$$
```

## Step 5: Footer — Per-Section Paper Citations

**MANDATORY.** Every presentation MUST have a `global-bottom.vue` that
shows the current paper's full citation in the footer. This is the
definitive footer pattern:

### Footer Definition

The footer displays two pieces of information:
- **Left:** Current paper citation (Author et al. "Full Title" — Venue Year)
- **Right:** Page number (current / total)

The citation **switches dynamically** based on the current slide number,
so the audience always knows which paper is being discussed.

### Implementation: `global-bottom.vue`

```vue
<template>
  <div class="absolute bottom-0 left-0 right-0 px-6 py-2
       flex justify-between items-center text-[10px] opacity-50"
       style="pointer-events: none;">
    <span>{{ footerText }}</span>
    <span>{{ $nav.currentPage }} / {{ $nav.total }}</span>
  </div>
</template>

<script setup>
import { computed } from 'vue'
import { useNav } from '@slidev/client'

const { currentPage } = useNav()

const footerText = computed(() => {
  const p = currentPage.value
  // Title + intro slides
  if (p <= 2) {
    return 'Presentation Main Title'
  }
  // Paper 1 slides (adjust range after counting slides)
  if (p <= 9) {
    return 'Author et al. "Paper 1 Full Title" — Venue Year'
  }
  // Paper 2 slides
  if (p <= 14) {
    return 'Author et al. "Paper 2 Full Title" — Venue Year'
  }
  // Paper 3 slides
  if (p <= 19) {
    return 'Author et al. "Paper 3 Full Title" — Venue Year'
  }
  // Synthesis + Thank You
  return 'Presentation Main Title'
})
</script>
```

### How to Calculate Page Ranges

Count `---` separators in each page file to determine slide count:

```bash
# Count slides per section file
for f in pages/*.md; do
  separators=$(grep -c "^---$" "$f")
  slides=$((separators + 1))
  echo "$f: $slides slides"
done
```

Then set ranges in `global-bottom.vue` accordingly:
- `slides.md` title = page 1
- `01_intro.md` = page 2 (1 slide)
- `02_paper1.md` = pages 3-8 (6 slides with 5 `---`)
- etc.

**Important:** When adding/removing slides, always update the page
ranges in `global-bottom.vue` to match.

## Step 6: Overflow Scroll for Dense Slides

Academic slides often have dense content (equations, tables, figures).
Add a `style.css` to enable per-slide scrolling:

```css
/* style.css — Allow scrolling on slides with overflow content */
.slidev-layout {
  overflow-y: auto !important;
  max-height: 100% !important;
}
```

This lets dense slides scroll rather than clip content at the bottom.

## Step 7: Vite Config for Tunnel Sharing

When sharing via Cloudflare Tunnel, Vite's host check blocks
external domains. Add `vite.config.ts`:

```ts
import { defineConfig } from 'vite'

export default defineConfig({
  server: {
    allowedHosts: true,
  },
})
```

**Note:** This file requires a Slidev server restart (HMR does not
pick up vite config changes).

## Step 8: Launch & Review

### Starting the Dev Server

**Critical:** Slidev's interactive mode exits when stdin closes.
Use this pattern for background execution:

```bash
cd <presentation-dir>
tail -f /dev/null | npx slidev --port 3131 > /tmp/slidev.log 2>&1 &
sleep 8
curl -s -o /dev/null -w "HTTP %{http_code}" http://localhost:3131/
```

**Port conflicts:** Default port 3030 is often taken (Docker, etc.).
Use `--port 3131` or another free port. Always check first:

```bash
lsof -i :3131 | head -5
```

### Browser Review Checklist

For each slide, verify:
- [ ] Text not overflowing the slide boundary
- [ ] Images loading correctly (no broken images)
- [ ] v-click animations stepping correctly
- [ ] Two-column layouts balanced
- [ ] Code/math rendering properly
- [ ] Figure captions visible and correct
- [ ] Color boxes rendering in both light/dark
- [ ] Footer shows correct paper citation for each section
- [ ] Footer page numbers match actual slide count

Navigate between slides using:
- Direct URL: `http://localhost:3131/<slide-number>`
- Keyboard: Right arrow in the browser

### Cleanup

```bash
pkill -f "slidev"
```

## Step 9: Public Sharing via Cloudflare Tunnel

To share the presentation with others without deploying:

```bash
# Quick tunnel (temporary URL, no config needed)
cloudflared tunnel --url http://localhost:3131
```

This generates a `https://xxx-xxx.trycloudflare.com` URL.

**Requirements:**
1. `cloudflared` must be installed (`brew install cloudflared`)
2. `vite.config.ts` must have `allowedHosts: true` (see Step 7)
3. Slidev server must be running
4. Kill with `pkill -f cloudflared` when done

## Step 10: Git & .gitignore

Always add a `.gitignore` to the presentation directory or project:

```
node_modules/
dist/
.slidev/
```

Never commit `node_modules/` (hundreds of MB).
`package-lock.json` should be committed for reproducible installs.

## Slide Budget Guidelines

| Section | Slides | Purpose |
|---------|--------|---------|
| Title | 1 | Hook + paper list |
| Background | 1-2 | Shared motivation / assumption |
| Per Paper | 4-7 | Title → Background → Problem → Method → Results → Takeaway |
| Synthesis | 2-3 | Comparison table + research gaps |
| Thank You | 1 | References |

**Target:** 18-25 slides for a 20-30 minute talk.
Dense technical slides (equations, multi-panel figures) can use
overflow scroll if needed.

## Common Pitfalls

1. **Blank first slide:** Title content must be in `slides.md`,
   not in a separate `src:` file
2. **Stdin EOF crash:** Always pipe `tail -f /dev/null` into Slidev
3. **Port conflict:** Check `lsof -i :<port>` before starting
4. **Image paths:** Use `/images/...` (from `public/`), not
   relative paths
5. **v-click spacing:** Need blank lines around `<v-click>` tags
   for markdown inside to render
6. **Dark mode:** Always add `dark:bg-*` variants for colored boxes
7. **Table overflow:** Use `text-sm` or `text-xs` wrapper for wide
   comparison tables
8. **Footer page ranges:** Must update `global-bottom.vue` ranges
   whenever slides are added/removed from any section
9. **Vite config not hot-reloaded:** Changes to `vite.config.ts`
   require full Slidev server restart
10. **Cloudflare Tunnel blocked:** Need `allowedHosts: true` in
    `vite.config.ts` before tunneling works
11. **Dense content:** Use `text-xs` for slides with equations +
    figures + tables; enable overflow scroll in `style.css`
