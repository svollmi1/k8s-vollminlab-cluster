---
description: Checkout main, pull latest, and create a new branch
user-invocable: true
---

# New Branch

Create a new branch from a clean, up-to-date main. The branch name should be provided as the argument (e.g. `/new-branch feat/my-feature`). If no argument is given, ask for the branch name before proceeding.

## Steps

1. Check for uncommitted changes (`git status`). If there are meaningful staged or unstaged changes (not just line-ending noise), stop and ask the user what to do with them before proceeding.

2. Checkout main and pull:
   ```bash
   git checkout main && git pull
   ```
   If working copy changes block the pull (e.g. CRLF noise on tracked files), stash them, pull, then drop the stash:
   ```bash
   git stash && git pull && git stash drop
   ```

3. Create the new branch:
   ```bash
   git checkout -b <branch-name>
   ```

4. Confirm success — report the branch name and the latest commit on main that was pulled.

## Branch naming convention

| Prefix | Use |
|--------|-----|
| `feat/` | New feature or service |
| `fix/` | Bug fix or correction |
| `chore/` | Housekeeping, dependency bumps, formatting |
| `docs/` | Documentation only |

Slugify the description: lowercase, hyphens, no special characters. Example: `feat/arc-migration`, `fix/velero-bsl-validation-frequency`.
