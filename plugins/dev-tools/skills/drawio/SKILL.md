---
name: drawio
description: >-
  Create and edit .drawio.svg diagrams that render as images
  and are editable in draw.io/VSCode. Supports sequence diagrams,
  flowcharts, comparison tables, note boxes, and network topologies.
  Handles SVG-to-PDF conversion for LaTeX integration.
  Use when the user wants to: (1) create a diagram or figure,
  (2) make a .drawio.svg file, (3) draw a sequence/flow/topology,
  (4) add a figure to LaTeX notes, (5) visualize protocol flows
  or system architecture.
  Triggers (EN): "create diagram", "draw", "drawio", "sequence
  diagram", "flowchart", "network diagram", "add figure",
  "visualize", "make a diagram".
  Triggers (中文): "画图", "画一个", "做图", "流程图",
  "时序图", "网络拓扑", "加个图".
---

# drawio Skill

Create `.drawio.svg` files — one file that is both a rendered
image and editable in draw.io / VSCode (hediet.vscode-drawio).

## Workflow

### Method A: Generator script (preferred)

1. Build a Python spec dict describing the diagram
2. Write to a temp JSON file
3. Run the generator:

```bash
uv run --with pyyaml \
  ~/.claude/skills/drawio/drawio/scripts/drawio_gen.py \
  /tmp/spec.json output.drawio.svg
```

4. Convert to PDF if needed for LaTeX:

```bash
rsvg-convert -f pdf -o output.pdf output.drawio.svg
```

### Method B: Hand-write SVG (custom layouts)

Write SVG directly with `content` attribute containing
HTML-escaped mxGraphModel XML.
See `references/drawio_format.md` for schema and palette.

## Diagram Types

### Sequence Diagram

```python
{
    "type": "sequence",
    "offset_x": 40, "offset_y": 10,
    "title": "Three-Way Handshake",
    "title_color": "green",
    "participants": ["Client", "Server"],
    "spacing": 210,
    "messages": [
        {"from": 0, "to": 1, "label": "SYN", "color": "blue"},
        {"from": 1, "to": 0, "label": "SYN-ACK", "color": "green"},
    ],
    "footer": "Connection Established",
    "footer_color": "green",
}
```

Params: `spacing` (px between participants),
`message_gap` (vertical px, default 45).

### Comparison Table

```python
{
    "type": "table",
    "title": "Key Differences", "title_color": "purple",
    "columns": [
        {"header": "Feature", "color": "dark", "width": 200},
        {"header": "TCP", "color": "green", "width": 200},
    ],
    "rows": [["Setup", "3-way handshake"]],
}
```

### Flowchart

```python
{
    "type": "flowchart",
    "nodes": [
        {"id": "s", "label": "Start", "color": "green",
         "shape": "rounded"},
        {"id": "c", "label": "Valid?", "color": "yellow",
         "shape": "diamond"},
        {"id": "ok", "label": "OK", "color": "blue"},
        {"id": "err", "label": "Error", "color": "red"},
    ],
    "edges": [
        {"from": "s", "to": "c"},
        {"from": "c", "to": "ok", "label": "Yes"},
        {"from": "c", "to": "err", "label": "No",
         "direction": "right"},
    ],
}
```

Shapes: `rect`, `rounded`, `diamond`.
Edge `direction`: omit=vertical, `"right"`/`"left"`=branch.

### Network Topology

```python
{
    "type": "topology",
    "nodes": [
        {"id": "cli", "label": "Client", "x": 50, "y": 50,
         "color": "blue", "shape": "rounded"},
        {"id": "srv", "label": "Server\nPort 26000",
         "x": 300, "y": 50, "color": "green"},
    ],
    "links": [
        {"from": "cli", "to": "srv",
         "label": "TCP", "color": "blue"},
    ],
}
```

Multi-line labels: use `\n`. Explicit `x`/`y` positions.

### Note Box

```python
{
    "type": "note",
    "title": "UDP Features", "color": "blue", "width": 320,
    "items": ["No connection state", "Best-effort delivery"],
}
```

## Multi-Section Diagrams

Combine types in one SVG:

```python
{
    "width": 920, "height": 820,
    "sections": [
        {"type": "sequence", "offset_x": 40, "offset_y": 10, ...},
        {"type": "table", "offset_x": 120, "offset_y": 640, ...},
    ],
}
```

Use `offset_x`/`offset_y` to position each section.

## Color Palette

| Name   | Use for                          |
|--------|----------------------------------|
| green  | Success, established, category A |
| blue   | Info, data flow, category B      |
| yellow | Titles, warnings                 |
| purple | Summary, meta sections           |
| red    | Error, teardown, failure         |
| gray   | Neutral, even table rows         |
| dark   | Table headers                    |

Full hex values: `references/drawio_format.md`.

## LaTeX Integration

Prerequisite: `brew install librsvg`

### Makefile rule

```makefile
figures/%.pdf: figures/%.drawio.svg
	@rsvg-convert -f pdf -o $@ $<
```

### Batch convert

```bash
bash ~/.claude/skills/drawio/drawio/scripts/svg2pdf.sh figures/
```

### In LaTeX

```latex
\includegraphics[width=\textwidth]{diagram_name}
```

Omit extension — LaTeX finds `.pdf` automatically.
