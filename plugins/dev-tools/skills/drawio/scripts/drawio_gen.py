#!/usr/bin/env python3
"""
drawio_gen.py — Generate .drawio.svg from structured Python dicts.

Usage:
    uv run --with pyyaml scripts/drawio_gen.py spec.yaml output.drawio.svg
    uv run --with pyyaml scripts/drawio_gen.py spec.json output.drawio.svg

Or import as library:
    from drawio_gen import render_drawio_svg
    svg = render_drawio_svg(spec_dict)
"""

import html
import json
import sys
import uuid
from pathlib import Path

# ── Color Palette (matches MEMORY.md diagram strategy) ──────────
PALETTE = {
    "green":  {"fill": "#d5e8d4", "stroke": "#82b366", "font": "#006600"},
    "blue":   {"fill": "#dae8fc", "stroke": "#6c8ebf", "font": "#003366"},
    "yellow": {"fill": "#fff2cc", "stroke": "#d6b656", "font": "#333333"},
    "purple": {"fill": "#e1d5e7", "stroke": "#9673a6", "font": "#4a235a"},
    "red":    {"fill": "#f8cecc", "stroke": "#b85450", "font": "#990000"},
    "gray":   {"fill": "#f5f5f5", "stroke": "#cccccc", "font": "#333333"},
    "white":  {"fill": "#ffffff", "stroke": "#cccccc", "font": "#333333"},
    "dark":   {"fill": "#333333", "stroke": "#333333", "font": "#ffffff"},
}

ARROW_COLORS = {
    "blue":  "#0066CC",
    "green": "#009900",
    "red":   "#CC0000",
    "gray":  "#666666",
    "black": "#333333",
}

FONT = 'Arial, sans-serif'
DEFAULT_FONT_SIZE = 12


# ── Helpers ──────────────────────────────────────────────────────

def _uid():
    return uuid.uuid4().hex[:8]


def _esc(text):
    return html.escape(str(text))


def _mx_esc(text):
    """Double-escape for drawio content attribute (XML inside XML)."""
    return html.escape(html.escape(str(text)))


def _resolve_color(name_or_hex, default="blue"):
    if name_or_hex and name_or_hex.startswith("#"):
        return name_or_hex
    return ARROW_COLORS.get(name_or_hex, ARROW_COLORS.get(default, "#333333"))


def _resolve_palette(name_or_dict, default="gray"):
    if isinstance(name_or_dict, dict):
        return name_or_dict
    return PALETTE.get(name_or_dict, PALETTE.get(default))


# ── SVG Primitives ───────────────────────────────────────────────

def svg_rect(x, y, w, h, pal, rx=0):
    p = _resolve_palette(pal)
    r = f' rx="{rx}" ry="{rx}"' if rx else ''
    return (f'<rect x="{x}" y="{y}" width="{w}" height="{h}"{r} '
            f'fill="{p["fill"]}" stroke="{p["stroke"]}" '
            f'stroke-width="1"/>')


def svg_text(x, y, text, size=DEFAULT_FONT_SIZE, anchor="middle",
             fill="#333", bold=False, italic=False):
    fw = ' font-weight="bold"' if bold else ''
    fs = ' font-style="italic"' if italic else ''
    return (f'<text x="{x}" y="{y}" font-family="{FONT}" '
            f'font-size="{size}"{fw}{fs} text-anchor="{anchor}" '
            f'fill="{fill}">{_esc(text)}</text>')


def svg_line(x1, y1, x2, y2, color="#333", width=2, dashed=False,
             marker_end=None):
    da = ' stroke-dasharray="6,3"' if dashed else ''
    me = f' marker-end="url(#{marker_end})"' if marker_end else ''
    return (f'<line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" '
            f'stroke="{color}" stroke-width="{width}"{da}{me}/>')


def svg_arrow_marker(marker_id, color):
    return (f'<marker id="{marker_id}" markerWidth="10" '
            f'markerHeight="7" refX="10" refY="3.5" orient="auto">'
            f'<polygon points="0 0, 10 3.5, 0 7" fill="{color}"/>'
            f'</marker>')


# ── Diagram Types ────────────────────────────────────────────────

