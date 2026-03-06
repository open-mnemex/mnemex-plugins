# Personal Data Policy

This repository is public skill code. Personal data must stay outside this repo.

## Storage Model

- Public skill code: this repository only
- Private user facts: `~/.mnemex/facts/<skill-name>/facts.yaml`
- Secrets (tokens/passwords): OS keychain or secret manager

Do not store real personal data under `plugins/`, `references/`, or `README.md`.

## Why

Skill updates replace or overwrite installed skill content. If users put personal data in skill files, it can be lost during update.

## User Setup

Run:

```bash
bash scripts/bootstrap-user.sh
```

This creates:

```text
~/.mnemex/facts/<skill-name>/facts.yaml
```

Each file is created from `templates/facts.example.yaml` and set to permission `600`.

## For Skill Authors

- Keep examples anonymized (`example.com`, `Example Contact`, `EXAMPLE_ACCOUNT_ID`).
- If a skill needs user-specific facts, read from `~/.mnemex/facts/<skill-name>/facts.yaml`.
- Never write personal data back into repository files.
