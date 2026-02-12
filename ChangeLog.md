# Changelog for squealgen

## Unreleased changes

- Generator hardening:
  - `chosen_schema` is treated as a comma-separated `search_path` fragment and applied safely (quoted identifiers, no raw psql substitution).
  - The generated `type DB` targets the first schema in the fragment.
  - Views list output is deterministic (explicit ordering inside `string_agg`).
- Extensions:
  - Extension-owned types are emitted as `UnsafePGType` aliases only when referenced.
  - Generated output includes a comment block listing detected required extensions when extension-owned types are present.
  - Added an end-to-end `ltree` fixture (`test/Extensions`) and CI installs `postgresql-contrib`.
- CI/testing:
  - Dropped the coverage gate (coverage is not meaningful for this generator-only repo).
  - `make ci` runs `cabal test` with reduced falsify cases (`--falsify-tests 25`) to keep CI runtime bounded.