def build_sequence(spec, offset_x=0, offset_y=0):
    """Build a sequence diagram from spec.

    spec = {
        "title": "Three-Way Handshake",
        "title_color": "green",
        "participants": ["Client", "Server"],
        "spacing": 210,   # horizontal distance between participants
        "messages": [
            {"from": 0, "to": 1, "label": "SYN (seq=x)",
             "color": "blue"},
            {"from": 1, "to": 0, "label": "SYN-ACK",
             "color": "green"},
        ],
        "footer": "Connection Established",
        "footer_color": "green",
    }
    """
    parts = spec["participants"]
    spacing = spec.get("spacing", 210)
    msg_gap = spec.get("message_gap", 45)
    msgs = spec.get("messages", [])
    title = spec.get("title", "")
    title_color = spec.get("title_color", "green")
    footer = spec.get("footer", "")
    footer_color = spec.get("footer_color", "green")

    total_w = spacing * (len(parts) - 1) + 120
    ox, oy = offset_x, offset_y
    svg_parts = []
    markers = {}

    # Title
    cur_y = oy
    if title:
        tp = _resolve_palette(title_color)
        svg_parts.append(svg_rect(
            ox, cur_y, total_w, 26, title_color, rx=6))
        svg_parts.append(svg_text(
            ox + total_w // 2, cur_y + 18, title,
            size=13, fill=tp["font"], bold=True, italic=True))
        cur_y += 34

    # Participant labels
    part_xs = [ox + 30 + i * spacing for i in range(len(parts))]
    for i, name in enumerate(parts):
        svg_parts.append(svg_text(
            part_xs[i], cur_y + 14, name,
            size=12, fill="#333", bold=True))
    cur_y += 22

    # Lifelines start
    lifeline_start = cur_y
    lifeline_end = cur_y + len(msgs) * msg_gap + 30

    for px in part_xs:
        svg_parts.append(svg_line(
            px, lifeline_start, px, lifeline_end,
            color="#333", width=2, dashed=True))

    # Messages
    msg_y = lifeline_start + 20
    for msg in msgs:
        fi, ti = msg["from"], msg["to"]
        x1, x2 = part_xs[fi], part_xs[ti]
        color = _resolve_color(msg.get("color", "blue"))
        label = msg.get("label", "")

        mid = (x1 + x2) // 2
        marker_id = f"arrow_{_uid()}"
        markers[marker_id] = color

        dashed = msg.get("dashed", False)
        svg_parts.append(svg_line(
            x1, msg_y, x2, msg_y + 20,
            color=color, width=1.5, dashed=dashed,
            marker_end=marker_id))
        svg_parts.append(svg_text(
            mid, msg_y - 4, label,
            size=11, fill=color, bold=True))

        # Optional note below message
        if msg.get("note"):
            svg_parts.append(svg_text(
                mid, msg_y + 14, msg["note"],
                size=10, fill="#666", italic=True))

        msg_y += msg_gap

    cur_y = lifeline_end

    # Footer
    if footer:
        fp = _resolve_palette(footer_color)
        fw = total_w - 40
        svg_parts.append(svg_rect(
            ox + 20, cur_y, fw, 24, footer_color, rx=6))
        svg_parts.append(svg_text(
            ox + total_w // 2, cur_y + 16, footer,
            size=11, fill=fp["font"], italic=True))
        cur_y += 32

    return svg_parts, markers, cur_y - oy


def build_table(spec, offset_x=0, offset_y=0):
    """Build a comparison table from spec.

    spec = {
        "title": "Key Differences",
        "title_color": "purple",
        "columns": [
            {"header": "Feature", "color": "dark", "width": 200},
            {"header": "TCP", "color": "green", "width": 200},
            {"header": "UDP", "color": "blue", "width": 200},
        ],
        "rows": [
            ["Connection", "3-way handshake", "None"],
            ["Reliability", "ACK + Retransmit", "Best-effort"],
        ],
    }
    """
    cols = spec["columns"]
    rows = spec.get("rows", [])
    title = spec.get("title", "")
    title_color = spec.get("title_color", "purple")
    row_h = spec.get("row_height", 24)
    header_h = spec.get("header_height", 30)

    total_w = sum(c.get("width", 160) for c in cols)
    ox, oy = offset_x, offset_y
    svg_parts = []
    cur_y = oy

    # Title
    if title:
        tp = _resolve_palette(title_color)
        svg_parts.append(svg_rect(
            ox, cur_y, total_w, 30, title_color, rx=8))
        svg_parts.append(svg_text(
            ox + total_w // 2, cur_y + 21, title,
            size=14, fill=tp["font"], bold=True, italic=True))
        cur_y += 38

    # Header row
    cx = ox
    for col in cols:
        w = col.get("width", 160)
        p = _resolve_palette(col.get("color", "dark"))
        svg_parts.append(svg_rect(cx, cur_y, w, header_h, col.get("color", "dark")))
        svg_parts.append(svg_text(
            cx + w // 2, cur_y + header_h - 10, col["header"],
            size=12, fill=p["font"], bold=True))
        cx += w
    cur_y += header_h

    # Data rows
    for ri, row in enumerate(rows):
        bg = "gray" if ri % 2 == 0 else "white"
        cx = ox
        for ci, cell in enumerate(row):
            w = cols[ci].get("width", 160)
            svg_parts.append(svg_rect(cx, cur_y, w, row_h, bg))
            svg_parts.append(svg_text(
                cx + w // 2, cur_y + row_h - 8, cell,
                size=11, fill="#333"))
            cx += w
        cur_y += row_h

    return svg_parts, {}, cur_y - oy


