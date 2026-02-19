# mnemex-plugins

Claude Code plugin marketplace for
[mnemex](https://github.com/open-mnemex/core) — AI-powered digital
life management.

## Plugins

### `mnemex-core` — Digital Life System

Capture, inbox processing, and project lifecycle management.

| Skills | Agents |
|--------|--------|
| `/capture` | `pdf-analyzer` |
| `/processing-inbox` | `pdf-renamer` |
| `/project` | |

### `macos-automation` — macOS App Automation

Control native macOS apps via AppleScript.

| Skills |
|--------|
| `/calendar-automation` |
| `/mail-automation` |
| `/reminders-automation` |
| `/safari-automation` |
| `/wechat-control` |

### `dev-tools` — Developer Tools

LaTeX, Chrome DevTools, PDF toolkit, image generation, and more.

| Skills | Agents |
|--------|--------|
| `/latex` | `chinese-translator` |
| `/chrome-devtools` | `code-improvement-reviewer` |
| `/pdf` | |
| `/skill-creator` | |
| `/nano-banana-pro` | |
| `/jsonl-to-markdown` | |

## Install

### Interactive

```bash
# Add the marketplace
/plugin marketplace add open-mnemex/mnemex-plugins

# Install what you need
/plugin install mnemex-core@mnemex-plugins
/plugin install macos-automation@mnemex-plugins
/plugin install dev-tools@mnemex-plugins
```

### Headless (CLI)

```bash
# Add the marketplace from GitHub (owner/repo shorthand)
claude plugin marketplace add open-mnemex/mnemex-plugins

# Or use the full URL
claude plugin marketplace add https://github.com/open-mnemex/mnemex-plugins

# Install what you need
claude plugin install mnemex-core@mnemex-plugins
claude plugin install macos-automation@mnemex-plugins
claude plugin install dev-tools@mnemex-plugins
```

## License

[MIT](LICENSE)
