testTargets := $(patsubst %.dump.sql,%.hs,$(wildcard test/*/Schema.dump.sql))

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
		make test; \
		inotifywait -r -e modify -e create -e delete -e move $$(find src test -iname '*.hs' | grep -v '#' | grep -v Schema.hs) $$(find . -iname '*\.sql') squealgen.sql mksquealgen.sh Makefile stack.yaml package.yaml ;\
	done

# todo: bomb out if `schema` doesn't exist.
%.hs: %.dump.sql squealgen

	$(eval db := $(shell pg_tmp))
	@echo $(db)
	$(eval schema := $(shell cat $(@D)/schema))
	psql -d $(db) < $<
	./squealgen $(db) "$(patsubst test/%,%,$(*D)).$(*F)" $(schema)  > $@
        # an unprincipled hack: we tag the db connstr in the directory
