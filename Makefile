testTargets := $(subst /schemas,,$(patsubst %/structure.sql,%.hs,$(wildcard test/*/schemas/*/structure.sql)))

squealgen: squealgen.sql mksquealgen.sh
	./mksquealgen.sh

install: squealgen
	install squealgen $(prefix)/bin/squealgen

.PHONY: test
test: squealgen $(testTargets)
	@echo "testtargets: " $(testTargets)
	stack test --ghc-options="-fprint-potential-instances"

foo:
	echo $(testTargets)
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
%.hs: schemas/%/structure.sql schemas/%/extra_imports squealgen
	./buildTestSchema.sh $(dir $*) $(notdir $*)
