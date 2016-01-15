# makeup-managed:begin
include makeup.mk
# makeup-managed:end

include $(MAKEUP_DIR)/makeup-kit-info/main.mk

VERSION := $(shell git describe --tags --abbrev=0 2>/dev/null || echo 0.1.0-dev)

.PHONY: build
build:
	@./build.sh

.PHONY: prep-bintray-json
prep-bintray-json:
# TRAVIS_TAG is set to the tag name if the build is a tag
ifdef TRAVIS_TAG
	@jq '.version.name |= "$(VERSION)"' _scripts/ci/bintray-template.json | \
		jq '.package.repo |= "helm"' > _scripts/ci/bintray-ci.json
else
	@jq '.version.name |= "$(VERSION)"' _scripts/ci/bintray-template.json \
		> _scripts/ci/bintray-ci.json
endif
