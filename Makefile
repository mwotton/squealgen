hack:
	while true; do echo "" | stack runhaskell ./app/genConstraints.hs -- public >/dev/null &&  psql ${DBNAME} -v chosen_schema=public -v modulename=Simspace.Schema.Squeal < squealgen.sql > src/Schema.hs && echo "start" && head -30 src/Schema.hs && echo "end" && echo "" | stack repl squealgen:lib 2>&1 | head -20; inotifywait squealgen.sql app/genConstraints.hs -e CLOSE_WRITE; done



