ifdef GITHUB_SHA #is it running in GitHub Actions
	cfcompile := cfcompile
else
	cfcompile := docker run --rm -v `pwd`:/src -w /src -u root theonestack/cfhighlander cfcompile
endif

.PHONY: test
test: ./*.cfhighlander.rb
	for file in $^ ; do \
		basename -- $${file} .cfhighlander.rb | xargs $(cfcompile) -q || exit 1 ; \
	done


.PHONY: build
build: ./*.cfhighlander.rb
	for file in $^ ; do \
		basename -- $${file} .cfhighlander.rb | xargs $(cfcompile) -q || exit 1 ; \
		basename -- $${file} .cfhighlander.rb | xargs -I@ cp out/yaml/@.compiled.yaml stacks/templates/  ; \
	done
