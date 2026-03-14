#!/bin/bash
# Pre-compile wechat tools to binaries for ~5x faster execution
set -e
DIR="$(cd "$(dirname "$0")" && pwd)"
BIN="$DIR/../bin"
mkdir -p "$BIN"

echo "Compiling wechat_tool..."
swiftc "$DIR/wechat_tool.swift" -o "$BIN/wechat_tool" -O -framework Vision 2>&1

echo "Compiling ocr_locate..."
swiftc "$DIR/ocr_locate.swift" -o "$BIN/ocr_locate" -O -framework Vision -framework AppKit 2>&1

echo "Done. Binaries in $BIN/"
ls -lh "$BIN/"
