# gt — Git Tool

A CLI that streamlines the git branch-commit-push workflow with AI-generated commit messages and interactive prompts.

## Features

- **`gt branch`** — Create a new branch off the latest default branch. Auto-stashes dirty work, pulls latest, converts input to valid branch names (preserving JIRA ticket IDs like `NI-4567`).

- **`gt push`** — Interactive file staging with status labels, AI-generated commit messages (accept/edit/regenerate/cancel), auto-pull before commit, smart push with force-with-lease after rebase.

- **`gt message`** — Generate a commit message from current changes using Claude AI. Works standalone or piped (e.g. `gt message | pbcopy`).

- **`gt rebase`** — Rebase current branch onto the default branch. On conflicts, offers to launch Claude Code or Codex to resolve them automatically.

- **`gt status`** — Quick overview: branch name, JIRA ticket, dirty files, unpushed commits, last commit message.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/KubaRocks/git-tool/main/install.sh | bash
```

The installer will:
- Check and optionally install dependencies
- Let you choose an install location
- Set up zsh completions

### Dependencies

- [gum](https://github.com/charmbracelet/gum) — interactive terminal UI
- [claude](https://docs.anthropic.com/en/docs/claude-cli) — AI commit message generation

### Manual install

```bash
# Download
curl -fsSL https://raw.githubusercontent.com/KubaRocks/git-tool/main/gt -o ~/bin/gt
chmod +x ~/bin/gt

# Zsh completions (optional)
curl -fsSL https://raw.githubusercontent.com/KubaRocks/git-tool/main/completions/_gt -o ~/.zsh/completions/_gt
```

## Usage

### `gt branch`

Creates a new branch off the latest default branch. Auto-stashes dirty work, pulls latest, and converts your input into a valid branch name.

```
❯ gt branch
▸ Default branch: main
▸ Stashing uncommitted changes...
▸ Switching to main and pulling latest...
? Branch name (e.g. NI-4567 refactor order flow)
> NI-4567 refactor order flow
▸ Creating branch: NI-4567-refactor-order-flow
▸ Restoring stashed changes...
✓ On new branch NI-4567-refactor-order-flow
```

### `gt push`

Stages files, generates an AI commit message, commits, and pushes — all in one interactive flow.

```
❯ gt push
Select files to stage:
> ✓ All files
  · src/api/handler.ts (modified)
  · src/api/handler.test.ts (new)
  · src/utils/cache.ts (modified)
▸ Staged all files.

Commit message:
─────────────────────────────────────────
NI-4567: add request caching to API handler
─────────────────────────────────────────

? What would you like to do?
> Accept
  Edit
  Regenerate
  Cancel

✓ Committed.
✓ Pushed to origin/NI-4567-refactor-order-flow
```

### `gt message`

Generates a commit message from current changes. Works standalone or piped.

```
❯ gt message
NI-4567: add request caching to API handler

❯ gt message | pbcopy
```

### `gt rebase`

Rebases the current branch onto the default branch. On conflicts, offers AI-assisted resolution.

```
❯ gt rebase
▸ Fetching latest main...
▸ Rebasing NI-4567-refactor-order-flow onto origin/main (3 new commit(s))...
✓ Rebased successfully onto main.
```

If conflicts occur:

```
❯ gt rebase
▸ Fetching latest main...
▸ Rebasing feature-branch onto origin/main (2 new commit(s))...
⚠ Rebase conflicts detected.

Conflicting files:
  • src/api/handler.ts
  • src/utils/cache.ts

? Resolve conflicts with:
> Claude Code
  Codex
  Abort rebase
```

### `gt status`

Quick overview of the current branch state.

```
❯ gt status

Branch:    NI-4567-refactor-order-flow
Ticket:    NI-4567
Dirty:     2 file(s)
Unpushed:  1 commit(s)
Last:      add request caching to API handler
```

## License

MIT
