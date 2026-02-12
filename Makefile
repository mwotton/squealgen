testTargets := $(subst /schemas,,$(patsubst %/structure.sql,%.hs,$(wildcard test/*/schemas/*/structure.sql)))

squealgen: squealgen.sql mksquealgen.sh
	./mksquealgen.sh

install: squealgen
	install squealgen $(prefix)/bin/squealgen

.PHONY: check-squealgen-drift
check-squealgen-drift: squealgen.sql mksquealgen.sh
	./check_squealgen_drift.sh

.PHONY: test
test: check-squealgen-drift squealgen $(testTargets)
	@echo "testtargets: " $(testTargets)
	cabal test --test-show-details=direct --ghc-option=-fprint-potential-instances

.PHONY: ci
ci: check-squealgen-drift squealgen $(testTargets)
	@echo "Validation contract [ci]: running cabal test (reduced falsify cases)"
	cabal test --test-show-details=direct --ghc-option=-fprint-potential-instances --test-options="--falsify-tests 25"

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
		inotifywait -r -e modify -e create -e delete -e move $$(find test -iname '*.hs' | grep -v '#' | grep -v Schema.hs) $$(find . -iname '*\.sql' | grep -v '#' ) squealgen.sql mksquealgen.sh Makefile cabal.project package.yaml ;\
	done

# todo: bomb out if `schema` doesn't exist.
%.hs: schemas/%/structure.sql schemas/%/extra_imports squealgen
	./buildTestSchema.sh $(dir $*) $(notdir $*)

.PHONY: install-exe
install-exe:
	cabal install exe:squealgen --installdir=$(prefix)/bin --overwrite-policy=always
