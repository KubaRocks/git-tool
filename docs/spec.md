# gt — Git Tool CLI

A bash CLI tool that streamlines the git branch-commit-push workflow with AI-generated commit messages and styled interactive prompts.

## General

- **Language:** Bash script
- **Location:** `~/bin/gt`
- **Dependencies:** `gum` (charmbracelet), `claude` CLI
- **Dependency check:** On startup, verify both are available. If missing, print install instructions and exit.
- **Output:** Colored and styled using `gum` and ANSI escape codes

## Commands

### `gt branch`

Creates a new branch off the latest default branch.

**Flow:**

1. Auto-detect the default branch from remote (`git remote show origin | grep 'HEAD branch'`)
2. If working tree is dirty, auto-stash (`git stash push -m "gt-auto-stash"`)
3. Switch to default branch and pull latest (`git checkout <default> && git pull`)
4. Prompt for branch name using `gum input` with placeholder text
5. Convert input to valid branch name:
   - Replace spaces with dashes
   - Lowercase everything except JIRA ticket IDs (e.g. `NI-4567`)
   - Strip invalid characters
   - Example: `NI-4567 refactor order flow` → `NI-4567-refactor-order-flow`
6. Create and switch to the new branch (`git checkout -b <branch>`)
7. If changes were stashed in step 2, pop the stash (`git stash pop`)

**Ticket ID pattern:** `[A-Z]+-[0-9]+` at the start of the input.

### `gt push`

Stages files, generates an AI commit message, commits, and pushes — all in one command.

**Flow:**

1. Detect changed files (`git status --porcelain`)
2. If no changes exist:
   - Check for unpushed commits
   - If unpushed commits exist, prompt: "No changes to commit. Push N unpushed commits?" (Yes / Abort)
   - If no unpushed commits either, print error and exit
3. Interactive file staging via `gum choose --no-limit`:
   - First option: **"All files"** (pre-selected)
   - Remaining options: individual changed files
   - Stage selected files with `git add`
4. Generate commit message:
   - Collect `git diff --staged` and current branch name
   - Send to `claude` CLI with a prompt instructing the format (see below)
   - Show a `gum spin` spinner with "Generating commit message..." during generation
5. Display generated message and prompt with 4 options:
   - **Accept** — use the message as-is
   - **Edit** — open message in `$EDITOR` for manual editing
   - **Regenerate** — call Claude again for a new message
   - **Cancel** — unstage files, abort
6. Commit with the final message (`git commit -m "<message>"`)
7. Push:
   - If branch has no upstream: `git push -u origin <branch>`
   - Otherwise: `git push`

**Commit message format:**

- **First line:** Max 80 characters
- **With ticket ID** (extracted from branch name using `[A-Z]+-[0-9]+`):
  ```
  NI-4567: short description of changes

  Longer description of what changed and why.
  ```
- **Without ticket ID** (use conventional commit prefix):
  ```
  fix: short description of changes

  Longer description of what changed and why.
  ```
- Conventional prefixes: `fix:`, `feat:`, `chore:`, `refactor:`, `perf:`, `docs:`, `test:`, `style:`

### `gt status`

Shows a quick overview of the current branch state.

**Displays:**

- Current branch name
- Extracted JIRA ticket ID (if found in branch name)
- Number of dirty/modified files
- Number of unpushed commits (ahead of remote)
- Last commit message (short summary)

### `gt cleanup`

Deletes stale local branches grouped by safety level.

**Flow:**

1. Assert git repo, remote origin, not detached
2. Detect default branch from remote
3. `git fetch --prune` to sync remote state
4. Scan all local branches (exclude current + default)
5. Categorize each branch:
   - **Safe to delete:** merged into default branch AND `origin/<branch>` gone
   - **Merged, remote exists:** merged into default branch AND `origin/<branch>` still present
   - **Unmerged, remote gone:** NOT merged into default AND `origin/<branch>` gone
   - Active branches (not merged, remote exists) are skipped entirely
6. Display summary counts per category
7. Category 1 — `gum choose --no-limit` with all preselected → `git branch -d`
8. Category 2 — per-branch `gum choose`: "Delete local only" / "Delete local + remote" / "Skip"
   - Local: `git branch -d`, Remote: `git push origin --delete <branch>`
9. Category 3 — show commit count ahead of default, `gum choose --no-limit` (none preselected) → `git branch -D`
10. Show summary: "Deleted X branch(es). Skipped Y."

### `gt version`

Prints the current version.

**Output:** `git-tool (gt) v2026.03.13`

Aliases: `gt --version`, `gt -v`

### `gt self-update`

Updates gt to the latest version.

**Flow:**

1. Detect install path via `which gt`
2. Fetch `VERSION` from `raw.githubusercontent.com/KubaRocks/git-tool/main/VERSION`
3. Compare with current `GT_VERSION`
4. If same → "Already up to date" and exit
5. Download new `gt` to install path (sudo if not writable)
6. Check for installed zsh completions, download new version, compare, update only if changed
7. If completions changed, instruct user to run `exec zsh`
8. Print version transition summary

## Edge Cases

- **Not a git repo:** Detect and print a clear error
- **No remote origin:** Error with explanation
- **Detached HEAD:** Error suggesting to create or switch to a branch
- **Merge conflicts after stash pop:** Warn the user, don't silently swallow
- **Empty diff sent to Claude:** Skip AI generation, warn user
- **Claude CLI timeout/failure:** Error with suggestion to retry
