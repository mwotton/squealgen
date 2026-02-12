# Changelog for squealgen

## Unreleased changes

- Coverage policy hardening:
  - `check_coverage.sh` now rejects synthetic-only covered-expression scopes.
  - Zero-denominator expression policy is explicit (`fail` by default, optional local `allow` override) and is reported in `coverage/summary.txt`.
- Trigger generation determinism:
  - Trigger metadata output ordering is deterministic even when trigger names collide.
- CI contract simplification:
  - `make ci` runs drift + coverage gates as the single expensive compile/test pass.
- Script/workflow test hardening:
  - Script checks exercise integration behavior with tighter assertions and failure-path coverage.
- Generated API/docs contract clarity:
  - Generated modules now state that `type Triggers` is metadata-only and not composed into typed `Schema`.
  - README contract/policy notes were refreshed to match current behavior.
