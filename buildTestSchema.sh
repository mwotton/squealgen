#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' "$@"

basedir=$1
schema_=$2

# basedir is like test/Arrays/; modulename is like Arrays.Public
modulename="$(basename "${basedir%/}").${schema_}"

echo "$basedir"
echo "modname $modulename"

schema=$(echo "$schema_" | tr '[:upper:]' '[:lower:]')
db=$(./vendor/pg_tmp)
extra_imports=$(cat "$basedir/schemas/$schema_/extra_imports")

tmp=$(mktemp /tmp/squealgen.XXXXXX)
echo "tmp is $tmp"

psql -X -v ON_ERROR_STOP=1 -d "$db" < "$basedir/schemas/$schema_/structure.sql" &&
  ./squealgen "$db" "$modulename" "$schema" "$extra_imports" > "$tmp" &&
  ./check_schema "$tmp" "${basedir}/${schema_}.hs"
