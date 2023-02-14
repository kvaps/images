# Build docker images from submodules using kaniko
#
# Copyright 2020 Andrei Kvapil
# SPDX-License-Identifier: Apache-2.0

# Source directory with submodules
SRC = sources

CACHE_REPO=ghcr.io/kvaps/cache

# Force regenerate images if no changes detected
FORCE ?= 0

# Detect which submodules were changed
ALLSUBS = $(shell git ls-files ${SRC} --stage | awk '$$1 = "160000" {print $$NF}')
CHANGED = $(shell git status --short ${SRC} | awk '$$1 ~ "^(A|M)" {print $$2}')

# ------------------------------------------------------------------------------
# Kube-linstor
# ------------------------------------------------------------------------------

TARGETS += \
	sources/kube-linstor/dockerfiles/linstor-controller \
	sources/kube-linstor/dockerfiles/linstor-satellite \
	sources/kube-linstor/dockerfiles/linstor-csi \
	sources/kube-linstor/dockerfiles/linstor-stork \
	sources/kube-linstor/dockerfiles/linstor-ha-controller

IMAGES += \
	ghcr.io/kvaps/linstor-controller,docker.io/kvaps/linstor-controller \
	ghcr.io/kvaps/linstor-satellite,docker.io/kvaps/linstor-satellite \
	ghcr.io/kvaps/linstor-csi,docker.io/kvaps/linstor-csi \
	ghcr.io/kvaps/linstor-stork,docker.io/kvaps/linstor-stork \
	ghcr.io/kvaps/linstor-ha-controller,docker.io/kvaps/linstor-ha-controller

ARGS += \
	--cache,--cache-repo=$(CACHE_REPO)/linstor \
	--cache,--cache-repo=$(CACHE_REPO)/linstor \
	--cache,--cache-repo=$(CACHE_REPO)/linstor \
	--cache,--cache-repo=$(CACHE_REPO)/linstor \
	--cache,--cache-repo=$(CACHE_REPO)/linstor

# ------------------------------------------------------------------------------
# Kube-fencing
# ------------------------------------------------------------------------------

TARGETS += \
	sources/kube-fencing \
	sources/kube-fencing \
	sources/kube-fencing

IMAGES += \
	ghcr.io/kvaps/kube-fencing-agents \
	ghcr.io/kvaps/kube-fencing-controller \
	ghcr.io/kvaps/kube-fencing-switcher

ARGS += \
	--cache,--cache-repo=$(CACHE_REPO)/fencing,--dockerfile=/build/agents/Dockerfile \
	--cache,--cache-repo=$(CACHE_REPO)/fencing,--dockerfile=/build/controller/Dockerfile \
	--cache,--cache-repo=$(CACHE_REPO)/fencing,--dockerfile=/build/switcher/Dockerfile

# ------------------------------------------------------------------------------
# Dnsmasq-controller
# ------------------------------------------------------------------------------

TARGETS += sources/dnsmasq-controller

IMAGES += ghcr.io/kvaps/dnsmasq-controller,ghcr.io/kubefarm/dnsmasq-controller,docker.io/kvaps/dnsmasq-controller

ARGS += --cache,--cache-repo=$(CACHE_REPO)/dnsmasq-controller

# ------------------------------------------------------------------------------
# Kubefarm images
# ------------------------------------------------------------------------------

TARGETS += \
       sources/kubefarm/build/ltsp \
       sources/kubernetes-in-kubernetes/build/tools \
       sources/kube-pipework

IMAGES += \
       ghcr.io/kvaps/kubefarm-ltsp,ghcr.io/kubefarm/kubefarm-ltsp,docker.io/kvaps/kubefarm-ltsp \
       ghcr.io/kvaps/kubernetes-tools,ghcr.io/kubefarm/kubernetes-tools,docker.io/kvaps/kubernetes-tools \
       docker.io/kvaps/pipework

ARGS += \
       --cache,--cache-repo=$(CACHE_REPO)/infra \
       --cache,--cache-repo=$(CACHE_REPO)/infra \
       --cache,--cache-repo=$(CACHE_REPO)/infra

# ------------------------------------------------------------------------------
# OpenNebula images
# ------------------------------------------------------------------------------

TARGETS += \
	sources/kube-opennebula/dockerfiles/opennebula-packages \
	sources/kube-opennebula/dockerfiles/opennebula \
	sources/kube-opennebula/dockerfiles/opennebula-exporter \
	sources/kube-opennebula/dockerfiles/opennebula-flow \
	sources/kube-opennebula/dockerfiles/opennebula-gate \
	sources/kube-opennebula/dockerfiles/opennebula-node \
	sources/kube-opennebula/dockerfiles/opennebula-sunstone

IMAGES += \
	ghcr.io/kvaps/opennebula-packages,docker.io/kvaps/opennebula-packages \
	ghcr.io/kvaps/opennebula,docker.io/kvaps/opennebula \
	ghcr.io/kvaps/opennebula-exporter,docker.io/kvaps/opennebula-exporter \
	ghcr.io/kvaps/opennebula-flow,docker.io/kvaps/opennebula-flow \
	ghcr.io/kvaps/opennebula-gate,docker.io/kvaps/opennebula-gate \
	ghcr.io/kvaps/opennebula-node,docker.io/kvaps/opennebula-node \
	ghcr.io/kvaps/opennebula-sunstone,docker.io/kvaps/opennebula-sunstone