def build_note_box(spec, offset_x=0, offset_y=0):
    """Build a note/bullet-point box.

    spec = {
        "title": "UDP Characteristics",
        "color": "blue",
        "items": [
            "No connection state",
            "Each datagram independent",
        ],
    }
    """
    items = spec.get("items", [])
    color = spec.get("color", "blue")
    title = spec.get("title", "")
    width = spec.get("width", 320)
    line_h = spec.get("line_height", 18)

    ox, oy = offset_x, offset_y
    svg_parts = []
    cur_y = oy
    p = _resolve_palette(color)

    if title:
        svg_parts.append(svg_rect(ox, cur_y, width, 26, color, rx=6))
        svg_parts.append(svg_text(
            ox + width // 2, cur_y + 18, title,
            size=12, fill=p["font"], bold=True, italic=True))
        cur_y += 34

    box_h = len(items) * line_h + 16
    svg_parts.append(svg_rect(ox, cur_y, width, box_h, color, rx=8))
    item_y = cur_y + line_h
    for item in items:
        svg_parts.append(svg_text(
            ox + 12, item_y, f"\u2022 {item}",
            size=11, fill=p["font"], anchor="start"))
        item_y += line_h
    cur_y += box_h

    return svg_parts, {}, cur_y - oy


def build_flowchart(spec, offset_x=0, offset_y=0):
    """Build a simple top-to-bottom flowchart.

    spec = {
        "nodes": [
            {"id": "start", "label": "Start", "color": "green",
             "shape": "rounded"},
            {"id": "check", "label": "Valid?", "color": "yellow",
             "shape": "diamond"},
            {"id": "ok", "label": "Process", "color": "blue"},
            {"id": "fail", "label": "Error", "color": "red"},
        ],
        "edges": [
            {"from": "start", "to": "check"},
            {"from": "check", "to": "ok", "label": "Yes"},
            {"from": "check", "to": "fail", "label": "No",
             "direction": "right"},
        ],
    }
    """
    nodes = spec.get("nodes", [])
    edges = spec.get("edges", [])
    node_w = spec.get("node_width", 160)
    node_h = spec.get("node_height", 40)
    v_gap = spec.get("vertical_gap", 60)
    h_gap = spec.get("horizontal_gap", 200)

    ox, oy = offset_x, offset_y
    svg_parts = []
    markers = {}

    # Layout: simple column layout for now
    positions = {}
    col_offsets = {}  # track rightward branches
    cur_y = oy
    main_x = ox + h_gap  # center column

    for node in nodes:
        nid = node["id"]
        direction = None
        # Check if any edge targets this node with a direction
        for e in edges:
            if e.get("to") == nid and e.get("direction") == "right":
                direction = "right"
                break
            if e.get("to") == nid and e.get("direction") == "left":
                direction = "left"
                break

        if direction == "right":
            positions[nid] = (main_x + h_gap, cur_y - v_gap - node_h)
        elif direction == "left":
            positions[nid] = (main_x - h_gap, cur_y - v_gap - node_h)
        else:
            positions[nid] = (main_x, cur_y)
            cur_y += node_h + v_gap

    # Draw nodes
    for node in nodes:
        nid = node["id"]
        nx, ny = positions[nid]
        color = node.get("color", "gray")
        p = _resolve_palette(color)
        shape = node.get("shape", "rect")
        label = node.get("label", nid)

        if shape == "diamond":
            cx, cy = nx + node_w // 2, ny + node_h // 2
            pts = (f"{cx},{ny} {nx + node_w},{cy} "
                   f"{cx},{ny + node_h} {nx},{cy}")
            svg_parts.append(
                f'<polygon points="{pts}" fill="{p["fill"]}" '
                f'stroke="{p["stroke"]}" stroke-width="1.5"/>')
            svg_parts.append(svg_text(
                cx, cy + 5, label, size=11,
                fill=p["font"], bold=True))
        else:
            rx = 8 if shape == "rounded" else 0
            svg_parts.append(svg_rect(
                nx, ny, node_w, node_h, color, rx=rx))
            svg_parts.append(svg_text(
                nx + node_w // 2, ny + node_h // 2 + 5, label,
                size=12, fill=p["font"], bold=True))

    # Draw edges
    for edge in edges:
        fid, tid = edge["from"], edge["to"]
        if fid not in positions or tid not in positions:
            continue
        fx, fy = positions[fid]
        tx, ty = positions[tid]

        color = _resolve_color(edge.get("color", "black"))
        marker_id = f"arrow_{_uid()}"
        markers[marker_id] = color

        # Connect bottom-center of source to top-center of target
        direction = edge.get("direction")
        if direction == "right":
            x1, y1 = fx + node_w, fy + node_h // 2
            x2, y2 = tx, ty + node_h // 2
        elif direction == "left":
            x1, y1 = fx, fy + node_h // 2
            x2, y2 = tx + node_w, ty + node_h // 2
        else:
            x1, y1 = fx + node_w // 2, fy + node_h
            x2, y2 = tx + node_w // 2, ty

        svg_parts.append(svg_line(
            x1, y1, x2, y2, color=color, width=1.5,
            marker_end=marker_id))

        if edge.get("label"):
            mx, my = (x1 + x2) // 2, (y1 + y2) // 2
            svg_parts.append(svg_text(
                mx + 10, my - 4, edge["label"],
                size=10, fill=color, bold=True))

    return svg_parts, markers, cur_y - oy


