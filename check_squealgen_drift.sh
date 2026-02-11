#!/usr/bin/env bash
set -euo pipefail

./mksquealgen.sh

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "error: check_squealgen_drift.sh must run inside a git worktree" >&2
  exit 2
fi

if ! git diff --quiet -- squealgen || ! git diff --cached --quiet -- squealgen; then
  echo "squealgen drift detected. Run: ./mksquealgen.sh" >&2
  git --no-pager diff -- squealgen || true
  exit 1
fi
