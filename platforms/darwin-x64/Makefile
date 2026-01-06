# =============================================================================
# FFmpeg Build System for macOS x86_64 (Intel)
# =============================================================================
# Main build orchestrator for darwin-x64 platform.
# Cross-compiled from ARM64 runners using -arch x86_64.
#
# Usage:
#   make              - Build everything (codecs + FFmpeg + package)
#   make codecs       - Build only codec dependencies
#   make ffmpeg       - Build FFmpeg (requires codecs)
#   make package      - Package artifacts for distribution
#   make verify       - Verify the build
#   make clean        - Remove build directory
#   make distclean    - Remove build and artifacts
#   make help         - Show this help
#
# Individual codecs:
#   make x264.stamp   - Build just x264
#   make aom.stamp    - Build just libaom
#   etc.
# =============================================================================

# Platform identification
PLATFORM := darwin-x64

# =============================================================================
# Directory Structure
# =============================================================================

ROOT_DIR := $(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))
PROJECT_ROOT := $(realpath $(ROOT_DIR)/../..)

# Build directories
BUILD_DIR := $(PROJECT_ROOT)/build/$(PLATFORM)
PREFIX := $(BUILD_DIR)/prefix
SOURCES_DIR := $(BUILD_DIR)/sources
STAMPS_DIR := $(BUILD_DIR)/stamps

# Output directories (includes license tier for separate packages)
ARTIFACTS_DIR := $(PROJECT_ROOT)/artifacts/$(PLATFORM)-$(LICENSE)

# =============================================================================
# Include Configurations
# =============================================================================

include $(PROJECT_ROOT)/shared/versions.mk
include $(PROJECT_ROOT)/shared/common.mk
include $(ROOT_DIR)/config.mk
include $(ROOT_DIR)/codecs/codec.mk

# =============================================================================
# Include Build Tools
# =============================================================================
# NASM is built from source to get an x86_64 binary that can run on ARM64
# hosts via Rosetta 2. Homebrew's ARM64 NASM fails libaom's multipass test.

include $(ROOT_DIR)/tools/nasm.mk

# =============================================================================
# Include Individual Codec Build Rules
# =============================================================================

include $(ROOT_DIR)/codecs/bsd/libvpx.mk
include $(ROOT_DIR)/codecs/bsd/aom.mk
include $(ROOT_DIR)/codecs/bsd/dav1d.mk
include $(ROOT_DIR)/codecs/bsd/svt-av1.mk
include $(ROOT_DIR)/codecs/bsd/opus.mk
include $(ROOT_DIR)/codecs/bsd/ogg.mk
include $(ROOT_DIR)/codecs/bsd/vorbis.mk

ifneq ($(LICENSE),bsd)
include $(ROOT_DIR)/codecs/lgpl/lame.mk
endif

ifeq ($(LICENSE),gpl)
include $(ROOT_DIR)/codecs/gpl/x264.mk
include $(ROOT_DIR)/codecs/gpl/x265.mk
endif

# =============================================================================
# Main Targets
# =============================================================================

.DEFAULT_GOAL := all

.PHONY: all ffmpeg package verify clean distclean help dirs

all: package verify
	$(call log_info,Build complete: $(ARTIFACTS_DIR))

dirs:
	@mkdir -p $(BUILD_DIR) $(PREFIX) $(SOURCES_DIR) $(STAMPS_DIR) $(ARTIFACTS_DIR)

# =============================================================================
# Build Tool Dependencies
# =============================================================================
# CMake-based codecs (aom, svt-av1, x265) require NASM for x86 assembly.
# The built NASM (x86_64 binary) takes precedence over Homebrew's ARM64 NASM
# because $(PREFIX)/bin is prepended to PATH in config.mk.

aom.stamp svt-av1.stamp: nasm.stamp
ifeq ($(LICENSE),gpl)
x265.stamp: nasm.stamp
endif

# =============================================================================
# FFmpeg Build
# =============================================================================

FFMPEG_SRC := $(SOURCES_DIR)/FFmpeg-$(FFMPEG_VERSION)

# -----------------------------------------------------------------------------
# FFmpeg Configure Options (by license tier)
# -----------------------------------------------------------------------------
# Cross-compile mode (--enable-cross-compile, --target-os) is REQUIRED when
# building x86_64 on ARM64 runners. Without it, FFmpeg's configure tries to
# RUN test programs to detect libraries like LAME (which doesn't use pkg-config),
# and the x86_64 test binaries fail to execute on the ARM64 host.