def build_topology(spec, offset_x=0, offset_y=0):
    """Build a network topology diagram.

    spec = {
        "nodes": [
            {"id": "client", "label": "Client", "x": 100, "y": 50,
             "color": "blue", "shape": "rounded"},
            {"id": "server", "label": "Server", "x": 400, "y": 50,
             "color": "green"},
        ],
        "links": [
            {"from": "client", "to": "server",
             "label": "TCP 26000", "color": "blue"},
        ],
    }
    """
    nodes = spec.get("nodes", [])
    links = spec.get("links", [])
    node_w = spec.get("node_width", 120)
    node_h = spec.get("node_height", 50)

    ox, oy = offset_x, offset_y
    svg_parts = []
    markers = {}
    positions = {}

    max_y = oy

    # Draw nodes
    for node in nodes:
        nid = node["id"]
        nx = ox + node.get("x", 0)
        ny = oy + node.get("y", 0)
        positions[nid] = (nx, ny)
        max_y = max(max_y, ny + node_h)

        color = node.get("color", "gray")
        p = _resolve_palette(color)
        shape = node.get("shape", "rect")
        rx = 8 if shape == "rounded" else 0

        svg_parts.append(svg_rect(nx, ny, node_w, node_h, color, rx=rx))

        label = node.get("label", nid)
        lines = label.split("\n")
        for li, line in enumerate(lines):
            ly = ny + node_h // 2 + 5 + (li - (len(lines) - 1) / 2) * 16
            svg_parts.append(svg_text(
                nx + node_w // 2, ly, line,
                size=11, fill=p["font"],
                bold=(li == 0)))

    # Draw links
    for link in links:
        fid, tid = link["from"], link["to"]
        if fid not in positions or tid not in positions:
            continue
        fx, fy = positions[fid]
        tx, ty = positions[tid]

        # Center-to-center
        x1 = fx + node_w // 2
        y1 = fy + node_h // 2
        x2 = tx + node_w // 2
        y2 = ty + node_h // 2

        color = _resolve_color(link.get("color", "gray"))
        bidirectional = link.get("bidirectional", False)

        marker_id = f"arrow_{_uid()}"
        markers[marker_id] = color

        svg_parts.append(svg_line(
            x1, y1, x2, y2, color=color, width=1.5,
            dashed=link.get("dashed", False),
            marker_end=marker_id))

        if link.get("label"):
            mx = (x1 + x2) // 2
            my = (y1 + y2) // 2 - 8
            svg_parts.append(svg_text(
                mx, my, link["label"],
                size=10, fill=color, bold=True))

    return svg_parts, markers, max_y - oy + 20


