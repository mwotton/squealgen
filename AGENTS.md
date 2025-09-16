# Agent Notes

- On Ubuntu installs, `initdb` usually isn't on the default `PATH`; look for it under `/usr/lib/postgresql/<version>/bin/initdb` (e.g. `/usr/lib/postgresql/17/bin/initdb`).
- Always run the full test suite (`cabal test --test-show-details=direct`) before committing or pushing changes.
- For any change accompanied by tests, split the work into two separate commits and pushes: first push a commit that adds the failing test(s) only; then push a follow-up commit that contains the fix making those tests pass. This ensures GitHub CI runs and records both the failing and passing states (red → green).