ARGS += \
	--cache,--cache-repo=$(CACHE_REPO)/opennebula \
	--cache,--cache-repo=$(CACHE_REPO)/opennebula \
	--cache,--cache-repo=$(CACHE_REPO)/opennebula \
	--cache,--cache-repo=$(CACHE_REPO)/opennebula \
	--cache,--cache-repo=$(CACHE_REPO)/opennebula \
	--cache,--cache-repo=$(CACHE_REPO)/opennebula \
	--cache,--cache-repo=$(CACHE_REPO)/opennebula

# ------------------------------------------------------------------------------
# Functions
# ------------------------------------------------------------------------------

define uniq
	$(eval seen :=) $(foreach _,$1,$(if $(filter $_,${seen}),,$(eval seen += $_))) ${seen}
endef

define image_by_target
	$(foreach a,$(full_list), \
		$(eval line=$(subst $(comma),$(space),$(a))) \
		$(if $(filter $1,$(word 2,$(line))),$(word 1,$(line))) \
	)
endef

define target_by_image
	$(foreach a,$(full_list), \
		$(eval line=$(subst $(comma),$(space),$(a))) \
		$(if $(filter $1,$(word 1,$(line))),$(word 2,$(line))) \
	)
endef

define build_image
	$(foreach a,$(full_list), \
		$(eval line=$(subst $(comma),$(space),$(a))) \
		$(if $(filter $1,$(word 1,$(line))), \
			$(eval image=$(word 1,$(line)))
			$(eval context=$(word 2,$(line)))
			$(eval args=$(wordlist 3, $(words $(line)), $(line)))
			cd $(word 2,$(line)); \
			tag=$$(git describe --tags --abbrev=0) && \
			hash=$$(git rev-parse HEAD) && \
			url=$$(git config --get remote.origin.url) && \
			date=$$(date -u +%Y-%m-%dT%H:%M:%S.%6N) && \
			if [ $(FORCE) != 1 ] && skopeo inspect docker://$1:$${tag} 2>&1 | grep -q "$${hash}"; then \
				echo "=== image $(image):$${tag} is up to date ===" >&2; \
			else \
				echo "=== building $(image):$${tag} ===" >&2; \
				echo "current path: $$PWD"; \
				name=build-$$(echo $(notdir $(image))-$${tag} | head -c 51)-$$(env LC_ALL=C tr -dc a-z0-9 </dev/urandom | head -c 6) \
				set -x; \
				KUBECTL_BUILD_NAME_OVERRIDE="$$name" \
				kubectl build -c . -d $(image):$${tag} $(args) \
					--label=build-date=$${date} \
					--label=vcs-ref=$${hash} \
					--label=vcs-type=git --force \
					--label=vcs-url=$${url}; \
			fi
		) \
	)
endef

# ------------------------------------------------------------------------------
# Generate list of targets
# ------------------------------------------------------------------------------

ifneq ($(words $(TARGETS)),$(words $(IMAGES)))
	$(error number of IMAGES not equas TARGETS)
endif
ifneq ($(words $(TARGETS)),$(words $(ARGS)))
	$(error number of ARGS not equal TARGETS)
endif

comma:= ,
empty:=
space:= $(empty) $(empty)
$(eval j=1) \
$(foreach target,$(TARGETS), \
	$(foreach image,$(subst $(comma),$(space),$(word $j,$(IMAGES))), \
		$(eval targets_list+=$(target)) \
		$(eval images_list+=$(image)) \
		$(eval full_list+=$(image),$(target),$(word $j,$(ARGS))) \
	) \
	$(eval j=$(shell echo $$(($(j)+1)))) \
)
targets_list_uniq=$(call uniq,$(targets_list))
subs=$(filter-out $(targets_list_uniq), $(ALLSUBS))

# ------------------------------------------------------------------------------
# Targets
# ------------------------------------------------------------------------------

.PHONY: list list-images list-submodules list-targets list-changed pull all changed push $(images_list) $(targets_list_uniq) $(subs)

# Find and build changed submodules
auto:
	@$(MAKE) --no-print-directory pull
	@$(MAKE) --no-print-directory changed
	@$(MAKE) --no-print-directory push

# Check for required executables
check:
	@command -V skopeo
	@command -V kubectl-build

# List all possible targets
list: list-images list-submodules list-targets

# List changed submodules
list-images:
	@printf "%s\n" $(images_list)

# List changed submodules
list-submodules:
	@printf "%s\n" $(subs)

# List changed submodules
list-targets:
	@printf "%s\n" $(targets_list_uniq)

# List changed submodules
list-changed:
	@printf "%s\n" $(CHANGED)

# Build by target path
$(targets_list_uniq):
	$(MAKE) --no-print-directory $(strip $(call image_by_target,$@))

# Build by submodule path and commit
$(subs):
	$(MAKE) --no-print-directory $(shell $(MAKE) list | grep "^$@/")
	git diff-index HEAD --quiet --exit-code $@ || git commit $@ -m "Build: $@ ($$(cd $@; git describe --tags --abbrev=0))"

# Build by image name
$(images_list): check
	@$(call build_image,$@)

# Fetch submodule updates
pull:
	git submodule update --init ${ALLSUBS}
	@for i in ${ALLSUBS}; do \
		(echo "[$$i]" && cd $$i && \
		git fetch --tags --force --prune --prune-tags && \
		git -c advice.detachedHead=false checkout $$(git tag --sort=committerdate | tail -1) && \
		git clean -fdx); \
	done

# Build all submodules
all: $(ALLSUBS)

# Build changed submodules
changed: $(CHANGED)

# Push changes to remote origin
push:
	git diff HEAD origin/$$(git symbolic-ref --short HEAD) --quiet --exit-code || git push origin
