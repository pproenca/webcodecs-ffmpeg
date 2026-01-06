# =============================================================================
# Common Make Patterns and Functions
# =============================================================================
# Shared utilities for all platform builds
# =============================================================================

SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c

NPROC ?= $(shell nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)

ifneq ($(TERM),)
    COLOR_GREEN := \033[0;32m
    COLOR_YELLOW := \033[1;33m
    COLOR_RED := \033[0;31m
    COLOR_RESET := \033[0m
else
    COLOR_GREEN :=
    COLOR_YELLOW :=
    COLOR_RED :=
    COLOR_RESET :=
endif

# =============================================================================
# Logging Functions
# =============================================================================

define log_info
	@printf "$(COLOR_GREEN)[INFO]$(COLOR_RESET) %s\n" "$(1)"
endef

define log_warn
	@printf "$(COLOR_YELLOW)[WARN]$(COLOR_RESET) %s\n" "$(1)"
endef

define log_error
	@printf "$(COLOR_RED)[ERROR]$(COLOR_RESET) %s\n" "$(1)"
endef

# =============================================================================
# Download Functions
# =============================================================================

# Download and extract a tarball
# Usage: $(call download_and_extract,name,url,target_dir)
# Example: $(call download_and_extract,libvpx,$(LIBVPX_URL),$(SOURCES_DIR))
define download_and_extract
	$(call log_info,Downloading $(1)...)
	@mkdir -p $(3)
	@if [ ! -f "$(3)/$(1).tar.gz" ]; then \
		curl -fSL --retry 3 -o "$(3)/$(1).tar.gz" "$(2)"; \
	fi
	$(call log_info,Extracting $(1)...)
	@tar -xzf "$(3)/$(1).tar.gz" -C "$(3)"
endef

# Git clone at specific branch/tag
# Usage: $(call git_clone,name,repo_url,branch,target_dir)
# Example: $(call git_clone,x264,$(X264_REPO),$(X264_VERSION),$(SOURCES_DIR))
define git_clone
	$(call log_info,Cloning $(1) at $(3)...)
	@mkdir -p $(4)
	@if [ ! -d "$(4)/$(1)" ]; then \
		git clone --depth 1 --branch $(3) $(2) $(4)/$(1); \
	else \
		$(call log_info,$(1) already cloned); \
	fi
endef

# =============================================================================
# Build Helpers
# =============================================================================

# Standard autoconf build pattern
# Usage: $(call autoconf_build,source_dir,configure_args)
define autoconf_build
	cd $(1) && \
	./configure $(2) && \
	$(MAKE) -j$(NPROC) && \
	$(MAKE) install
endef

# Standard CMake build pattern
# Usage: $(call cmake_build,source_dir,build_dir,cmake_args)
define cmake_build
	mkdir -p $(2) && \
	cd $(2) && \
	cmake $(1) $(3) && \
	$(MAKE) -j$(NPROC) && \
	$(MAKE) install
endef

# Standard Meson build pattern
# Usage: $(call meson_build,source_dir,build_dir,meson_args)
define meson_build
	cd $(1) && \
	meson setup $(2) $(3) && \
	ninja -C $(2) && \
	ninja -C $(2) install
endef

# =============================================================================
# Verification Helpers
# =============================================================================

# Verify a static library exists
# Usage: $(call verify_static_lib,libname,prefix)
define verify_static_lib
	@if [ ! -f "$(2)/lib/$(1).a" ]; then \
		printf "$(COLOR_RED)[ERROR]$(COLOR_RESET) Static library $(1).a not found in $(2)/lib\n"; \
		exit 1; \
	fi
	@printf "$(COLOR_GREEN)[OK]$(COLOR_RESET) $(1).a verified\n"
endef

# Verify pkg-config file exists
# Usage: $(call verify_pkgconfig,name,prefix)
define verify_pkgconfig
	@if [ ! -f "$(2)/lib/pkgconfig/$(1).pc" ]; then \
		printf "$(COLOR_YELLOW)[WARN]$(COLOR_RESET) pkg-config file $(1).pc not found\n"; \
	fi
endef

# =============================================================================
# Cleanup Patterns
# =============================================================================

# Clean a specific codec build
# Usage: $(call clean_codec,name,sources_dir)
define clean_codec
	rm -rf $(2)/$(1)* $(1).stamp
endef

# =============================================================================
# Stamp File Pattern
# =============================================================================
# All codec builds use stamp files to track completion:
#   codec.stamp - created after successful build
#
# This enables:
#   - Incremental builds (skip completed codecs)
#   - Explicit dependency ordering
#   - Easy status checking

.PRECIOUS: %.stamp
