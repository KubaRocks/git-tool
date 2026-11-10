---
name: gt-workflow
description: Conventions of the gt git workflow for branch names, commit messages and pull/merge requests. Use when creating a branch, committing or pushing, opening a pull/merge request, or rebasing onto the default branch.
---

# gt workflow

The conventions the `gt` CLI applies, for agents doing the same work with `git`, `gh` and `glab` directly (`gt` itself needs a terminal).

## Ticket ID

The first `[A-Z]+-[0-9]+` in the branch name, e.g. `ID-4567`. It prefixes every commit message and PR title as `ID-4567: `.

## Branch

Branch from the default branch right after pulling it. Name: `ID-4567 Refactor order flow [WIP]` → `ID-4567-refactor-order-flow` (ticket ID as written, `[...]` tags dropped, the rest lowercase kebab-case). Switch to the branch if it already exists.

## Commit message

One line: the ticket prefix, then a lowercase verb (add/fix/update/refactor/remove) and what changed and why, in one or two sentences.

`ID-4567: refactor order checks into a shared validateOrder helper to remove duplicated validation`

## Pull request

Push the branch, then open it against the default branch:

- **Title**: the ticket prefix, then the change itself starting with a lowercase verb; at most 80 characters in total.
- **Body**:

  ```markdown
  ## Summary
  - 2–4 bullets on what and why

  ## Changes
  - the key changes
  ```

- **GitHub**: `gh pr create --base <default> --title … --body …`
- **GitLab**: `glab mr create --target-branch <default> --title … --description … --squash-before-merge --no-editor`

Report the PR/MR URL.

## Rebase

Rebase onto `origin/<default>` after fetching it. Resolve conflicts by taking the incoming changes and keeping the branch's new functionality. When a conflict has no clear resolution, show it to the user and offer `git rebase --abort`.

## Rejected push

- Branch diverged because it was rebased: `git push --force-with-lease`. A request to push the rebased branch is the go-ahead; otherwise ask first.
- Otherwise: `git pull --rebase`, then push again.
