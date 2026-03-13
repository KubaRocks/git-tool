.PHONY: release

release:
	@echo "Preparing release..."
	@today=$$(date +%Y.%m.%d); \
	version="v$$today"; \
	suffix=1; \
	while git tag -l "$$version" | grep -q "$$version"; do \
		suffix=$$((suffix + 1)); \
		version="v$$today.$$suffix"; \
	done; \
	echo "Version: $$version"; \
	\
	echo "$$version" > VERSION; \
	sed -i '' "s/^GT_VERSION=.*/GT_VERSION=\"$$version\"/" gt; \
	\
	git add VERSION gt; \
	git commit -m "release: $$version"; \
	git tag "$$version"; \
	git push && git push --tags; \
	echo ""; \
	echo "Released $$version"
