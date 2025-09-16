# Agent Notes

- On Ubuntu installs, `initdb` usually isn't on the default `PATH`; look for it under `/usr/lib/postgresql/<version>/bin/initdb` (e.g. `/usr/lib/postgresql/17/bin/initdb`).
- Always run the full test suite (`cabal test --test-show-details=direct`) before committing or pushing changes.

## Issue-Fix Workflow

- When fixing an issue, first write a failing test that reproduces the problem.
- Commit only the failing test, then open/push a PR so CI shows the failure.
- Implement the fix in a separate commit and push it to the same PR so CI shows the fix.
- If the initial failing test didn’t capture the failure correctly, it’s okay to amend/force-push the failing commit. The goal is to have two separate pushes so both the failing state and the fix are evidenced.
- Continue to run `cabal test --test-show-details=direct` locally before each push.
