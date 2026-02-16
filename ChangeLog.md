# Changelog for squealgen

## 0.2.0.0 (2026-02-16)

### Breaking Changes

**Overloaded function naming now uses disambiguated labels.**

Previously, when a PostgreSQL function was overloaded, squealgen would emit only one overload (undefined which one). Now, all representable overloads are emitted with disambiguated labels.

**Function label format:** `name__argtype1__argtype2`

Example for `my_func(int4)` and `my_func(int8)`:
```haskell
type Functions =
  '[ "my_func__int4" ::: Function '[Null PGint4] :=> 'Returns ('Null PGint4)
   , "my_func__int8" ::: Function '[Null PGint8] :=> 'Returns ('Null PGint8)
   ]
```

**Compatibility aliases** are emitted when exactly one overload is representable (others have pseudotype arguments). For example, if `legacy_func(int8)` is representable but `legacy_func(anyelement)` is not:
```haskell
type Functions =
  '[ "legacy_func" ::: Function '[Null PGint8] :=> ...      -- compatibility alias
   , "legacy_func__int8" ::: Function '[Null PGint8] :=> ... -- disambiguated label
   ]
```

### Migration Guide

1. **Find affected functions**: Regenerate your schema and compare to previous version:
   ```bash
   squealgen mydb Schema public > Schema.hs.new
   diff Schema.hs Schema.hs.new
   ```

2. **Update call sites**: Replace simple function names with disambiguated labels:
   - Before: `#"my_func"` → After: `#"my_func__int8"` (or appropriate type suffix)
   - Use grep to find usages: `grep -r '#"my_func"' src/`

3. **No action needed if**:
   - The function is not overloaded in PostgreSQL
   - Only one overload is representable (compatibility alias preserved)

### Other Changes

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
