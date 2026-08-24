# =============================
# Jobe-in-a-box Docker image for DIVE
# =============================
# Build tooling for the jobeinabox image, mirroring ../jupyter/Makefile so the
# image is built/tagged the same way as the nb images (divenb, cs1302nb, ...).
#
# NOTE on registries:
#   This is the PUBLIC jobeinabox repo, so it must NOT assume the private
#   dive4dec cluster registry. It builds locally and, when asked to publish,
#   uses the generic local registry (localhost:32000) by default. The PRIVATE
#   dive-deploy/Makefile overrides the registry to
#   registry.dive4dec.svc.cluster.local so any node in the cluster can pull it.
#
# NOTE on versioning:
#   The image version lives HERE (in this public repo), not in dive-deploy, so
#   the tag is published alongside the source. Bump the number below to release
#   a new tag.

# Current image information
# =========================
# Syntax: IMAGE_NAME^IMAGE_VERSION[^BUILD_TARGET[^DOCKERFILE_SUFFIX]]
#   -> docker tag  IMAGE_NAME:IMAGE_VERSION
#   -> Dockerfile  Dockerfile[.DOCKERFILE_SUFFIX]   (in this repo's root)
jobeinabox := jobeinabox^1.0.1

# Registries
# ==========
# Generic local registry (default, public/portable). Do not hardcode dive4dec here.
private_registry ?= localhost:32000
# Public docker registry for publishing (multiarch) images.
public_registry ?= chungc
# Effective registry; empty = build locally only, push only when a registry is given.
registry ?=

# Commands
# ========
SHELL := /bin/bash

# Show image information
image-info.%:
	@ $(MAKE) parse-image-info.$($*)

# Prepare a docker image by building and pushing it to the registry (if non-empty)
image.%:
	@ $(MAKE) docker-build.$($*) && \
	$(if $(strip $(registry)),$(MAKE) docker-push.$($*))

# Publish a docker image to the public registry
public-image.%:
	@ $(MAKE) docker-multiarch.$($*) registry=$(public_registry)

# Build a multiarch docker image for publishing to the public registry
docker-multiarch.%: parse-image-info.%
	$(docker-multiarch)

define docker-multiarch
@echo "Building multiarch docker image..." && \
docker buildx build . \
--builder=container \
--platform linux/amd64,linux/arm64 \
$(if $(DOCKERFILE_SUFFIX),-f Dockerfile.$(DOCKERFILE_SUFFIX)) \
$(if $(BUILD_TARGET),--target $(BUILD_TARGET)) \
--cache-from=type=registry,ref=$(FULL_IMAGE_NAME):cache1 \
--cache-to=type=registry,ref=$(FULL_IMAGE_NAME):cache1,mode=max \
-t "$(FULL_IMAGE_NAME):$(IMAGE_TAG)" \
--push
endef

# Parse docker image information
parse-image-info.%:
	$(call parse-image-info,$*)
	$(info $(image-info))
	@:

define parse-image-info
$(eval _tokenized ?= $(subst ^, ^,$*))
$(eval IMAGE_NAME ?= $(word 1,$(_tokenized)))
$(eval IMAGE_VERSION ?= $(subst ^,,$(word 2,$(_tokenized))))
$(eval BUILD_TARGET ?= $(subst ^,,$(word 3,$(_tokenized))))
$(eval DOCKERFILE_SUFFIX ?= $(subst ^,,$(word 4,$(_tokenized))))
$(eval IMAGE_TAG ?= $(if $(IMAGE_VERSION),$(IMAGE_VERSION)$(if $(BUILD_TARGET),-$(BUILD_TARGET))$(if $(DOCKERFILE_SUFFIX),.$(DOCKERFILE_SUFFIX)),latest))
$(eval FULL_IMAGE_NAME ?= $(if $(strip $(registry)),$(registry)/$(IMAGE_NAME),$(IMAGE_NAME)))
endef

define image-info
==============================
Docker image
------------------------------
Name: $(FULL_IMAGE_NAME)
Tag: $(IMAGE_TAG)
Version: $(IMAGE_VERSION)
Dockerfile: Dockerfile.$(DOCKERFILE_SUFFIX)
Build target: $(BUILD_TARGET)
==============================
endef

# Build a docker image.
# Flat layout: the Dockerfile is in this repo's root (not a per-image subdir),
# so we build from "." with no `cd $(IMAGE_NAME)`.
docker-build.%: parse-image-info.%
	$(docker-build)

define docker-build
@echo "Building docker image..."
docker buildx build . \
-t "$(IMAGE_NAME):$(IMAGE_TAG)" \
$(if $(DOCKERFILE_SUFFIX),-f Dockerfile.$(DOCKERFILE_SUFFIX)) \
$(if $(BUILD_TARGET),--target $(BUILD_TARGET))
endef

# Pull a docker image
docker-pull.%: parse-image-info.%
	$(docker-pull)

define docker-pull
@ docker pull \
	"$(FULL_IMAGE_NAME):$(IMAGE_TAG)"
endef

# Run a docker image (jobe serves on port 80)
docker-run.%: parse-image-info.%
	$(docker-run)

define docker-run
@ docker run -it \
	-p 8080:80/tcp \
	"$(FULL_IMAGE_NAME):$(IMAGE_TAG)"
endef

# Push a docker image to the registry
docker-push.%: parse-image-info.%
	$(docker-push)

define docker-push
@echo "Pushing docker image..."
docker tag "$(IMAGE_NAME):$(IMAGE_TAG)" "$(FULL_IMAGE_NAME):$(IMAGE_TAG)" && \
docker push "$(FULL_IMAGE_NAME):$(IMAGE_TAG)"
endef
