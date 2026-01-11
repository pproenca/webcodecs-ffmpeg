# =============================================================================
# shared/verify.mk - Build Verification Functions
# =============================================================================
# Provides layered verification to catch issues early with actionable errors.
# Include after common.mk which defines logging functions.
#
# LAYERS:
#   0. Parse-Time: Variable validation during Makefile parsing
#   1. Preflight: Toolchain and environment checks before any build
#   2. Codec Post-Build: Library and pkg-config validation per codec
#   3. FFmpeg Pre-Configure: All codecs available before FFmpeg build
#   4. Final Binary: Architecture and linkage verification
#
# USAGE:
#   include $(PROJECT_ROOT)/shared/verify.mk
#   preflight: dirs
#       $(call verify_arch_toolchain,$(BUILD_DIR),$(CC),$(CFLAGS),$(ARCH_VERIFY_PATTERN))
# =============================================================================

# -----------------------------------------------------------------------------
# Allowed System Libraries by Platform
# -----------------------------------------------------------------------------
# These patterns define which dynamic libraries are acceptable in statically-
# linked binaries. Everything else is considered a linkage error.

# macOS: System framework libs only
ALLOWED_DYLIBS_darwin := libSystem|libc\+\+|libresolv|libz

# Linux (glibc): Core runtime libs only
ALLOWED_DYLIBS_linux := linux-vdso|ld-linux|libc\.so|libm\.so|libdl\.so|libpthread|librt\.so|libstdc\+\+|libgcc

# Linux (musl): Same as glibc for our purposes
ALLOWED_DYLIBS_linuxmusl := $(ALLOWED_DYLIBS_linux)

# -----------------------------------------------------------------------------
# Layer 0: Parse-Time Validation
# -----------------------------------------------------------------------------
# These checks run during Makefile parsing (before any recipe).
# Use $(call ...) at file scope, not in recipes.

# Validate version refs are immutable (not branch names)
# Usage: $(call validate_immutable_ref,VERSION_VAR_NAME,COMPONENT_NAME)
# Example: $(call validate_immutable_ref,X264_VERSION,x264)
define validate_immutable_ref
$(if $(filter stable master main HEAD,$($(1))),\
    $(error $(2) uses mutable ref '$($(1))'. Pin to commit hash for cache correctness.))
endef

# Ensure required variable is set
# Usage: $(call require_var,VAR_NAME,PURPOSE)
# Example: $(call require_var,PREFIX,installation prefix)
define require_var
$(if $($(1)),,$(error $(1) must be defined. $(2)))
endef

# -----------------------------------------------------------------------------
# Layer 1: Preflight Checks (run before any codec builds)
# -----------------------------------------------------------------------------

# Verify toolchain produces correct architecture
# Usage: $(call verify_arch_toolchain,BUILD_DIR,CC,CFLAGS,EXPECTED_PATTERN)
# Example: $(call verify_arch_toolchain,$(BUILD_DIR),$(CC),$(CFLAGS),arm64)
define verify_arch_toolchain
	@echo "Verifying toolchain architecture..."
	@echo 'int main() { return 0; }' > $(1)/arch_test.c
	@$(2) $(3) -o $(1)/arch_test $(1)/arch_test.c 2>/dev/null || \
		(echo ""; \
		 echo "ERROR: Toolchain compilation failed"; \
		 echo ""; \
		 echo "  Diagnosis:"; \
		 echo "    CC=$(2)"; \
		 echo "    CFLAGS=$(3)"; \
		 echo ""; \
		 echo "  Fix: Verify compiler is installed and CFLAGS are valid"; \
		 rm -f $(1)/arch_test.c; \
		 exit 1)
	@if ! file $(1)/arch_test | grep -q "$(4)"; then \
		echo ""; \
		echo "ERROR: Toolchain produces wrong architecture"; \
		echo ""; \
		echo "  Diagnosis:"; \
		echo "    Expected: $(4)"; \
		echo "    Got: $$(file $(1)/arch_test)"; \
		echo ""; \
		echo "  Fix: Check CC and CFLAGS in config.mk"; \
		echo "       For cross-compile: verify CROSS_PREFIX is set"; \
		rm -f $(1)/arch_test.c $(1)/arch_test; \
		exit 1; \
	fi
	@rm -f $(1)/arch_test.c $(1)/arch_test
	@printf "$(COLOR_GREEN)  [OK]$(COLOR_RESET) Toolchain verified: %s\n" "$(4)"
endef

