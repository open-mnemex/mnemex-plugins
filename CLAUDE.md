# mnemex-plugins

## Versioning

When adding new skills, updating existing skill content, or modifying
agents, **always bump the version** in the affected plugin's
`.claude-plugin/plugin.json`.

Without a version bump, downstream installations will not pull updates.

**Rules:**
- New skill or agent added → bump **minor** (e.g., 1.1.0 → 1.2.0)
- Existing skill content updated → bump **patch** (e.g., 1.2.0 → 1.2.1)
- Breaking change to skill interface → bump **major** (e.g., 1.2.1 → 2.0.0)

**Affected files (one per plugin):**
- `plugins/dev-tools/.claude-plugin/plugin.json`
- `plugins/mnemex-core/.claude-plugin/plugin.json`
- `plugins/macos-automation/.claude-plugin/plugin.json`
