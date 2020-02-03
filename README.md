# squealgen

Generate squeal types from a running database.

My workflow looks like this:

```
while true; do inotifywait squealgen.sql -e CLOSE_WRITE; psql -v modulename=Schema < squealgen.sql > src/Schema.hs && echo "start" && head src/Schema.hs && echo "end" && echo "" | stack repl squealgen:lib 2>&1 | head -50; done
```

