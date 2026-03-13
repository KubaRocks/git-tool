# gt cleanup Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a `gt cleanup` command that deletes stale local branches in three safety-tiered categories with interactive batch selection.

**Architecture:** Single new `cmd_cleanup()` function in the monolithic `gt` bash script, following the existing `cmd_*` pattern. Uses `gum choose` for interactive selection (consistent with `gt push`). Routes through the main case statement.

**Tech Stack:** Bash, git, gum

---

### Task 1: Create feature branch

**Files:**
- None (git operation only)

**Step 1: Create and switch to new branch from main**

```bash
git checkout main
git pull
git checkout -b feature/cleanup-command
```

**Step 2: Commit the design doc**

```bash
git add docs/plans/2026-03-13-gt-cleanup-design.md docs/plans/2026-03-13-gt-cleanup-plan.md
git commit -m "docs: add design and plan for gt cleanup command"
```

---

### Task 2: Add cmd_cleanup function — guards, fetch, and branch categorization

**Files:**
- Modify: `gt:505` (insert before the push_branch helper on line 506)

**Step 1: Add the cmd_cleanup function**

Insert the following before the `# ── Push Helper ──` comment (line 506 in `gt`):

```bash
# ── gt cleanup ──────────────────────────────────────────────────────────────
cmd_cleanup() {
  assert_git_repo
  assert_remote_origin
  assert_not_detached

  local current_branch
  current_branch=$(git symbolic-ref --short HEAD)

  # Detect default branch
  local default_branch
  default_branch=$(git remote show origin 2>/dev/null | grep 'HEAD branch' | awk '{print $NF}')
  [[ -z "$default_branch" ]] && die "Could not detect default branch from origin."

  # Fetch and prune to sync remote state
  info "Fetching and pruning remote references..."
  git fetch --prune

  # Get merged branches (exclude current and default)
  local merged_branches
  merged_branches=$(git branch --merged "$default_branch" --format='%(refname:short)' | grep -vE "^(${current_branch}|${default_branch})$")

  # Get all local branches (exclude current and default)
  local all_branches
  all_branches=$(git branch --format='%(refname:short)' | grep -vE "^(${current_branch}|${default_branch})$")

  # Categorize branches
  local safe_to_delete=()      # merged + remote gone
  local merged_remote_exists=() # merged + remote exists
  local unmerged_remote_gone=() # not merged + remote gone

  while IFS= read -r branch; do
    [[ -z "$branch" ]] && continue
    local is_merged=false
    if echo "$merged_branches" | grep -qx "$branch"; then
      is_merged=true
    fi

    local has_remote=false
    if git rev-parse --verify --quiet "refs/remotes/origin/${branch}" &>/dev/null; then
      has_remote=true
    fi

    if [[ "$is_merged" == true && "$has_remote" == false ]]; then
      safe_to_delete+=("$branch")
    elif [[ "$is_merged" == true && "$has_remote" == true ]]; then
      merged_remote_exists+=("$branch")
    elif [[ "$is_merged" == false && "$has_remote" == false ]]; then
      unmerged_remote_gone+=("$branch")
    fi
    # Branches that are not merged AND have remote are active — skip them
  done <<< "$all_branches"

  local total=$(( ${#safe_to_delete[@]} + ${#merged_remote_exists[@]} + ${#unmerged_remote_gone[@]} ))

  if [[ "$total" -eq 0 ]]; then
    success "Nothing to clean up. All branches look active."
    return
  fi

  # Display summary
  echo ""
  echo -e "${BOLD}Found ${total} branch(es) to review:${RESET}"
  [[ ${#safe_to_delete[@]} -gt 0 ]] && echo -e "  ${GREEN}${#safe_to_delete[@]}${RESET} safe to delete (merged, remote gone)"
  [[ ${#merged_remote_exists[@]} -gt 0 ]] && echo -e "  ${YELLOW}${#merged_remote_exists[@]}${RESET} merged but remote still exists"
  [[ ${#unmerged_remote_gone[@]} -gt 0 ]] && echo -e "  ${RED}${#unmerged_remote_gone[@]}${RESET} unmerged with remote gone"
  echo ""

  local deleted=0
  local skipped=0

  # ── Category 1: Safe to delete (merged + remote gone) ──
  if [[ ${#safe_to_delete[@]} -gt 0 ]]; then
    echo -e "${BOLD}Merged branches (remote gone):${RESET}"
    echo -e "${DIM}These branches are fully merged and their remote has been deleted.${RESET}"
    echo ""

    local selected
    selected=$(gum choose --no-limit --selected="${safe_to_delete[*]}" --header "Select branches to delete:" -- "${safe_to_delete[@]}") || true

    if [[ -n "$selected" ]]; then
      while IFS= read -r branch; do
        git branch -d "$branch" &>/dev/null
        success "Deleted ${BOLD}${branch}${RESET}"
        ((deleted++))
      done <<< "$selected"
    else
      skipped=$(( skipped + ${#safe_to_delete[@]} ))
    fi
    echo ""
  fi

  # ── Category 2: Merged, remote exists ──
  if [[ ${#merged_remote_exists[@]} -gt 0 ]]; then
    echo -e "${BOLD}Merged branches (remote still exists):${RESET}"
    echo -e "${DIM}These branches are merged but origin/<branch> is still present.${RESET}"
    echo ""

    for branch in "${merged_remote_exists[@]}"; do
      local action
      action=$(gum choose "Delete local only" "Delete local + remote" "Skip" --header "${branch}:") || true

      case "$action" in
        "Delete local only")
          git branch -d "$branch" &>/dev/null
          success "Deleted local ${BOLD}${branch}${RESET}"
          ((deleted++))
          ;;
        "Delete local + remote")
          git branch -d "$branch" &>/dev/null
          git push origin --delete "$branch" &>/dev/null
          success "Deleted local + remote ${BOLD}${branch}${RESET}"
          ((deleted++))
          ;;
        *)
          info "Skipped ${BOLD}${branch}${RESET}"
          ((skipped++))
          ;;
      esac
    done
    echo ""
  fi

  # ── Category 3: Unmerged, remote gone ──
  if [[ ${#unmerged_remote_gone[@]} -gt 0 ]]; then
    echo -e "${BOLD}Unmerged branches (remote gone):${RESET}"
    echo -e "${DIM}These branches have commits not in ${default_branch} and their remote is gone.${RESET}"
    echo ""

    # Build labels with commit count
    local labels=()
    for branch in "${unmerged_remote_gone[@]}"; do
      local ahead
      ahead=$(git rev-list --count "${default_branch}..${branch}" 2>/dev/null || echo "?")
      labels+=("${branch} (${ahead} commits ahead)")
    done

    local selected
    selected=$(gum choose --no-limit --header "Select branches to force-delete:" -- "${labels[@]}") || true

    if [[ -n "$selected" ]]; then
      while IFS= read -r label; do
        # Extract branch name from label (strip " (N commits ahead)")
        local branch="${label% (*}"
        git branch -D "$branch" &>/dev/null
        success "Force-deleted ${BOLD}${branch}${RESET}"
        ((deleted++))
      done <<< "$selected"
    else
      skipped=$(( skipped + ${#unmerged_remote_gone[@]} ))
    fi
    echo ""
  fi

  # Summary
  echo -e "${DIM}─────────────────────────────────────────${RESET}"
  success "Deleted ${deleted} branch(es). Skipped ${skipped}."
}
```

