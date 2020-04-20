testTargets := $(patsubst %.dump.sql,%.hs,$(wildcard test/*/Schema.dump.sql))

hack:
	while true; do psql ${DBNAME} -v chosen_schema=public -v modulename=Schema < squealgen.sql > src/Schema.hs && echo "start" && tail -30 src/Schema.hs && echo "end" && echo "" | stack repl squealgen:lib 2>&1 | head -20; inotifywait squealgen.sql  -e CLOSE_WRITE; done

squealgen: squealgen.sql mksquealgen.sh
	./mksquealgen.sh

install: squealgen
	install squealgen $(prefix)/bin/squealgen

.PHONY: test
test: squealgen $(testTargets)
	 stack test

clean:
	rm $(testTargets)

testwatch:
	while true; do \
		inotifywait -r -e modify -e create -e delete -e move $$(find src test -iname '*.hs' | grep -v '#' | grep -v Schema.hs) $$(find . -iname '*\.sql') squealgen.sql mksquealgen.sh Makefile stack.yaml package.yaml ;\
		make test; \
	done

# todo: bomb out if `schema` doesn't exist.
%.hs: %.dump.sql squealgen

	$(eval db := $(shell pg_tmp))
	@echo $(db)

	$(eval schema := $(shell cat $(@D)/schema))
	@echo $(schema)
#	@echo $<

	psql -d $(db) < $<
#	echo "\d foo" | psql -d $(db)
#	echo ./squealgen test $(*F) $(schema) > $@
	./squealgen $(db) "$(patsubst test/%,%,$(*D)).$(*F)" $(schema)  > $@
