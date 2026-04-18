---
description: Git branch and PR workflow rules for k8s-vollminlab-cluster
---

# Git Workflow Rules

## Always start from a clean main

Before creating any branch, always:
```bash
git checkout main && git pull
```

If working copy changes block the pull, stash them first:
```bash
git stash && git pull && git stash drop
```

Never branch off a stale main — this avoids unnecessary rebases and keeps PRs clean. Use the `/new-branch <name>` skill to automate this.

## After merging a PR

Pull main immediately before starting the next branch. Do not let local main fall behind. This is especially important when multiple PRs are being merged in sequence (e.g. staged rollouts).

## Branch naming

| Prefix | Use |
|--------|-----|
| `feat/` | New feature or service |
| `fix/` | Bug fix or correction |
| `chore/` | Housekeeping, formatting, bumps |
| `docs/` | Documentation only |

## One concern per PR

Keep PRs tightly scoped. If a task touches unrelated concerns (e.g. a feature + a CRLF fix), split them into separate branches and PRs. Reviewers and CI both benefit from focused diffs.

## Never push to main

Branch protection is enforced via GitHub repository settings. All changes go through a PR. Never use `--force` or bypass hooks.

## Staging files

Always add files explicitly by name — never `git add -A` or `git add .`. This prevents accidentally staging sensitive files or unrelated changes.

## Context window and session hygiene

- Check `/context` before starting a long multi-file task. If above 80%, finish the current task and start a fresh session for the next one.
- Use `/compact` mid-session when token count is high but you still need conversation continuity.
- Use `/clear` when switching to a completely unrelated task.
- Delegate codebase exploration to subagents (`Explore` type) to keep the main context clean.
