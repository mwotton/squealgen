#!/usr/bin/env bash
set -euo pipefail

# Check that the squealgen script matches squealgen.sql.
#
# Modes (via SQUEALGEN_DRIFT_MODE):
#   auto    - detect git worktree, use git mode if available (default)
#   git     - require git worktree, compare against committed artifact
#   non-git - compare against existing squealgen file (for tarball builds)
#
# Exit codes:
#   0 - no drift detected (or first run in non-git mode with no existing artifact)
#   1 - drift detected
#   2 - usage error
#
# Note: In non-git mode, if squealgen doesn't exist, it's created and we exit 0.
# This allows first-time setup from a source tarball without drift errors.

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
candidate_squealgen="$(mktemp)"
cleanup() {
  if [[ -n "${previous_squealgen}" && -e "${previous_squealgen}" ]]; then
    rm -f "${previous_squealgen}"
  fi
  if [[ -n "${candidate_squealgen}" && -e "${candidate_squealgen}" ]]; then
    rm -f "${candidate_squealgen}"
  fi
}
trap cleanup EXIT

if [[ "${use_git_mode}" != "true" ]]; then
  if [[ -e squealgen ]]; then
    previous_squealgen="$(mktemp)"
    cp -p squealgen "${previous_squealgen}"
  fi
fi

SQUEALGEN_OUTPUT_PATH="${candidate_squealgen}" ./mksquealgen.sh

candidate_is_executable="false"
current_is_executable="false"
if [[ -x "${candidate_squealgen}" ]]; then
  candidate_is_executable="true"
fi
if [[ -x squealgen ]]; then
  current_is_executable="true"
fi
candidate_differs=false
if [[ ! -e squealgen ]] || ! cmp -s "${candidate_squealgen}" squealgen || [[ "${candidate_is_executable}" != "${current_is_executable}" ]]; then
  candidate_differs=true
fi

if [[ "${use_git_mode}" == "true" ]]; then
  if [[ "${candidate_differs}" == "true" ]]; then
    echo "squealgen drift detected. Run: ./mksquealgen.sh" >&2
    if [[ -e squealgen ]]; then
      diff -u --label "squealgen (committed artifact)" --label "squealgen (regenerated)" squealgen "${candidate_squealgen}" || true
    else
      echo "squealgen is missing from the working tree." >&2
    fi
    exit 1
  fi
  if ! git diff --quiet -- squealgen || ! git diff --cached --quiet -- squealgen; then
    echo "squealgen drift detected in git state. Run: ./mksquealgen.sh and stage the updated artifact." >&2
    git --no-pager diff -- squealgen || true
    exit 1
  fi
else
  if [[ -z "${previous_squealgen}" ]]; then
    mv "${candidate_squealgen}" squealgen
    candidate_squealgen=""
    exit 0
  fi
  if [[ "${candidate_differs}" == "true" ]]; then
    echo "squealgen drift detected in non-git fallback mode. Run: ./mksquealgen.sh and refresh distributed squealgen artifact." >&2
    diff -u --label "squealgen (distributed artifact)" --label "squealgen (regenerated)" "${previous_squealgen}" "${candidate_squealgen}" || true
    exit 1
  fi
fi