FFMPEG_BASE_OPTS := \
	--prefix=$(PREFIX) \
	--arch=x86_64 \
	--target-os=darwin \
	--enable-cross-compile \
	--enable-version3 \
	--enable-static \
	--disable-shared \
	--enable-pic \
	--enable-pthreads \
	--enable-videotoolbox \
	--enable-audiotoolbox \
	--disable-debug \
	--disable-doc \
	--disable-htmlpages \
	--disable-manpages \
	--disable-podpages \
	--disable-txtpages

FFMPEG_BSD_OPTS := \
	--enable-libvpx \
	--enable-libaom \
	--enable-libsvtav1 \
	--enable-libdav1d \
	--enable-libopus \
	--enable-libvorbis

FFMPEG_LGPL_OPTS := \
	--enable-libmp3lame

FFMPEG_GPL_OPTS := \
	--enable-gpl \
	--enable-libx264 \
	--enable-libx265

ifeq ($(LICENSE),bsd)
    FFMPEG_LICENSE_OPTS := $(FFMPEG_BSD_OPTS)
else ifeq ($(LICENSE),lgpl)
    FFMPEG_LICENSE_OPTS := $(FFMPEG_BSD_OPTS) $(FFMPEG_LGPL_OPTS)
else
    FFMPEG_LICENSE_OPTS := $(FFMPEG_BSD_OPTS) $(FFMPEG_LGPL_OPTS) $(FFMPEG_GPL_OPTS)
endif

FFMPEG_CONFIGURE_OPTS := $(FFMPEG_BASE_OPTS) $(FFMPEG_LICENSE_OPTS)

# -----------------------------------------------------------------------------

ffmpeg.stamp: dirs $(addsuffix .stamp,$(ACTIVE_CODECS))
	$(call log_info,Building FFmpeg $(FFMPEG_VERSION) [$(LICENSE) tier]...)
	$(call download_and_extract,ffmpeg,$(FFMPEG_URL),$(SOURCES_DIR))
	@# Create pkg-config wrapper to ensure cross-compilation uses only our built libs
	@echo '#!/bin/sh' > $(BUILD_DIR)/pkg-config-cross
	@echo 'export PKG_CONFIG_LIBDIR="$(PREFIX)/lib/pkgconfig"' >> $(BUILD_DIR)/pkg-config-cross
	@echo 'exec pkg-config "$$@"' >> $(BUILD_DIR)/pkg-config-cross
	@chmod +x $(BUILD_DIR)/pkg-config-cross
	@# Verify pkg-config can find our built codecs before FFmpeg configure
	@echo "=== Verifying pkg-config setup ==="
	@PKG_CONFIG_LIBDIR="$(PREFIX)/lib/pkgconfig" pkg-config --list-all 2>/dev/null | grep -iE "(svtav1|aom|vpx|dav1d|opus|vorbis)" || \
		(echo "WARNING: Some codec .pc files not found" && ls -la $(PREFIX)/lib/pkgconfig/ 2>/dev/null || true)
	cd $(FFMPEG_SRC) && \
		export PKG_CONFIG_LIBDIR="$(PREFIX)/lib/pkgconfig" && \
		./configure \
			--pkg-config=$(BUILD_DIR)/pkg-config-cross \
			$(FFMPEG_CONFIGURE_OPTS) \
			--pkg-config-flags="--static" \
			--extra-cflags="-I$(PREFIX)/include $(CFLAGS)" \
			--extra-ldflags="-L$(PREFIX)/lib $(LDFLAGS)" \
			--extra-libs="-lpthread -lm -lc++" && \
		$(MAKE) -j$(NPROC) && \
		$(MAKE) install
	@touch $(STAMPS_DIR)/$@

ffmpeg: ffmpeg.stamp

# =============================================================================
# Packaging
# =============================================================================