# ── MxGraph XML Generation ──────────────────────────────────────

def _build_mxgraph_xml(spec, width, height):
    """Build the drawio mxGraphModel XML from the same spec.

    This creates a minimal but valid mxGraphModel that draw.io can
    open and edit. We use a simplified approach: one mxCell per
    visual element.
    """
    cells = ['<mxCell id="0"/>', '<mxCell id="1" parent="0"/>']
    cell_id = 10

    sections = spec.get("sections", [spec])
    for section in sections:
        dtype = section.get("type", "sequence")

        if dtype == "sequence":
            cells.extend(_mx_sequence(section, cell_id))
        elif dtype == "table":
            cells.extend(_mx_table(section, cell_id))
        elif dtype == "note":
            cells.extend(_mx_note(section, cell_id))
        elif dtype == "flowchart":
            cells.extend(_mx_flowchart(section, cell_id))
        elif dtype == "topology":
            cells.extend(_mx_topology(section, cell_id))

        cell_id += 100

    root_xml = "\n".join(cells)
    return (
        f'<mxfile host="app.diagrams.net">'
        f'<diagram name="Diagram" id="diagram-1">'
        f'<mxGraphModel dx="{width}" dy="{height}" grid="1" '
        f'gridSize="10" guides="1" tooltips="1" connect="1" '
        f'arrows="1" fold="1" page="1" pageScale="1" '
        f'pageWidth="{width}" pageHeight="{height}">'
        f'<root>{root_xml}</root>'
        f'</mxGraphModel></diagram></mxfile>'
    )


def _mx_cell(cid, value, style, x, y, w, h, is_edge=False,
             src=None, tgt=None):
    """Generate a single mxCell XML string."""
    v = _esc(value)
    if is_edge:
        geo = (f'<mxGeometry as="geometry">'
               f'<mxPoint x="{x}" y="{y}" as="sourcePoint"/>'
               f'<mxPoint x="{w}" y="{h}" as="targetPoint"/>'
               f'</mxGeometry>')
        return (f'<mxCell id="{cid}" value="{v}" style="{style}" '
                f'edge="1" parent="1">{geo}</mxCell>')
    else:
        geo = (f'<mxGeometry x="{x}" y="{y}" width="{w}" '
               f'height="{h}" as="geometry"/>')
        return (f'<mxCell id="{cid}" value="{v}" style="{style}" '
                f'vertex="1" parent="1">{geo}</mxCell>')


def _mx_style(pal_name, **kw):
    """Build a drawio style string."""
    p = _resolve_palette(pal_name)
    parts = [
        f'fillColor={p["fill"]}',
        f'strokeColor={p["stroke"]}',
        f'fontColor={p["font"]}',
    ]
    defaults = {
        "rounded": "1", "whiteSpace": "wrap",
        "fontSize": "12", "align": "center",
    }
    defaults.update(kw)
    for k, v in defaults.items():
        parts.append(f'{k}={v}')
    return ";".join(parts) + ";"


def _mx_sequence(spec, base_id):
    cells = []
    cid = base_id
    title = spec.get("title", "")
    if title:
        cells.append(_mx_cell(
            cid, title,
            _mx_style(spec.get("title_color", "green"),
                       fontStyle="5", fontSize="13"),
            0, 0, 300, 26))
        cid += 1
    for msg in spec.get("messages", []):
        color = _resolve_color(msg.get("color", "blue"))
        cells.append(_mx_cell(
            cid, msg.get("label", ""),
            f'endArrow=block;endFill=1;strokeColor={color};'
            f'strokeWidth=1.5;fontSize=11;fontColor={color};',
            0, 0, 100, 100, is_edge=True))
        cid += 1
    return cells


def _mx_table(spec, base_id):
    cells = []
    cid = base_id
    for col in spec.get("columns", []):
        cells.append(_mx_cell(
            cid, col["header"],
            _mx_style(col.get("color", "dark"), fontStyle="1"),
            0, 0, col.get("width", 160), 30))
        cid += 1
    return cells


