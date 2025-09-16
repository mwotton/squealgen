# Agent Notes

- On Ubuntu installs, `initdb` usually isn't on the default `PATH`; look for it under `/usr/lib/postgresql/<version>/bin/initdb` (e.g. `/usr/lib/postgresql/17/bin/initdb`).
- Always run the full test suite (`cabal test --test-show-details=direct`) before committing or pushing changes.
