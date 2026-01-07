# =============================================================================
# Common Make Patterns and Functions
# =============================================================================
# Shared utilities for all platform builds.
#
# SECTIONS:
#   1. Shell Configuration - Bash settings for recipe execution
#   2. Portable Commands - Platform-specific command abstractions
#   3. Phony Target Registry - Centralized PHONY management
#   4. Logging Functions - Colored output helpers
#   5. Download Functions - Source code retrieval
#   6. Verification Helpers - Build validation
#   7. Cleanup Patterns - Source removal
#   8. Safety Directives - .DELETE_ON_ERROR, .SECONDARY
#
# VARIABLE SCOPING:
#   - Variables defined here are global to all including Makefiles
#   - Use ?= for defaults that platforms may override
#   - Use := for values that should not change
#
# NAMING CONVENTIONS:
#   - Version variables: UPPERCASE (e.g., LIBVPX_VERSION)
#   - Source directories: UPPERCASE_SRC (e.g., LIBVPX_SRC)
#   - Build directories: UPPERCASE_BUILD (e.g., AOM_BUILD)
#   - Stamp targets: lowercase.stamp (e.g., libvpx.stamp)
#   - Clean targets: lowercase-clean (e.g., libvpx-clean)
#
# CROSS-REFERENCES:
#   - shared/versions.mk: Version numbers and URLs
#   - platforms/*/config.mk: Platform-specific compiler settings
#   - shared/codecs/codec.mk: License-based codec selection
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
# Portable Commands
# =============================================================================
# Abstractions for platform-specific command differences

# Portable sed in-place edit (macOS uses -i '', Linux uses -i)
ifeq ($(shell uname -s),Darwin)
    SED_INPLACE = sed -i ''
else
    SED_INPLACE = sed -i
endif

# =============================================================================
# Phony Target Registry
# =============================================================================
# All phony targets should be added using: PHONY_TARGETS += target1 target2
# This allows distributed declaration across multiple files.

PHONY_TARGETS := all clean distclean help

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
		printf "$(COLOR_RED)[ERROR]$(COLOR_RESET) pkg-config file $(1).pc not found in $(2)/lib/pkgconfig\n"; \
		exit 1; \
	fi
	@printf "$(COLOR_GREEN)[OK]$(COLOR_RESET) $(1).pc verified\n"
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

# =============================================================================
# Safety Directives
# =============================================================================

# Delete targets if recipe fails (prevents corrupt artifacts)
.DELETE_ON_ERROR:

# Don't delete intermediate files (keep downloaded sources)
.SECONDARY:

# =============================================================================
# Consolidated PHONY Declaration
# =============================================================================

.PHONY: $(PHONY_TARGETS)
