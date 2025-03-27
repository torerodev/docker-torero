# makefile for building the torero docker image
#
# Copyright 2025 torerodev
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

.PHONY: build push push-all build-all clean test help

# docker hub username
DOCKER_USERNAME ?= torerodev

# default versions if not specified
# override with 'make build TORERO_VERSION=x.x.x'
TORERO_VERSION ?= 1.3.0

# default python version
PYTHON_VERSION ?= 3.13.0

# default tag as latest
TAG_AS_LATEST ?= true

# force rebuild (no-cache)
FORCE_REBUILD ?= false

# all available torero versions for build-all
TORERO_VERSIONS ?= 1.3.0

help:
	@echo "available targets:"
	@echo "  build       - build torero image with specified version"
	@echo "  build-all   - build all torero versions"
	@echo "  push        - push specific torero version to docker hub"
	@echo "  push-all    - push all torero versions to docker hub"
	@echo "  test        - run basic tests on the built image"
	@echo "  clean       - remove all torero images"
	@echo ""
	@echo "variables:"
	@echo "  DOCKER_USERNAME   - docker hub username (default: torerodev)"
	@echo "  TORERO_VERSION    - torero version to build (default: 1.3.0)"
	@echo "  PYTHON_VERSION    - python version to install (default: 3.13.0)"
	@echo "  TORERO_VERSIONS   - space-separated list of torero versions for build-all (default: 1.3.0)"
	@echo "  FORCE_REBUILD     - set to 'true' to force rebuild (default: false)"
	@echo "  TAG_AS_LATEST     - set to 'true' to tag latest version (default: true)"
	@echo ""
	@echo "examples:"
	@echo "  make build"
	@echo "  make build TORERO_VERSION=1.3.0 PYTHON_VERSION=3.13.0"
	@echo "  make build-all TORERO_VERSIONS=\"1.2.0 1.3.0\""
	@echo "  make push"
	@echo "  make push-all"

build:
	@echo "building image: $(DOCKER_USERNAME)/torero:$(TORERO_VERSION)"
	@if [ "$(FORCE_REBUILD)" = "true" ]; then \
		docker build -t $(DOCKER_USERNAME)/torero:$(TORERO_VERSION) \
			--build-arg TORERO_VERSION=$(TORERO_VERSION) \
			--build-arg PYTHON_VERSION=$(PYTHON_VERSION) \
			--no-cache .; \
	else \
		docker build -t $(DOCKER_USERNAME)/torero:$(TORERO_VERSION) \
			--build-arg TORERO_VERSION=$(TORERO_VERSION) \
			--build-arg PYTHON_VERSION=$(PYTHON_VERSION) .; \
	fi
	@if [ "$(TAG_AS_LATEST)" = "true" ] && \
		[ "$(TORERO_VERSION)" = "$(shell echo $(TORERO_VERSIONS) | tr ' ' '\n' | sort -V | tail -n1)" ]; then \
		echo "tagging $(TORERO_VERSION) as latest"; \
		docker tag $(DOCKER_USERNAME)/torero:$(TORERO_VERSION) $(DOCKER_USERNAME)/torero:latest; \
	fi

# build all torero versions
build-all:
	@for torero_version in $(TORERO_VERSIONS); do \
		$(MAKE) build TORERO_VERSION=$$torero_version PYTHON_VERSION=$(PYTHON_VERSION); \
	done

# push specific version to docker hub
push:
	@echo "pushing $(DOCKER_USERNAME)/torero:$(TORERO_VERSION) to docker hub..."
	docker push $(DOCKER_USERNAME)/torero:$(TORERO_VERSION)
	@if [ "$(TAG_AS_LATEST)" = "true" ] && \
		[ "$(TORERO_VERSION)" = "$(shell echo $(TORERO_VERSIONS) | tr ' ' '\n' | sort -V | tail -n1)" ]; then \
		echo "pushing latest tag"; \
		docker push $(DOCKER_USERNAME)/torero:latest; \
	fi

# push all versions to docker hub
push-all:
	@for torero_version in $(TORERO_VERSIONS); do \
		$(MAKE) push TORERO_VERSION=$$torero_version; \
	done

# run basic tests on the built image
test:
	@echo "testing $(DOCKER_USERNAME)/torero:$(TORERO_VERSION)..."
	@docker run --rm $(DOCKER_USERNAME)/torero:$(TORERO_VERSION) torero version
	@echo "testing python installation..."
	@docker run --rm $(DOCKER_USERNAME)/torero:$(TORERO_VERSION) python3 --version
	@echo "testing opentofu installation..."
	@docker run --rm -e INSTALL_OPENTOFU=true -e OPENTOFU_VERSION=1.6.2 $(DOCKER_USERNAME)/torero:$(TORERO_VERSION) bash -c "tofu version" || echo "opentofu test failed (expected on first run)"

# clean up all torero images
clean:
	@echo "removing all torero images..."
	-docker rmi $(shell docker images $(DOCKER_USERNAME)/torero -q) -f 2>/dev/null || true