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

```bash
gt branch          # Create a new branch
gt push            # Stage, commit, and push
gt message         # Generate a commit message
gt rebase          # Rebase onto default branch
gt status          # Show branch overview
```

## License

MIT
