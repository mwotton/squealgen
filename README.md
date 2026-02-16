# squealgen

Generate squeal types from a running database.

![CI](https://github.com/mwotton/squealgen/actions/workflows/ci.yml/badge.svg)

## Breaking Changes (v2.0.0)

### Overloaded Function Naming

Starting with v2.0.0, overloaded PostgreSQL functions now use **disambiguated labels** to ensure type-safe calling:

```haskell
-- Old (v1.x): Only one overload could be represented, using simple name
type Functions = '[ "my_func" ::: Function ... ]

-- New (v2.0): All representable overloads use disambiguated labels
type Functions = '[ "my_func__int4" ::: Function '[Null PGint4] :=> ...
                  , "my_func__int8" ::: Function '[Null PGint8] :=> ... ]
```

**Migration Guide:**

1. **Search for simple function names** in your codebase that may have been overloaded:
   ```bash
   # Find usages of function labels in your code
   grep -r '#"my_func"' src/
   ```

2. **Replace with disambiguated labels**:
   - Before: `#"my_func"` → After: `#"my_func__int4"` or `#"my_func__int8"` (as appropriate)

3. **Compatibility aliases**: If only ONE overload of a function is representable (others have pseudotype arguments), a compatibility alias is emitted:
   ```haskell
   -- Both labels work when only one overload is representable:
   type Functions = '[ "legacy_func" ::: Function ...      -- compatibility alias
                     , "legacy_func__int8" ::: Function ... -- disambiguated label
                     ]
   ```
   In this case, existing code using the simple name will continue to work.

4. **Pseudotype functions** (using `anyelement`, `anyarray`, etc.) are not representable and are omitted with a comment—this behavior is unchanged.

## why?

[Squeal](https://hackage.haskell.org/package/squeal-postgresql) is a lovely way to interact with a database, but setting up the initial schema is a struggle.
By default, it assumes you will be managing and migrating your database with Squeal, and if you are starting
from scratch, that works great, but if you're managing it some other way, or even just want to test out Squeal
on an existing database, it's tedious to have to set up the database types and keep them up to date.

## how?

1. clone the repo and change into the directory
2. Install the executable (recommended):

   ```bash
   cabal install exe:squealgen --installdir=$HOME/.local/bin --overwrite-policy=always
   ```

   If you prefer the generated script (dev convenience), you can also run:

   ```bash
   make prefix=$HOME/.local install
   ```
3. If my database is `cooldb`, my Haskell module is `Schema` (file `Schema.hs`), and I want to generate from the `public` schema,
   I would run `squealgen cooldb Schema public > ~/myproject/src/Schema.hs`.

   Notes:

   - `DBNAME` is passed to `psql -d`, so it can be a database name *or* a libpq connection string/URL.
   - `MODULENAME` is the Haskell module name (not a file path).
   - `IMPORTS` (optional) is inserted into the generated module; a convenient pattern is `"... $(cat extra_imports.txt)"`.
   - `PSQLCMD` can be set to use a non-default `psql` binary.

   `SCHEMA` is treated as a comma-separated `search_path` fragment, so you can pass `public,ext` if you also need `ext` on the path (e.g. for extension-owned types).

You could integrate this in various ways: perhaps just as an initial scaffold, or perhaps integrated as part
of your build process. A true madman could integrate this into a TH call, but I suspect this would be slow and
prone to failing (for instance, better never compile any code if you don't have access to the right version
of psql or a way of spinning up an empty database.)

I highly recommend having a scripted way to bring up a temporary database and run all migrations first. I use
Jonathan Fischoff's [tmp-postgres](https://hackage.haskell.org/package/tmp-postgres) library and
recommend it if you're running migrations through Haskell.

## hacking?

My workflow looks like this:

```bash
make testwatch
```

`squealgen` is generated from `squealgen.sql` via `./mksquealgen.sh`.
Treat `squealgen.sql` as the source of truth and do not edit `squealgen` directly.

`./check_squealgen_drift.sh` is run by `make test` and CI to enforce that the checked-in `./squealgen` script matches `squealgen.sql`.

Validation contract:

- Local validation (`make test`): enforce `squealgen` drift parity, regenerate fixture modules, then run `cabal test`.
- CI validation (`make ci`): enforce drift parity, regenerate fixture modules, then run `cabal test` with reduced falsify cases (`--falsify-tests 25`) to keep runtime bounded.

`SCHEMA` is treated as a comma-separated `search_path` fragment.
The generator targets only the first schema in the fragment for emitted types, but sets the full `search_path` safely (quoted identifiers).

Extension story:

- If the schema references extension-owned types, squealgen emits opaque `UnsafePGType` aliases (e.g. `type PGltree = UnsafePGType "ltree"`) only when needed.
- When any extension-owned types are present, generated output includes a comment block listing detected required extensions.
- Users are responsible for installing extensions via migrations/DDL; CI enforces this via the `test/Extensions` ltree fixture.

Function-overload compatibility notes:

- Generated output always includes deterministic disambiguated overloaded labels (`name__argtokens`).
- When an overloaded base name has exactly one representable signature, a compatibility alias using the legacy simple name (`name`) is also emitted.
- When two or more representable overloads remain, no legacy alias is emitted; callers must use the disambiguated labels.

## you'll need

- PostgreSQL client/server tools on your `PATH`: `psql`, `initdb`, `pg_ctl`, `createdb` (used by tests and vendored `vendor/pg_tmp`). On Ubuntu, these are often under `/usr/lib/postgresql/<version>/bin` (e.g. `/usr/lib/postgresql/16/bin`); if `pg_config` is available: `export PATH="$(pg_config --bindir):$PATH"`.
- make
- cabal-install
- `inotifywait` (from `inotify-tools`) if you want to use `make testwatch`.

## what next?

- Remove string-hacking, generate in a more principled way.
- Improve function-label ergonomics while preserving overload safety and readability.
- Investigate richer type-level trigger/check representations while preserving current metadata fallback behavior.

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              squealgen flow                                  │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   ┌──────────────┐    ┌────────────────┐    ┌──────────────────────────┐   │
│   │ PostgreSQL   │    │ squealgen.sql  │    │ Generated Schema.hs      │   │
│   │ Database     │───▶│ (psql script)  │───▶│ (Squeal types)           │   │
│   │              │    │                │    │                          │   │
│   │ - tables     │    │ - CTE queries  │    │ - type DB                │   │
│   │ - views      │    │ - type mapping │    │ - type Schema            │   │
│   │ - enums      │    │ - emit logic   │    │ - type Tables/Views/...  │   │
│   │ - functions  │    │                │    │ - function definitions   │   │
│   └──────────────┘    └────────────────┘    └──────────────────────────┘   │
│                                                                             │
│   Input: DBNAME, MODULENAME, SCHEMA                                         │
│   Output: Haskell module with Squeal type definitions                      │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

The generator queries PostgreSQL system catalogs (`pg_catalog`, `information_schema`) to extract schema metadata, then emits Haskell type definitions compatible with Squeal's type-level DSL.

### Triggers Metadata

The generated output includes a `Triggers` type that provides metadata about PostgreSQL triggers defined on tables in the schema:

```haskell
-- Example generated output:
-- triggers
-- Trigger contract: Triggers is generated metadata and is not composed into Schema.
type Triggers = 
  '[ "users_insert_trigger" ::: 'TriggerMetadata
       '["table" ::: "users", "event" ::: "INSERT", "timing" ::: "BEFORE"]
   ]
```

**Important**: The `Triggers` type is **metadata-only** and is NOT composed into the `Schema` type. It cannot be used in Squeal queries. Its purpose is to document what triggers exist in the database for developer reference. Squeal does not provide type-level trigger support.

## Type Mappings

| PostgreSQL Type | Squeal Type |
|-----------------|-------------|
| `boolean` | `PGbool` |
| `int2` / `smallint` | `PGint2` |
| `int4` / `integer` | `PGint4` |
| `int8` / `bigint` | `PGint8` |
| `float4` / `real` | `PGfloat4` |
| `float8` / `double precision` | `PGfloat8` |
| `numeric` | `PGnumeric` |
| `text` | `PGtext` |
| `varchar` | `PGtext` or `(PGvarchar n)` |
| `char` | `PGchar` or `(PGvarchar n)` |
| `bytea` | `PGbytea` |
| `date` | `PGdate` |
| `time` | `PGtime` |
| `timestamp` | `PGtimestamp` |
| `timestamptz` | `PGtimestamptz` |
| `interval` | `PGinterval` |
| `uuid` | `PGuuid` |
| `inet` | `PGinet` |
| `json` | `PGjson` |
| `jsonb` | `PGjsonb` |
| `oid` | `PGoid` |
| `array[]` | `(PGvararray ...)` |
| `enum` | `'PGenum '["label1", "label2", ...]` |
| `composite` | `'PGcomposite '[...]` |
| `domain` | Alias to base type |

**Extension types** (ltree, hstore, etc.) are emitted as `UnsafePGType "typename"` aliases.

## Troubleshooting

### "squealgen drift detected"

Run `./mksquealgen.sh` to regenerate the `squealgen` script from `squealgen.sql`, then commit both files. The CI enforces that these stay in sync.

### "initdb: command not found"

PostgreSQL binaries may not be on your PATH. On Ubuntu, try:

```bash
export PATH="/usr/lib/postgresql/$(ls /usr/lib/postgresql | tail -1)/bin:$PATH"
```

Or use `pg_config`:

```bash
export PATH="$(pg_config --bindir):$PATH"
```

### Generated code doesn't compile

1. Ensure you're using compatible versions of `squeal-postgresql` and GHC.
2. Check for pseudotype arguments/returns in functions - these are omitted with a comment.
3. Extension types require `UnsafePGType` - ensure extensions are installed in the database.

### Functions are omitted from output

Functions with pseudotype arguments (e.g., `anyelement`) or returns are not representable in Squeal's type system. Check the generated output for comments like:

```haskell
-- Omitted function signatures:
--   my_func(anyelement): pseudotype argument is not representable
```

### "Croaked: chosen_schema is empty"

The schema argument is required. Provide a valid schema name:

```bash
squealgen mydb MySchema public > Schema.hs
```

### Multiple schemas / extensions

Use comma-separated search_path for extensions:

```bash
squealgen mydb MySchema public,extensions > Schema.hs
```

Types are generated only for the first schema (`public`), but extension-owned types referenced by it will emit `UnsafePGType` aliases.
