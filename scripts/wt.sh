#!/usr/bin/env bash
# Worktree helper: one branch per worktree, created next to the repo in ../citytour-wt/<slug>.
# Usage: scripts/wt.sh new <type/slug> | list | rm <slug>
set -euo pipefail
ROOT="$(git rev-parse --show-toplevel)"
WT_DIR="$(dirname "$ROOT")/citytour-wt"
cmd="${1:-list}"
case "$cmd" in
  new)
    branch="${2:?usage: wt.sh new <type/slug>  e.g. feat/poi-data}"
    slug="${branch#*/}"
    mkdir -p "$WT_DIR"
    git -C "$ROOT" fetch --quiet origin main 2>/dev/null || true
    base="main"; git -C "$ROOT" rev-parse --verify --quiet origin/main >/dev/null && base="origin/main"
    git -C "$ROOT" worktree add --no-track -b "$branch" "$WT_DIR/$slug" "$base"
    # carry over local-only (gitignored) agent config, if present
    for f in CLAUDE.local.md .claude/settings.local.json .claude/skills; do
      [ -e "$ROOT/$f" ] && mkdir -p "$(dirname "$WT_DIR/$slug/$f")" && cp -R "$ROOT/$f" "$WT_DIR/$slug/$f"
    done
    echo "Worktree ready: $WT_DIR/$slug (branch $branch from $base)"
    echo "Next: cd \"$WT_DIR/$slug\" && claude"
    ;;
  list)
    git -C "$ROOT" worktree list
    ;;
  rm)
    slug="${2:?usage: wt.sh rm <slug>}"
    git -C "$ROOT" worktree remove "$WT_DIR/$slug"
    echo "Removed worktree $WT_DIR/$slug (branch kept; delete with: git branch -d <branch> once merged)"
    ;;
  *) echo "usage: wt.sh new <type/slug> | list | rm <slug>"; exit 1 ;;
esac
