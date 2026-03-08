#!/bin/bash
set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOST_DIR="$PROJECT_DIR/host"
CLI_DIR="$PROJECT_DIR/cli"
EXTENSION_DIR="$PROJECT_DIR/extension"

NATIVE_HOST_DIR="$HOME/Library/Application Support/Google/Chrome/NativeMessagingHosts"
MANIFEST_NAME="com.danieltang.chrome_bookmarks.json"
CLI_LINK="$HOME/.local/bin/chrome-bookmarks"

echo "=== Chrome Bookmark Manager Installer ==="
echo

# 1. Install native messaging host manifest
echo "[1/3] Installing native messaging host manifest..."
mkdir -p "$NATIVE_HOST_DIR"
cp "$HOST_DIR/$MANIFEST_NAME" "$NATIVE_HOST_DIR/$MANIFEST_NAME"
echo "  → $NATIVE_HOST_DIR/$MANIFEST_NAME"

# 2. Create CLI symlink
echo "[2/3] Creating CLI symlink..."
if [ -L "$CLI_LINK" ] || [ -e "$CLI_LINK" ]; then
    rm "$CLI_LINK"
fi
ln -s "$CLI_DIR/chrome-bookmarks" "$CLI_LINK"
echo "  → $CLI_LINK → $CLI_DIR/chrome-bookmarks"

# 3. Reminder about extension
echo "[3/3] Extension setup..."
echo "  Extension directory: $EXTENSION_DIR"
echo

echo "=== Installation complete ==="
echo
echo "Next steps:"
echo "  1. Open Chrome → chrome://extensions"
echo "  2. Enable 'Developer mode' (top right)"
echo "  3. Click 'Load unpacked' → select: $EXTENSION_DIR"
echo "  4. Note the Extension ID and update the host manifest's allowed_origins"
echo "     File: $NATIVE_HOST_DIR/$MANIFEST_NAME"
echo '     Add:  "allowed_origins": ["chrome-extension://<EXTENSION_ID>/"]'
echo "  5. Reload the extension after updating the manifest"
echo "  6. Test: chrome-bookmarks tree"
