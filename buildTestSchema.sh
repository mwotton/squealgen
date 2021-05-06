#!/bin/bash
set -x

echo $@

basedir=$1
schema_=$2
modulename=$(echo $basedir |sed 's/\/$//;s/.*\///').$schema_
echo $basedir
echo "modname $modulename"

schema=$(echo $schema_ | tr '[:upper:]' '[:lower:]')
db=$(./vendor/pg_tmp)
extra_imports=$(cat $basedir/schemas/$schema_/extra_imports)


# 	$(eval extra_imports := $(shell cat $(<D)/extra_imports))
tmp=$(mktemp /tmp/squealgen.XXXXXX)
echo "tmp is $tmp"
#psql -d $(db) < ./squealgen $(db) "$(patsubst test/%,%,$(*D)).$(*F)" $(schema) $(extra_imports) > $(tmp)

cat $1/schemas/$schema_/structure.sql

cat <(echo "create schema $schema; set search_path to $schema,public;") $1/schemas/$schema_/structure.sql | psql -d $db &&
    ./squealgen $db $modulename $schema $extra_imports > $tmp &&
    ./check_schema $tmp ${basedir}/${schema_}.hs
#         # an unprincipled hack: we tag the db connstr in the directory