# Verify pkg-config isolation (only finds our libs, not system)
# Usage: $(call verify_pkgconfig_isolation,PKG_CONFIG_LIBDIR)
# Example: $(call verify_pkgconfig_isolation,$(PREFIX)/lib/pkgconfig)
define verify_pkgconfig_isolation
	@echo "Verifying pkg-config isolation..."
	@if PKG_CONFIG_LIBDIR="$(1)" pkg-config --exists glib-2.0 2>/dev/null; then \
		printf "$(COLOR_YELLOW)  [WARN]$(COLOR_RESET) pkg-config finds system libs (glib-2.0)\n"; \
		echo "    PKG_CONFIG_LIBDIR=$(1)"; \
		echo "    System libs may leak into build"; \
	else \
		printf "$(COLOR_GREEN)  [OK]$(COLOR_RESET) pkg-config isolation verified\n"; \
	fi
endef

# -----------------------------------------------------------------------------
# Layer 2: Codec Post-Build Verification (enhanced versions)
# -----------------------------------------------------------------------------
# These enhance the basic verify functions in common.mk with architecture checks.

# Verify static library exists and has correct architecture
# Usage: $(call verify_static_lib_arch,LIB_PATH,ARCH_PATTERN)
# Example: $(call verify_static_lib_arch,$(PREFIX)/lib/libx265.a,arm64)
define verify_static_lib_arch
	@if [ ! -f "$(1)" ]; then \
		echo ""; \
		echo "ERROR: Static library not found: $(1)"; \
		echo ""; \
		echo "  Diagnosis:"; \
		echo "    Build may have failed silently"; \
		echo "    Check build logs for errors"; \
		echo ""; \
		echo "  Fix: Re-run the codec build with DEBUG=1"; \
		exit 1; \
	fi
	@if ! file "$(1)" | grep -q "$(2)"; then \
		echo ""; \
		echo "ERROR: Library has wrong architecture: $(1)"; \
		echo ""; \
		echo "  Diagnosis:"; \
		echo "    Expected: $(2)"; \
		echo "    Got: $$(file $(1))"; \
		echo ""; \
		echo "  Fix: Verify cross-compilation flags in config.mk"; \
		exit 1; \
	fi
endef

# Verify pkg-config file exists and resolves correctly
# Usage: $(call verify_pkgconfig_resolves,PC_DIR,PKG_NAME)
# Example: $(call verify_pkgconfig_resolves,$(PREFIX)/lib/pkgconfig,x265)
define verify_pkgconfig_resolves
	@if [ ! -f "$(1)/$(2).pc" ]; then \
		echo ""; \
		echo "ERROR: pkg-config file not found: $(1)/$(2).pc"; \
		echo ""; \
		echo "  Diagnosis:"; \
		echo "    Codec build may have failed or skipped pkg-config generation"; \
		echo ""; \
		echo "  Fix: Check if codec supports pkg-config generation"; \
		exit 1; \
	fi
	@if ! PKG_CONFIG_LIBDIR="$(1)" pkg-config --exists $(2) 2>/dev/null; then \
		echo ""; \
		echo "ERROR: pkg-config cannot resolve $(2)"; \
		echo ""; \
		echo "  Diagnosis:"; \
		echo "    File exists: $(1)/$(2).pc"; \
		echo "    But pkg-config --exists fails"; \
		echo ""; \
		echo "  Check .pc file syntax:"; \
		echo "    cat $(1)/$(2).pc"; \
		exit 1; \
	fi
endef

# -----------------------------------------------------------------------------
# Layer 3: FFmpeg Pre-Configure Verification
# -----------------------------------------------------------------------------

