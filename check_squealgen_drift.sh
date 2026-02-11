#!/usr/bin/env bash
set -euo pipefail

drift_mode="${SQUEALGEN_DRIFT_MODE:-auto}"
case "$drift_mode" in
  auto|git|non-git) ;;
  *)
    echo "error: unsupported SQUEALGEN_DRIFT_MODE='$drift_mode' (expected auto|git|non-git)" >&2
    exit 2
    ;;
esac

is_git_worktree() {
  git rev-parse --is-inside-work-tree >/dev/null 2>&1
}

use_git_mode=false
case "$drift_mode" in
  auto)
    if is_git_worktree; then
      use_git_mode=true
    fi
    ;;
  git)
    if ! is_git_worktree; then
      echo "error: check_squealgen_drift.sh in git mode requires a git worktree" >&2
      exit 2
    fi
    use_git_mode=true
    ;;
  non-git)
    use_git_mode=false
    ;;
esac

previous_squealgen=""
cleanup() {
  if [[ -n "${previous_squealgen}" && -e "${previous_squealgen}" ]]; then
    rm -f "${previous_squealgen}"
  fi
}
trap cleanup EXIT

if [[ "${use_git_mode}" != "true" ]]; then
  if [[ ! -e squealgen ]]; then
    echo "error: non-git fallback mode requires an existing ./squealgen file to compare against" >&2
    echo "hint: run ./mksquealgen.sh once before invoking this drift check" >&2
    exit 2
  fi
  previous_squealgen="$(mktemp)"
  cp -p squealgen "${previous_squealgen}"
fi

./mksquealgen.sh

if [[ "${use_git_mode}" == "true" ]]; then
  if ! git diff --quiet -- squealgen || ! git diff --cached --quiet -- squealgen; then
    echo "squealgen drift detected. Run: ./mksquealgen.sh" >&2
    git --no-pager diff -- squealgen || true
    exit 1
  fi
else
  was_executable="false"
  is_executable="false"
  if [[ -x "${previous_squealgen}" ]]; then
    was_executable="true"
  fi
  if [[ -x squealgen ]]; then
    is_executable="true"
  fi
  if ! cmp -s "${previous_squealgen}" squealgen || [[ "${was_executable}" != "${is_executable}" ]]; then
    echo "squealgen drift detected in non-git fallback mode. Run: ./mksquealgen.sh and refresh distributed squealgen artifact." >&2
    diff -u "${previous_squealgen}" squealgen || true
    exit 1
  fi
fi