package: ffmpeg.stamp
	$(call log_info,Packaging $(LICENSE) tier artifacts to $(ARTIFACTS_DIR)...)
	@mkdir -p $(ARTIFACTS_DIR)/bin $(ARTIFACTS_DIR)/lib $(ARTIFACTS_DIR)/include
	@# Copy binaries
	@cp -a $(PREFIX)/bin/ffmpeg $(ARTIFACTS_DIR)/bin/
	@cp -a $(PREFIX)/bin/ffprobe $(ARTIFACTS_DIR)/bin/
	@# Copy static libraries
	@cp -a $(PREFIX)/lib/*.a $(ARTIFACTS_DIR)/lib/ 2>/dev/null || true
	@# Copy headers
	@cp -a $(PREFIX)/include/* $(ARTIFACTS_DIR)/include/
	@# Generate version info with license metadata
	@echo '{"ffmpeg": "$(FFMPEG_VERSION)", "platform": "$(PLATFORM)", "license": "$(LICENSE_LABEL)", "tier": "$(LICENSE)", "codecs": "$(ACTIVE_CODECS)"}' > $(ARTIFACTS_DIR)/versions.json
	$(call log_info,Artifacts packaged successfully)

# =============================================================================
# Verification
# =============================================================================
# Note: Cross-compiled binaries cannot be executed on ARM64 host.
# Verification is limited to static checks (file type, dynamic libraries).

verify: package
	$(call log_info,Verifying build...)
	@echo "=== Binary Architecture ==="
	@file $(ARTIFACTS_DIR)/bin/ffmpeg
	@file $(ARTIFACTS_DIR)/bin/ffmpeg | grep -q "x86_64" && echo "✓ x86_64 verified" || (echo "✗ Not x86_64!" && exit 1)
	@echo ""
	@echo "=== Dynamic Library Dependencies ==="
	@otool -L $(ARTIFACTS_DIR)/bin/ffmpeg
	@# Verify only expected system libs are dynamically linked (libSystem, libc++, libresolv)
	@if otool -L $(ARTIFACTS_DIR)/bin/ffmpeg | tail -n +2 | grep -vE "^\s+/usr/lib/(libSystem|libc\+\+|libresolv)" | grep -q .; then \
		echo "✗ WARNING: Unexpected dynamic libraries found"; \
	else \
		echo "✓ Static linkage verified (only system libs)"; \
	fi
	@echo ""
	@echo "=== Build Info ==="
	@echo "Platform: $(PLATFORM)"
	@echo "License tier: $(LICENSE)"
	@echo "Codecs: $(ACTIVE_CODECS)"
	@echo ""
	@echo "Note: Runtime verification skipped (cross-compiled binary)"
	$(call log_info,Verification passed)

# =============================================================================
# Cleanup
# =============================================================================

clean:
	$(call log_info,Cleaning build directory...)
	rm -rf $(BUILD_DIR)

distclean: clean
	$(call log_info,Cleaning artifacts...)
	rm -rf $(ARTIFACTS_DIR)

# =============================================================================
# Help
# =============================================================================

help:
	@echo "FFmpeg Build System for $(PLATFORM)"
	@echo ""
	@echo "Usage:"
	@echo "  make                    - Build with default (gpl) license"
	@echo "  make LICENSE=bsd        - Build BSD-only (VP8/9, AV1, Opus, Vorbis)"
	@echo "  make LICENSE=lgpl       - Build BSD + LGPL (adds MP3)"
	@echo "  make LICENSE=gpl        - Build all codecs (default)"
	@echo ""
	@echo "Current settings:"
	@echo "  LICENSE    = $(LICENSE)"
	@echo "  CODECS     = $(ACTIVE_CODECS)"
	@echo ""
	@echo "Main targets:"
	@echo "  all        - Build everything (default)"
	@echo "  codecs     - Build codec dependencies for current tier"
	@echo "  ffmpeg     - Build FFmpeg"
	@echo "  package    - Package artifacts for distribution"
	@echo "  verify     - Verify the build"
	@echo "  clean      - Remove build directory"
	@echo "  distclean  - Remove build and artifacts"
	@echo "  help       - Show this help"
	@echo ""
	@echo "Codec tiers (cumulative):"
	@echo "  bsd:  $(BSD_CODECS)"
	@echo "  lgpl: + $(LGPL_CODECS)"
	@echo "  gpl:  + $(GPL_CODECS)"
	@echo ""
	@echo "Directories:"
	@echo "  PREFIX     = $(PREFIX)"
	@echo "  BUILD_DIR  = $(BUILD_DIR)"
	@echo "  ARTIFACTS  = $(ARTIFACTS_DIR)"
	@echo ""
	@echo "Status:"
	@$(MAKE) -s LICENSE=$(LICENSE) codecs-info

# =============================================================================
# Debugging
# =============================================================================

.PHONY: pkg-config-debug
pkg-config-debug:
	@echo "=== PKG_CONFIG_LIBDIR ==="
	@echo "$(PREFIX)/lib/pkgconfig"
	@echo ""
	@echo "=== Available .pc files ==="
	@ls -la $(PREFIX)/lib/pkgconfig/ 2>/dev/null || echo "(directory not found)"
	@echo ""
	@echo "=== pkg-config --list-all ==="
	@PKG_CONFIG_LIBDIR="$(PREFIX)/lib/pkgconfig" pkg-config --list-all 2>/dev/null || echo "(pkg-config failed)"

# =============================================================================
# NPM Package
# =============================================================================

.PHONY: npm

npm: package
	$(call log_info,Populating npm package...)
	$(PROJECT_ROOT)/scripts/populate-npm.sh