# Verify all required codecs are available before FFmpeg configure
# Usage: $(call verify_codecs_available,PKG_CONFIG_LIBDIR,CODEC_LIST)
# Example: $(call verify_codecs_available,$(PREFIX)/lib/pkgconfig,aom x264 x265)
define verify_codecs_available
	@echo "Verifying codec availability for FFmpeg..."
	@failed=0; \
	for codec in $(2); do \
		if ! PKG_CONFIG_LIBDIR="$(1)" pkg-config --exists $$codec 2>/dev/null; then \
			printf "$(COLOR_RED)  [FAIL]$(COLOR_RESET) %s not found\n" "$$codec"; \
			failed=1; \
		else \
			printf "$(COLOR_GREEN)  [OK]$(COLOR_RESET) %s\n" "$$codec"; \
		fi; \
	done; \
	if [ $$failed -eq 1 ]; then \
		echo ""; \
		echo "ERROR: Some codecs not available for FFmpeg"; \
		echo ""; \
		echo "  PKG_CONFIG_LIBDIR=$(1)"; \
		echo ""; \
		echo "  Available .pc files:"; \
		ls -1 $(1)/*.pc 2>/dev/null | sed 's/^/    /' || echo "    (none)"; \
		echo ""; \
		echo "  Fix: Build missing codecs first with 'make codecs'"; \
		exit 1; \
	fi
	@printf "$(COLOR_GREEN)[OK]$(COLOR_RESET) All codecs verified\n"
endef

# -----------------------------------------------------------------------------
# Layer 4: Final Binary Verification
# -----------------------------------------------------------------------------

# Verify binary architecture
# Usage: $(call verify_binary_arch,BINARY_PATH,ARCH_PATTERN)
# Example: $(call verify_binary_arch,$(PREFIX)/bin/ffmpeg,arm64)
define verify_binary_arch
	@if ! file "$(1)" | grep -q "$(2)"; then \
		echo ""; \
		echo "ERROR: Binary has wrong architecture: $(1)"; \
		echo ""; \
		echo "  Diagnosis:"; \
		echo "    Expected: $(2)"; \
		echo "    Got: $$(file $(1))"; \
		echo ""; \
		echo "  Fix: Check cross-compilation settings"; \
		exit 1; \
	fi
	@printf "$(COLOR_GREEN)  [OK]$(COLOR_RESET) Architecture verified: %s\n" "$(2)"
endef

# Verify static linkage on darwin (using otool)
# Usage: $(call verify_static_linkage_darwin,BINARY_PATH)
define verify_static_linkage_darwin
	@if otool -L "$(1)" | tail -n +2 | grep -vE "^\s+/usr/lib/(libSystem|libc\+\+|libresolv|libz)" | grep -q "\.dylib"; then \
		echo ""; \
		echo "ERROR: Binary has unexpected dynamic dependencies:"; \
		otool -L "$(1)" | tail -n +2 | grep -vE "^\s+/usr/lib/(libSystem|libc\+\+|libresolv|libz)"; \
		echo ""; \
		echo "  Fix: Ensure all codecs are built as static libraries"; \
		exit 1; \
	fi
	@printf "$(COLOR_GREEN)  [OK]$(COLOR_RESET) Static linkage verified (darwin)\n"
endef

# Verify static linkage on linux (using ldd)
# Usage: $(call verify_static_linkage_linux,BINARY_PATH)
define verify_static_linkage_linux
	@if ldd "$(1)" 2>/dev/null | grep -vE "linux-vdso|ld-linux|libc\.so|libm\.so|libdl\.so|libpthread|libstdc\+\+|libgcc" | grep -q "=>"; then \
		echo ""; \
		echo "ERROR: Binary has unexpected dynamic dependencies:"; \
		ldd "$(1)" | grep -vE "linux-vdso|ld-linux|libc\.so|libm\.so|libdl\.so|libpthread|libstdc\+\+|libgcc"; \
		echo ""; \
		echo "  Fix: Ensure all codecs are built as static libraries"; \
		exit 1; \
	fi
	@printf "$(COLOR_GREEN)  [OK]$(COLOR_RESET) Static linkage verified (linux)\n"
endef

# -----------------------------------------------------------------------------
# pkg-config Name Mappings
# -----------------------------------------------------------------------------
# Some codecs have different library names vs pkg-config names.
# These variables provide the mapping for verification.

CODEC_PKGCONFIG_NAMES_bsd := vpx aom dav1d SvtAv1Enc opus ogg vorbis
CODEC_PKGCONFIG_NAMES_lgpl := $(CODEC_PKGCONFIG_NAMES_bsd) mp3lame
CODEC_PKGCONFIG_NAMES_gpl := $(CODEC_PKGCONFIG_NAMES_lgpl) x264 x265

# Active pkg-config names based on LICENSE tier
CODEC_PKGCONFIG_NAMES = $(CODEC_PKGCONFIG_NAMES_$(LICENSE))

# -----------------------------------------------------------------------------
# Phony Targets
# -----------------------------------------------------------------------------

PHONY_TARGETS += preflight

# Note: The actual preflight target is defined in each platform's Makefile
# to access platform-specific variables like BUILD_DIR, CC, CFLAGS.

# -----------------------------------------------------------------------------
# Parse-Time Version Validation
# -----------------------------------------------------------------------------
# Validate that git-cloned dependencies use immutable refs.
# This runs at Makefile parse time, before any recipes execute.
# Catches cache correctness issues early.

$(call validate_immutable_ref,X264_VERSION,x264)
