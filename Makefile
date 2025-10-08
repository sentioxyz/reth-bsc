.DEFAULT_GOAL := help

GIT_SHA ?= $(shell git rev-parse HEAD)
GIT_TAG ?= $(shell git describe --tags --abbrev=0 2>/dev/null)

# Cargo profile for builds. Default is for local builds, CI uses an override.
PROFILE ?= release

# The docker image name
DOCKER_IMAGE_NAME ?= ghcr.io/sentioxyz/reth-bsc

##@ Help

.PHONY: help
help: ## Display this help.
	@awk 'BEGIN {FS = ":.*##"; printf "Usage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_0-9-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

.PHONY: build
build: ## Build the reth binary into `target` directory.
	cargo build --bin reth-bsc --features "$(FEATURES)" --profile "$(PROFILE)"

.PHONY: maxperf
maxperf: ## Builds `reth-bsc` with the most aggressive optimisations.
	RUSTFLAGS="-C target-cpu=native" cargo build --bin reth-bsc --profile maxperf --features jemalloc,asm-keccak

.PHONY: bench-test
bench-test: ## Builds `reth-bsc` with the bench-test feature.
	RUSTFLAGS="-C target-cpu=native" cargo build --profile maxperf --features jemalloc,asm-keccak,bench-test

.PHONY: reth-bench
reth-bench: ## Build the reth-bench binary into the `target` directory.
	cargo build --manifest-path bin/reth-bench/Cargo.toml --features "$(FEATURES)" --profile "$(PROFILE)"
	@echo "reth-bench-bsc built successfully"
	@echo "Location: bin/reth-bench/target/$(PROFILE)/reth-bench-bsc"
	@echo ""

check-features:
	cargo hack check \
		--package reth-codecs \
		--package reth-primitives-traits \
		--package reth-primitives \
		--feature-powerset

##@ Docker

# Note: This requires a buildx builder with emulation support. For example:
#
# `docker run --privileged --rm tonistiigi/binfmt --install amd64,arm64`
# `docker buildx create --use --driver docker-container --name cross-builder`
.PHONY: docker-build-push
docker-build-push: ## Build and push a cross-arch Docker image tagged with the latest git tag.
	$(call docker_build_push,$(GIT_TAG),$(GIT_TAG))

# Note: This requires a buildx builder with emulation support. For example:
#
# `docker run --privileged --rm tonistiigi/binfmt --install amd64,arm64`
# `docker buildx create --use --driver docker-container --name cross-builder`
.PHONY: docker-build-push-git-sha
docker-build-push-git-sha: ## Build and push a cross-arch Docker image tagged with the latest git sha.
	$(call docker_build_push,$(GIT_SHA),$(GIT_SHA))

# Note: This requires a buildx builder with emulation support. For example:
#
# `docker run --privileged --rm tonistiigi/binfmt --install amd64,arm64`
# `docker buildx create --use --driver docker-container --name cross-builder`
.PHONY: docker-build-push-latest
docker-build-push-latest: ## Build and push a cross-arch Docker image tagged with the latest git tag and `latest`.
	$(call docker_build_push,$(GIT_TAG),latest)

# Note: This requires a buildx builder with emulation support. For example:
#
# `docker run --privileged --rm tonistiigi/binfmt --install amd64,arm64`
# `docker buildx create --use --name cross-builder`
.PHONY: docker-build-push-nightly
docker-build-push-nightly: ## Build and push cross-arch Docker image tagged with the latest git tag with a `-nightly` suffix, and `latest-nightly`.
	$(call docker_build_push,nightly,nightly)

# Create a Docker image using the main Dockerfile
define docker_build_push
	docker buildx build --file ./Dockerfile . \
		--platform linux/amd64 \
		--tag $(DOCKER_IMAGE_NAME):$(1) \
		--tag $(DOCKER_IMAGE_NAME):$(2) \
		--build-arg BUILD_PROFILE="$(PROFILE)" \
		--build-arg FEATURES="jemalloc,asm-keccak" \
		--provenance=false \
		--push
endef