# gt cleanup — Design

## Purpose

Clean up local branches that have been merged and pushed upstream but never deleted locally. Handles three scenarios with appropriate safety levels.

## Flow

1. Guards: `assert_git_repo`, `assert_remote_origin`, `assert_not_detached`
2. `git fetch --prune` to sync remote state
3. Detect default branch, pull latest
4. Scan all local branches (exclude current + default)
5. Categorize each branch:
   - **Category 1 — Safe to delete**: merged into default, remote gone
   - **Category 2 — Merged, remote exists**: merged into default, `origin/<branch>` still present
   - **Category 3 — Unmerged, remote gone**: has unique commits, remote deleted
6. If no branches found → "Nothing to clean up" → exit
7. Display summary counts per category
8. Process each non-empty category with interactive prompts (see below)
9. Show final summary: "Deleted X branches. Skipped Y."

## Category UX

### Category 1 — Safe to delete
- `gum choose --no-limit` with all branches preselected
- Delete selected with `git branch -d`

### Category 2 — Merged, remote exists
- One-at-a-time prompt per branch using `gum choose`:
  - "Delete local only"
  - "Delete local + remote"
  - "Skip"
- Local: `git branch -d`, Remote: `git push origin --delete <branch>`

### Category 3 — Unmerged, remote gone
- Show unique commit count per branch as context (e.g., `feature-x (3 commits ahead)`)
- `gum choose --no-limit` with nothing preselected
- Delete selected with `git branch -D` (force)

## Dependencies

- `gum` for interactive prompts (consistent with other gt commands)
- Standard git commands

## Files to modify

- `gt` — add `cmd_cleanup()` function and route in main case statement
- `completions/_gt` — add `cleanup` to command list
- `README.md` — add cleanup to usage docs
- `docs/spec.md` — add cleanup command spec
