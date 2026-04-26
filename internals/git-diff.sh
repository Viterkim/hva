#!/usr/bin/env bash
# Compute a git diff and write it to stdout.
# Usage: git-diff.sh <mode> [target] [workspace]
#   mode:      unstaged | staged | commit | branch | main | all
#   target:    revision or branch for commit/branch modes
#   workspace: path to git repo (defaults to $PWD)
set -euo pipefail

MODE="${1:-}"
TARGET="${2:-}"
WORKSPACE="${3:-$PWD}"

if [[ -z "$MODE" ]]; then
  echo "usage: git-diff.sh <mode> [target] [workspace]" >&2
  echo "modes: unstaged staged commit branch main all" >&2
  exit 1
fi

if ! git -C "$WORKSPACE" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "workspace is not inside a git repository: $WORKSPACE" >&2
  exit 1
fi

require_commitish() {
  local rev="$1"
  if ! git -C "$WORKSPACE" rev-parse --verify "${rev}^{commit}" >/dev/null 2>&1; then
    echo "unknown revision: $rev" >&2
    exit 1
  fi
}

case "$MODE" in
  unstaged)
    git -C "$WORKSPACE" diff --no-color
    ;;
  staged)
    git -C "$WORKSPACE" diff --no-color --staged
    ;;
  commit)
    [[ -n "$TARGET" ]] || { echo "commit mode requires a target revision" >&2; exit 1; }
    require_commitish "$TARGET"
    git -C "$WORKSPACE" diff --no-color "${TARGET}..HEAD"
    ;;
  branch)
    [[ -n "$TARGET" ]] || { echo "branch mode requires a target branch" >&2; exit 1; }
    require_commitish "$TARGET"
    git -C "$WORKSPACE" diff --no-color "${TARGET}...HEAD"
    ;;
  main)
    if git -C "$WORKSPACE" rev-parse --verify "main^{commit}" >/dev/null 2>&1; then
      TARGET="main"
    elif git -C "$WORKSPACE" rev-parse --verify "master^{commit}" >/dev/null 2>&1; then
      TARGET="master"
    else
      echo "could not find main or master in: $WORKSPACE" >&2
      exit 1
    fi
    git -C "$WORKSPACE" diff --no-color "${TARGET}...HEAD"
    ;;
  all)
    tmp_index="$(mktemp "${TMPDIR:-/tmp}/hva-index.XXXXXX")"
    rm -f "$tmp_index"
    trap 'rm -f "$tmp_index"' EXIT
    (
      export GIT_INDEX_FILE="$tmp_index"
      git -C "$WORKSPACE" add -A >/dev/null 2>&1
      if git -C "$WORKSPACE" rev-parse --verify HEAD >/dev/null 2>&1; then
        git -C "$WORKSPACE" diff --no-color --cached HEAD
      else
        empty_tree="$(git -C "$WORKSPACE" hash-object -t tree /dev/null)"
        git -C "$WORKSPACE" diff --no-color --cached "$empty_tree"
      fi
    )
    ;;
  *)
    echo "unknown mode: $MODE" >&2
    echo "modes: unstaged staged commit branch main all" >&2
    exit 1
    ;;
esac
