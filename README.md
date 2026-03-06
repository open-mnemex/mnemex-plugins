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

LaTeX, PDF toolkit, image generation, and more.

| Skills | Agents |
|--------|--------|
| `/latex` | `—` |
| `/pdf` | |
| `/skill-creator` | |
| `/nano-banana-pro` | |
| `—` | `code-improvement-reviewer` |

## Install

### Interactive

```bash
# Add the marketplace
/plugin marketplace add open-mnemex/mnemex-plugins

# Install what you need
/plugin install mnemex-core@mnemex
/plugin install macos-automation@mnemex
/plugin install dev-tools@mnemex
```

### Headless (CLI)

```bash
# Add the marketplace from GitHub (owner/repo shorthand)
claude plugin marketplace add open-mnemex/mnemex-plugins

# Or use the full URL
claude plugin marketplace add https://github.com/open-mnemex/mnemex-plugins

# Install what you need
claude plugin install mnemex-core@mnemex
claude plugin install macos-automation@mnemex
claude plugin install dev-tools@mnemex
```

## Personal Data

Do not store personal facts inside this repository.

Initialize local private facts storage:

```bash
bash scripts/bootstrap-user.sh
```

Private data is created under `~/.mnemex/facts/<skill-name>/facts.yaml` and will not be overwritten by skill updates.

## Contributing

Use Issue + PR workflow:

1. Open an Issue first (`bug` or `feature`)
2. Create a branch
3. Open a PR linked to the Issue
4. Merge with squash after checks pass

See [CONTRIBUTING.md](CONTRIBUTING.md) for full rules.

## License

[MIT](LICENSE)
