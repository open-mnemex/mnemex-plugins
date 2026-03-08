---
name: chrome-bookmark-manager
description: >
  Manage Chrome bookmarks from the terminal via the chrome-bookmarks CLI.
  Use when the user wants to: (1) list, search, or browse Chrome bookmarks,
  (2) create bookmark folders, (3) move, rename, or delete bookmarks,
  (4) organize bookmarks in bulk with pattern matching,
  (5) get the full bookmark tree as JSON.
  Triggers (EN): "list bookmarks", "search bookmarks", "move bookmarks",
  "organize bookmarks", "bookmark folder", "chrome bookmarks", "bookmark tree".
  Triggers (中文): "书签", "收藏夹", "整理书签", "移动书签".
---

# Chrome Bookmark Manager

CLI tool that manages Chrome bookmarks via the `chrome.bookmarks` API through a native messaging bridge.

## Architecture

```
CLI (chrome-bookmarks) → Unix Socket → Native Messaging Host (Python) → Chrome Extension → chrome.bookmarks API
```

Installed at: `~/Developer/chrome-bookmark-manager/`

## CLI Usage

```bash
chrome-bookmarks list <path>                           # List folder contents
chrome-bookmarks tree                                  # Full bookmark tree (JSON)
chrome-bookmarks search <query>                        # Search bookmarks
chrome-bookmarks mkdir <path>                          # Create folder
chrome-bookmarks move --pattern <regex> <src> <dst>    # Move matching items
chrome-bookmarks rename <id> <title>                   # Rename bookmark/folder
chrome-bookmarks remove <id>                           # Delete bookmark/folder
```

Path format: `"Bookmarks Bar/FolderName/SubFolder"` — slash-separated from root.

## Programmatic Access via Socket

For operations not covered by CLI (e.g., `move_by_id`), connect directly to the Unix socket:

```python
import socket, json
sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
sock.settimeout(5)
sock.connect("/tmp/chrome-bookmarks.sock")
req = json.dumps({"command": "move_by_id", "args": {"id": "455", "parentId": "1"}})
sock.sendall(req.encode())
sock.shutdown(socket.SHUT_WR)
data = b""
while True:
    chunk = sock.recv(65536)
    if not chunk: break
    data += chunk
print(json.loads(data))
sock.close()
```

### Supported commands

| Command | Args | Description |
|---------|------|-------------|
| `list` | `{path}` | List folder children |
| `tree` | `{}` | Full bookmark tree |
| `search` | `{query}` | Search by title/URL |
| `mkdir` | `{path}` | Create folder at path |
| `move` | `{pattern, source, destination}` | Move regex-matched items between folders |
| `move_by_id` | `{id, parentId, index?}` | Move single item by bookmark ID |
| `rename` | `{id, title}` | Rename bookmark/folder |
| `remove` | `{id}` | Delete bookmark/folder |
| `ping` | `{}` | Health check |

### Key bookmark IDs

- `"0"` — root node
- `"1"` — Bookmarks Bar
- `"2"` — Other Bookmarks

## Troubleshooting

If CLI returns "Host not running":
1. Ensure Chrome is open with the extension loaded from `~/Developer/chrome-bookmark-manager/extension/`
2. Reload the extension at `chrome://extensions`
3. Check socket exists: `ls /tmp/chrome-bookmarks.sock`

## Extension Source

Full source code is bundled in `assets/` for reinstallation or modification:
- `assets/extension/manifest.json` — MV3 manifest (permissions: bookmarks, nativeMessaging)
- `assets/extension/background.js` — Service worker (native host bridge + all bookmark commands)
- `assets/host/chrome_bookmarks_host.py` — Python asyncio native messaging host
- `assets/host/com.danieltang.chrome_bookmarks.json` — Native messaging host manifest
- `assets/chrome-bookmarks` — CLI script (symlinked to `~/.local/bin/`)
- `assets/install.sh` — Install script (copies manifest, creates symlink)

Extension ID: `hlamepcmhoalekmlbkclpfckalogcpmp`
