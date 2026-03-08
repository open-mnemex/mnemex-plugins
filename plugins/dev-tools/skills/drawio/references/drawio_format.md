# drawio.svg Format Reference

## File Structure

A `.drawio.svg` is a standard SVG with an embedded `content` attribute
containing the full mxGraphModel XML (HTML-escaped).
This lets it render as an image AND be editable in draw.io/VSCode.

```
<svg ... content="&lt;mxfile ...&gt;...&lt;/mxfile&gt;" ...>
  <defs><!-- arrow markers --></defs>
  <g><!-- visual SVG elements --></g>
</svg>
```

## Color Palette

| Name   | Fill    | Stroke  | Font    | Use for              |
|--------|---------|---------|---------|----------------------|
| green  | #d5e8d4 | #82b366 | #006600 | Success, category A  |
| blue   | #dae8fc | #6c8ebf | #003366 | Info, category B     |
| yellow | #fff2cc | #d6b656 | #333333 | Titles, warnings     |
| purple | #e1d5e7 | #9673a6 | #4a235a | Summary, meta        |
| red    | #f8cecc | #b85450 | #990000 | Error, teardown      |
| gray   | #f5f5f5 | #cccccc | #333333 | Neutral, table rows  |
| white  | #ffffff | #cccccc | #333333 | Alt table rows       |
| dark   | #333333 | #333333 | #ffffff | Table headers        |

Arrow colors: blue=#0066CC, green=#009900, red=#CC0000, gray=#666666.

## mxGraphModel XML Schema

```xml
<mxfile host="app.diagrams.net">
  <diagram name="Name" id="unique-id">
    <mxGraphModel dx="W" dy="H" grid="1" gridSize="10"
        guides="1" tooltips="1" connect="1" arrows="1"
        fold="1" page="1" pageScale="1"
        pageWidth="W" pageHeight="H">
      <root>
        <mxCell id="0"/>
        <mxCell id="1" parent="0"/>
        <!-- vertices and edges here -->
      </root>
    </mxGraphModel>
  </diagram>
</mxfile>
```

### Vertex (box/shape)

```xml
<mxCell id="ID" value="LABEL" style="STYLE_STRING"
        vertex="1" parent="1">
  <mxGeometry x="X" y="Y" width="W" height="H"
              as="geometry"/>
</mxCell>
```

### Edge (arrow/line)

```xml
<mxCell id="ID" value="LABEL" style="STYLE_STRING"
        edge="1" parent="1">
  <mxGeometry as="geometry">
    <mxPoint x="X1" y="Y1" as="sourcePoint"/>
    <mxPoint x="X2" y="Y2" as="targetPoint"/>
  </mxGeometry>
</mxCell>
```

## Style Strings

Semicolon-separated key=value pairs:

| Key          | Values                              |
|--------------|-------------------------------------|
| fillColor    | #hex                                |
| strokeColor  | #hex                                |
| fontColor    | #hex                                |
| fontSize     | integer                             |
| fontStyle    | 0=normal, 1=bold, 2=italic, 4=underline (bitmask) |
| rounded      | 0 or 1                              |
| shape        | rhombus, ellipse, etc.              |
| whiteSpace   | wrap                                |
| align        | left, center, right                 |
| endArrow     | block, classic, open, none          |
| endFill      | 0 or 1                              |
| strokeWidth  | float                               |

Example: `rounded=1;fillColor=#d5e8d4;strokeColor=#82b366;fontSize=12;`

## SVG Arrow Markers

```xml
<marker id="arrowBlue" markerWidth="10" markerHeight="7"
        refX="10" refY="3.5" orient="auto">
  <polygon points="0 0, 10 3.5, 0 7" fill="#0066CC"/>
</marker>
```

## LaTeX Integration

XeLaTeX cannot include SVG directly. Convert first:

```bash
# Single file
rsvg-convert -f pdf -o figure.pdf figure.drawio.svg

# Makefile rule
figures/%.pdf: figures/%.drawio.svg
	rsvg-convert -f pdf -o $@ $<
```

Then use `\includegraphics{figure}` (no extension needed).

Requires: `brew install librsvg`
