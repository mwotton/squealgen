#
# testTargets := $(patsubst %,%.hs,$(wildcard test/*/schemas/*))

testTargets := $(shell echo $(wildcard test/*/schemas/*) | tr ' ' '\n' | sed 's/\/schemas\/./\U&\E/;s/\/SCHEMAS\//\//g;' | while read x; do echo "$$x.hs"; done)
squealgen: squealgen.sql mksquealgen.sh
	./mksquealgen.sh

install: squealgen
	install squealgen $(prefix)/bin/squealgen

.PHONY: test
test: squealgen $(testTargets)
	@echo $(testTargets)
	stack test --ghc-options="-fprint-potential-instances"

clean:
	rm $(testTargets)
.PHONY: initdb_exists
initdb_exists:
	which initdb

testwatch: initdb_exists
	while true; do \
		make test; \
		inotifywait -r -e modify -e create -e delete -e move $$(find test -iname '*.hs' | grep -v '#' | grep -v Schema.hs) $$(find . -iname '*\.sql' | grep -v '#' ) squealgen.sql mksquealgen.sh Makefile stack.yaml package.yaml ;\
	done

# todo: bomb out if `schema` doesn't exist.
%.hs: schemas/% squealgen
	@echo $(@D/schemas/%)

	$(eval db := $(shell vendor/pg_tmp))
	@echo $(db)
	$(eval schema := $(shell cat $$<))
#	$(eval extra_imports := $(shell cat $(@D)/extra_imports))
	$(eval tmp := $(shell mktemp /tmp/squealgen.XXXXXX))
	@echo $(tmp)
	psql -d $(db) < $< && ./squealgen $(db) "$(patsubst test/%,%,$(*D)).$(*F)" $(schema) $(extra_imports) > $(tmp)
	./check_schema $(tmp) $@

# an unprincipled hack: we tag the db connstr in the directory
