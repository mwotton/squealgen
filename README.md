# squealgen

Generate squeal types from a running database.

My workflow looks like this:

```DBNAME=somedb make hack```

but for normal use, you need to run this from within this folder (this limitation is because I needed a haskell post-processor,
I hope to remove this limitation eventually.)

```
psql -v chosen_schema=public -v modulename=Schema < squealgen.sql > /your/project/dir/src/Schema.hs
```

