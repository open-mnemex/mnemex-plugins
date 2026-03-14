#!/bin/bash
# Convert all .drawio.svg files in a directory to .pdf via rsvg-convert
# Usage: svg2pdf.sh [directory]
# Default: current directory's figures/ folder

DIR="${1:-.}"

if ! command -v rsvg-convert &>/dev/null; then
    echo "[svg2pdf] rsvg-convert not found. Install: brew install librsvg"
    exit 1
fi

count=0
for svg in "$DIR"/*.drawio.svg; do
    [ -f "$svg" ] || continue
    pdf="${svg%.drawio.svg}.pdf"
    if [ "$svg" -nt "$pdf" ] || [ ! -f "$pdf" ]; then
        echo "[svg→pdf] $svg"
        rsvg-convert -f pdf -o "$pdf" "$svg"
        count=$((count + 1))
    fi
done

if [ $count -eq 0 ]; then
    echo "[svg2pdf] No files to convert in $DIR"
else
    echo "[svg2pdf] Converted $count file(s)"
fi