**Step 2: Verify the file is syntactically valid**

Run: `bash -n gt`
Expected: No output (no syntax errors)

**Step 3: Commit**

```bash
git add gt
git commit -m "feat: add gt cleanup command for stale branch deletion"
```

---

### Task 3: Register cleanup in the main router and help text

**Files:**
- Modify: `gt:551-567` (main case statement and help text)

**Step 1: Add cleanup to the case statement**

Add after the `status)` line (line 556):

```bash
  cleanup) check_deps; cmd_cleanup ;;
```

Note: `check_deps` is needed because `gum` is required for interactive prompts.

**Step 2: Add cleanup to the help text**

Add after the `gt status` line (line 565):

```bash
  echo -e "  ${GREEN}gt cleanup${RESET}   Delete branches already merged or removed from remote"
```

**Step 3: Verify syntax**

Run: `bash -n gt`
Expected: No output

**Step 4: Commit**

```bash
git add gt
git commit -m "feat: register cleanup in router and help text"
```

---

### Task 4: Update zsh completions

**Files:**
- Modify: `completions/_gt:5-11`

**Step 1: Add cleanup to the commands array**

Add this line inside the `commands=()` array, after the `branch` entry:

```
    'cleanup:Delete branches already merged or removed from remote'
```

**Step 2: Commit**

```bash
git add completions/_gt
git commit -m "feat: add cleanup to zsh completions"
```

---

### Task 5: Update README

**Files:**
- Modify: `README.md`

**Step 1: Add feature bullet**

Add after the `gt status` feature bullet (after line 15):

```markdown
- **`gt cleanup`** — Delete stale local branches. Categorizes branches as safe-to-delete (merged, remote gone), merged-with-remote (choose local/remote/skip), or unmerged-remote-gone (with commit count context).
```

**Step 2: Add usage section**

Add after the `gt status` usage section (after line 142):

```markdown
### `gt cleanup`

Deletes local branches that have been merged or whose remote has been deleted. Branches are grouped by safety level with appropriate prompts.

```
❯ gt cleanup
▸ Fetching and pruning remote references...

Found 4 branch(es) to review:
  2 safe to delete (merged, remote gone)
  1 merged but remote still exists
  1 unmerged with remote gone

Merged branches (remote gone):
These branches are fully merged and their remote has been deleted.

Select branches to delete:
> ✓ fix/login-bug
  ✓ feature/add-caching

✓ Deleted fix/login-bug
✓ Deleted feature/add-caching

Merged branches (remote still exists):
These branches are merged but origin/<branch> is still present.

feature/old-api:
> Delete local only
  Delete local + remote
  Skip

✓ Deleted local feature/old-api

Unmerged branches (remote gone):
These branches have commits not in main and their remote is gone.

Select branches to force-delete:
  · experiment/new-ui (3 commits ahead)

─────────────────────────────────────────
✓ Deleted 3 branch(es). Skipped 1.
```

**Step 3: Commit**

```bash
git add README.md
git commit -m "docs: add gt cleanup to README"
```

---

### Task 6: Update spec

**Files:**
- Modify: `docs/spec.md`

**Step 1: Add cleanup command spec**

Add after the `gt status` section (after line 92):

```markdown
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
```

**Step 2: Commit**

```bash
git add docs/spec.md
git commit -m "docs: add gt cleanup to spec"
```

---

### Task 7: Manual integration test

**Step 1: Run gt cleanup in a repo with stale branches**

Run: `./gt cleanup`

Verify:
- Fetches and prunes
- Shows summary of categorized branches
- Category 1 shows preselected checklist
- Category 2 shows per-branch 3-option prompt
- Category 3 shows commit count and unselected checklist
- Branches are actually deleted after confirmation
- Final summary is accurate

**Step 2: Run gt cleanup in a clean repo**

Run: `./gt cleanup`

Expected: "Nothing to clean up. All branches look active."

**Step 3: Verify help text**

Run: `./gt`

Expected: `gt cleanup` appears in the help output

**Step 4: Verify syntax one final time**

Run: `bash -n gt`
Expected: No output
