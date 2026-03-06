# Contributing

This repository uses a PR-first workflow to keep history clean and auditable.

## Workflow

1. Open an Issue first (`bug` or `feature`).
2. Create a branch from `main`.
3. Use Conventional Commit messages.
4. Open a PR and link the Issue (`Closes #<id>`).
5. Merge with **Squash and merge** after checks pass.

## Branch Naming

- `feat/<short-topic>`
- `fix/<short-topic>`
- `chore/<short-topic>`
- `docs/<short-topic>`

## Commit Message Format

Use Conventional Commits:

```text
<type>(<scope>): <summary>
```

Examples:

```text
feat(mnemex-core): add paper capture type
fix(macos-automation): harden WeChat activation flow
docs(readme): update install and privacy notes
```

Recommended types: `feat`, `fix`, `docs`, `refactor`, `chore`, `test`, `ci`.

## Pull Request Rules

- Keep PRs focused and small.
- One logical change per PR.
- Update docs when behavior changes.
- Never include personal data in repository files.
- Ensure all checks pass.

## Sensitive Data Policy

Personal facts must stay local:

- `~/.mnemex/facts/<skill-name>/facts.yaml`

Do not commit personal emails, names, account IDs, or private paths.
See [docs/PERSONAL-DATA.md](docs/PERSONAL-DATA.md).

