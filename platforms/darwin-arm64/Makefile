# =============================================================================
# FFmpeg Build System for macOS ARM64 (Apple Silicon)
# =============================================================================
# Main build orchestrator for darwin-arm64 platform.
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
PLATFORM := darwin-arm64

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

# License tier (default: gpl for all codecs)
LICENSE ?= gpl

# Output directories (includes license tier for separate packages)
ARTIFACTS_DIR := $(PROJECT_ROOT)/artifacts/$(PLATFORM)-$(LICENSE)

# =============================================================================
# Include Configurations
# =============================================================================

include $(PROJECT_ROOT)/shared/versions.mk
include $(PROJECT_ROOT)/shared/common.mk
include $(ROOT_DIR)/config.mk
include $(PROJECT_ROOT)/shared/verify.mk
include $(PROJECT_ROOT)/shared/codecs/pkgconfig.mk
include $(PROJECT_ROOT)/shared/codecs/codec.mk

# =============================================================================
# Include Individual Codec Build Rules (from shared)
# =============================================================================

include $(PROJECT_ROOT)/shared/codecs/bsd/libvpx.mk
include $(PROJECT_ROOT)/shared/codecs/bsd/aom.mk
include $(PROJECT_ROOT)/shared/codecs/bsd/dav1d.mk
include $(PROJECT_ROOT)/shared/codecs/bsd/svt-av1.mk
include $(PROJECT_ROOT)/shared/codecs/bsd/opus.mk
include $(PROJECT_ROOT)/shared/codecs/bsd/ogg.mk
include $(PROJECT_ROOT)/shared/codecs/bsd/vorbis.mk

ifneq ($(LICENSE),bsd)
include $(PROJECT_ROOT)/shared/codecs/lgpl/lame.mk
endif

ifeq ($(LICENSE),gpl)
include $(PROJECT_ROOT)/shared/codecs/gpl/x264.mk
include $(PROJECT_ROOT)/shared/codecs/gpl/x265.mk
endif

# =============================================================================
# Main Targets
# =============================================================================

.DEFAULT_GOAL := all

.PHONY: all ffmpeg package verify clean distclean help dirs preflight

all: package verify
	$(call log_info,Build complete: $(ARTIFACTS_DIR))

dirs:
	@mkdir -p $(BUILD_DIR) $(PREFIX) $(SOURCES_DIR) $(STAMPS_DIR) $(ARTIFACTS_DIR)

# =============================================================================
# Preflight Checks
# =============================================================================
# Verify toolchain and environment before expensive builds.

preflight: dirs
	$(call verify_arch_toolchain,$(BUILD_DIR),$(CC),$(CFLAGS),$(ARCH_VERIFY_PATTERN))
	$(call verify_pkgconfig_isolation,$(PREFIX)/lib/pkgconfig)

# =============================================================================
# FFmpeg Build
# =============================================================================

FFMPEG_SRC := $(SOURCES_DIR)/FFmpeg-$(FFMPEG_VERSION)

# -----------------------------------------------------------------------------
# FFmpeg Configure Options (by license tier)
# -----------------------------------------------------------------------------

FFMPEG_BASE_OPTS := \
	--prefix=$(PREFIX) \
	--arch=arm64 \
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
	$(call verify_codecs_available,$(PREFIX)/lib/pkgconfig,$(CODEC_PKGCONFIG_NAMES))
	$(call download_and_extract,ffmpeg,$(FFMPEG_URL),$(SOURCES_DIR))
	cd $(FFMPEG_SRC) && \
		PKG_CONFIG_LIBDIR="$(PREFIX)/lib/pkgconfig" \
		./configure \
			$(FFMPEG_CONFIGURE_OPTS) \
			--pkg-config-flags="--static" \
			--extra-cflags="-I$(PREFIX)/include $(CFLAGS)" \
			--extra-ldflags="-L$(PREFIX)/lib $(LDFLAGS)" \
			--extra-libs="$(FFMPEG_EXTRA_LIBS)" && \
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
	@cp -a $(PREFIX)/bin/ffmpeg $(ARTIFACTS_DIR)/bin/
	@cp -a $(PREFIX)/bin/ffprobe $(ARTIFACTS_DIR)/bin/
	@cp -a $(PREFIX)/lib/*.a $(ARTIFACTS_DIR)/lib/ 2>/dev/null || true
	@mkdir -p $(ARTIFACTS_DIR)/lib/pkgconfig
	@cp -a $(PREFIX)/lib/pkgconfig/*.pc $(ARTIFACTS_DIR)/lib/pkgconfig/ 2>/dev/null || true
	@cp -a $(PREFIX)/include/* $(ARTIFACTS_DIR)/include/
	@echo '{"ffmpeg": "$(FFMPEG_VERSION)", "platform": "$(PLATFORM)", "license": "$(LICENSE_LABEL)", "tier": "$(LICENSE)", "codecs": "$(ACTIVE_CODECS)"}' > $(ARTIFACTS_DIR)/versions.json
	$(call log_info,Artifacts packaged successfully)

# =============================================================================
# Verification
# =============================================================================

verify: package
	$(call log_info,Verifying build...)
	@echo "=== FFmpeg Version ==="
	@$(ARTIFACTS_DIR)/bin/ffmpeg -version
	@echo ""
	@echo "=== Build Configuration ==="
	@$(ARTIFACTS_DIR)/bin/ffmpeg -buildconf 2>&1 | grep -E "(enable|configuration)" | head -20
	@echo ""
	@echo "=== Enabled Encoders (sample) ==="
	@$(ARTIFACTS_DIR)/bin/ffmpeg -encoders 2>&1 | grep -E "(libx264|libx265|libvpx|libaom|libsvtav1|libopus)" || true
	@echo ""
	@echo "=== Binary Architecture ==="
	@file $(ARTIFACTS_DIR)/bin/ffmpeg
	@file $(ARTIFACTS_DIR)/bin/ffmpeg | grep -q "arm64" && echo "✓ ARM64 verified" || (echo "✗ Not ARM64!" && exit 1)
	@echo ""
	@echo "=== Dynamic Library Dependencies ==="
	@otool -L $(ARTIFACTS_DIR)/bin/ffmpeg
	@if otool -L $(ARTIFACTS_DIR)/bin/ffmpeg | tail -n +2 | grep -vE "^\s+/usr/lib/(libSystem|libc\+\+|libresolv)" | grep -q .; then \
		echo "✗ WARNING: Unexpected dynamic libraries found"; \
	else \
		echo "✓ Static linkage verified (only system libs)"; \
	fi
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
