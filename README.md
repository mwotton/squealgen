# squealgen

Generate squeal types from a running database.

![CI](https://github.com/mwotton/squealgen/actions/workflows/ci.yml/badge.svg)

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
