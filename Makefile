
hack:
	while true; do psql ${DBNAME} -v chosen_schema=public -v modulename=Schema < squealgen.sql > src/Schema.hs && echo "start" && tail -30 src/Schema.hs && echo "end" && echo "" | stack repl squealgen:lib 2>&1 | head -20; inotifywait squealgen.sql  -e CLOSE_WRITE; done

squealgen: squealgen.sql mksquealgen.sh
	./mksquealgen.sh

install: squealgen
	install squealgen $(prefix)/bin/squealgen