def _mx_note(spec, base_id):
    cells = []
    cid = base_id
    items = spec.get("items", [])
    text = "\\n".join(f"• {it}" for it in items)
    cells.append(_mx_cell(
        cid, text,
        _mx_style(spec.get("color", "blue"),
                   align="left", spacingLeft="8"),
        0, 0, spec.get("width", 320), len(items) * 18 + 16))
    return cells


def _mx_flowchart(spec, base_id):
    cells = []
    cid = base_id
    for node in spec.get("nodes", []):
        shape = node.get("shape", "rect")
        extra = {}
        if shape == "diamond":
            extra["shape"] = "rhombus"
        elif shape == "rounded":
            extra["rounded"] = "1"
        cells.append(_mx_cell(
            cid, node.get("label", node["id"]),
            _mx_style(node.get("color", "gray"), **extra),
            node.get("x", 0), node.get("y", 0), 160, 40))
        cid += 1
    return cells


def _mx_topology(spec, base_id):
    cells = []
    cid = base_id
    for node in spec.get("nodes", []):
        cells.append(_mx_cell(
            cid, node.get("label", node["id"]),
            _mx_style(node.get("color", "gray"), rounded="1"),
            node.get("x", 0), node.get("y", 0), 120, 50))
        cid += 1
    return cells


# ── Main Renderer ────────────────────────────────────────────────

BUILDERS = {
    "sequence":  build_sequence,
    "table":     build_table,
    "note":      build_note_box,
    "flowchart": build_flowchart,
    "topology":  build_topology,
}


def render_drawio_svg(spec):
    """Render a full .drawio.svg from a spec dict.

    spec = {
        "width": 920,
        "height": 820,
        "background": "#ffffff",
        "sections": [
            {"type": "sequence", "offset_x": 40, "offset_y": 10,
             ...},
            {"type": "table", "offset_x": 120, "offset_y": 640,
             ...},
        ],
    }

    Or a single-section shortcut (type at top level).
    """
    # Handle single-section shortcut
    if "type" in spec and "sections" not in spec:
        spec = {
            "width": spec.get("width", 800),
            "height": spec.get("height", 600),
            "sections": [spec],
        }

    width = spec.get("width", 800)
    height = spec.get("height", 600)
    bg = spec.get("background", "#ffffff")

    all_svg = []
    all_markers = {}

    for section in spec.get("sections", []):
        dtype = section.get("type", "sequence")
        builder = BUILDERS.get(dtype)
        if not builder:
            continue

        ox = section.get("offset_x", 0)
        oy = section.get("offset_y", 0)
        parts, markers, h = builder(section, offset_x=ox, offset_y=oy)
        all_svg.extend(parts)
        all_markers.update(markers)

    # Build drawio XML
    mx_xml = _build_mxgraph_xml(spec, width, height)
    content_attr = _esc(mx_xml)

    # Assemble SVG
    marker_defs = "\n    ".join(
        svg_arrow_marker(mid, color)
        for mid, color in all_markers.items()
    )

    body = "\n    ".join(all_svg)

    svg = f'''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN" \
"http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd">
<svg xmlns="http://www.w3.org/2000/svg"
     xmlns:xlink="http://www.w3.org/1999/xlink"
     version="1.1" width="{width}px" height="{height}px"
     viewBox="-0.5 -0.5 {width} {height}"
     content="{content_attr}"
     style="background-color: {bg};">
  <defs>
    {marker_defs}
  </defs>
  <g>
    {body}
  </g>
</svg>'''

    return svg


# ── CLI ──────────────────────────────────────────────────────────

def main():
    if len(sys.argv) < 3:
        print("Usage: drawio_gen.py <spec.yaml|spec.json> <out.drawio.svg>")
        sys.exit(1)

    spec_path = Path(sys.argv[1])
    out_path = Path(sys.argv[2])

    raw = spec_path.read_text(encoding="utf-8")
    if spec_path.suffix in (".yaml", ".yml"):
        import yaml
        spec = yaml.safe_load(raw)
    else:
        spec = json.loads(raw)

    svg = render_drawio_svg(spec)
    out_path.write_text(svg, encoding="utf-8")
    print(f"[drawio] Written {out_path} ({len(svg)} bytes)")


if __name__ == "__main__":
    main()
