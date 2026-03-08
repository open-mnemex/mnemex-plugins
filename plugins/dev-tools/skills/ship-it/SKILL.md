---
name: ship-it
description: >
  Ship changes through the full GitHub flow:
  Issue -> Branch -> Commit -> PR -> Merge, in one command.
  Adapts to current state: uncommitted changes, existing branch,
  existing issue, submodule repos.
  Triggers (EN): "ship it", "/ship-it", "create PR and merge",
  "issue PR merge", "full PR flow".
  Triggers (中文): "走流程", "发PR", "提交合并", "走一下流程".
---

# /ship-it — Issue + PR + Merge Flow

Ship changes through the complete GitHub workflow. Adapts to whatever
state the repo is in.

## Inputs (all optional)

- **Title / description** — infer from diff if not provided
- **Issue number** — create one if not provided
- **Base branch** — default: `main`

## Workflow

### Step 0: Assess Current State

```bash
git status -u
git branch --show-current
git log --oneline @{upstream}..HEAD 2>/dev/null   # unpushed commits
git diff --stat                                     # uncommitted changes
```

Determine which scenario we're in:

| State | Action |
|-------|--------|
| On `main` with **unpushed commits** | Push main first, then branch for new changes |
| On `main` with **uncommitted changes only** | Create branch, commit, PR, merge |
| On **feature branch** with uncommitted changes | Commit to current branch, push, PR, merge |
| On **feature branch** with pushed commits | Just create PR and merge |
| **No changes at all** | Stop and tell the user |

### Step 1: Ensure Main is Up to Date

If on `main` with unpushed commits AND new uncommitted changes:

```bash
git stash
git push origin main
git stash pop
```

If on `main` with only unpushed commits (no uncommitted changes),
just push — no need for the full flow.

### Step 2: Create GitHub Issue

Skip if user provided an issue number.

- Draft concise title and body from the diff
- `gh issue create --title "..." --body "..."`
- Capture issue number

### Step 3: Branch + Commit

Skip branch creation if already on a feature branch.

- Branch name: `<type>/<short-description>`
  (e.g., `fix/suppress-console-log`, `feat/add-kin-example`)
- `git checkout -b <branch>`
- Stage files **by name** (never `git add -A`)
- If user requests separate commits (e.g., "README 另外 commit"),
  create multiple commits in the same branch
- Commit message format:
  ```
  <type>: <summary> (#<issue>)

  Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
  ```
- Use HEREDOC for multi-line commit messages

### Step 4: Push + Create PR

```bash
git push -u origin <branch>
gh pr create --title "..." --body "$(cat <<'EOF'
## Summary
- Bullet points

Closes #<issue>

## Test plan
- [x] ...

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

### Step 5: Merge + Cleanup

```bash
gh pr merge <pr-number> --squash --delete-branch
git checkout main
git pull origin main
```

### Step 6: Update Submodule (if applicable)

If the repo is a git submodule, update the outer repo:

```bash
cd <outer-repo>
git add <submodule-path>
git commit -m "chore: update submodule - <summary>"
git push origin main
```

Only do this if the outer repo is detected. Check with:
```bash
git rev-parse --show-superproject-working-tree
```

### Step 7: Report

Print:
- Issue URL
- PR URL
- Confirm merged to main
- Submodule updated (if applicable)

## Rules

- **Never force push.**
- **Never skip hooks.** Fix the issue if pre-commit fails.
- **Explicit file staging.** List files by name, not `git add -A`.
- **Don't commit secrets.** Warn on `.env`, credentials, API keys.
- **Follow repo commit style.** Check `git log` for conventions.
- **Separate concerns.** If changes span unrelated topics, ask
  whether to split into multiple PRs.
- **Confirm before merge** if CI checks haven't passed.
- **Squash merge by default.** Use `--merge` or `--rebase` only if
  the user asks.
