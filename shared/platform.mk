# =============================================================================
# Shared Platform Makefile Template
# =============================================================================
# Include this from platform Makefiles after setting:
#   PLATFORM          - Platform identifier (e.g., darwin-arm64)
#   FFMPEG_BASE_OPTS  - Platform-specific FFmpeg configure options
#   FFMPEG_EXTRA_LIBS - Extra libraries (e.g., -lc++ for darwin, -lstdc++ for linux)
#
# Optional overrides (before including this file):
#   BSD_CODECS        - Override to exclude codecs (e.g., armv6 excludes svt-av1)
# =============================================================================

# Ensure partial builds don't appear complete
.DELETE_ON_ERROR:

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
# Include Configurations (order matters)
# =============================================================================

include $(PROJECT_ROOT)/shared/versions.mk
include $(PROJECT_ROOT)/shared/common.mk
include $(ROOT_DIR)/config.mk
include $(PROJECT_ROOT)/shared/codecs/pkgconfig.mk
include $(PROJECT_ROOT)/shared/codecs/codec.mk

# =============================================================================
# Include Shared Codec Build Rules
# =============================================================================

include $(PROJECT_ROOT)/shared/codecs/bsd/libvpx.mk
include $(PROJECT_ROOT)/shared/codecs/bsd/aom.mk
include $(PROJECT_ROOT)/shared/codecs/bsd/dav1d.mk

# Only include svt-av1 if it's in BSD_CODECS (armv6 excludes it)
ifneq ($(filter svt-av1,$(BSD_CODECS)),)
include $(PROJECT_ROOT)/shared/codecs/bsd/svt-av1.mk
endif

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

.PHONY: all ffmpeg package clean distclean help dirs codecs

all: package verify
	$(call log_info,Build complete: $(ARTIFACTS_DIR))

dirs:
	@mkdir -p $(BUILD_DIR) $(PREFIX) $(SOURCES_DIR) $(STAMPS_DIR) $(ARTIFACTS_DIR)

# =============================================================================
# FFmpeg Build
# =============================================================================

FFMPEG_SRC := $(SOURCES_DIR)/FFmpeg-$(FFMPEG_VERSION)

# Standard codec options (used by all platforms)
FFMPEG_BSD_OPTS := \
	--enable-libvpx \
	--enable-libaom \
	--enable-libdav1d \
	--enable-libopus \
	--enable-libvorbis

# Add svt-av1 if supported (not on armv6)
ifneq ($(filter svt-av1,$(BSD_CODECS)),)
FFMPEG_BSD_OPTS += --enable-libsvtav1
endif

FFMPEG_LGPL_OPTS := --enable-libmp3lame

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

# Default extra libs (can be overridden by platform)
FFMPEG_EXTRA_LIBS ?= -lpthread -lm -lstdc++

# Rebuild FFmpeg if versions.mk changes
ffmpeg.stamp: dirs $(addsuffix .stamp,$(ACTIVE_CODECS)) $(PROJECT_ROOT)/shared/versions.mk
	$(call log_info,Building FFmpeg $(FFMPEG_VERSION) [$(LICENSE) tier]...)
	$(call download_and_extract,ffmpeg,$(FFMPEG_URL),$(SOURCES_DIR))
	cd $(FFMPEG_SRC) && \
		export PKG_CONFIG_LIBDIR="$(PREFIX)/lib/pkgconfig" && \
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
	@# Copy binaries
	@cp -a $(PREFIX)/bin/ffmpeg $(ARTIFACTS_DIR)/bin/
	@cp -a $(PREFIX)/bin/ffprobe $(ARTIFACTS_DIR)/bin/
	@# Copy static libraries
	@cp -a $(PREFIX)/lib/*.a $(ARTIFACTS_DIR)/lib/ 2>/dev/null || true
	@# Copy pkg-config files for native addon development
	@mkdir -p $(ARTIFACTS_DIR)/lib/pkgconfig
	@cp -a $(PREFIX)/lib/pkgconfig/*.pc $(ARTIFACTS_DIR)/lib/pkgconfig/ 2>/dev/null || true
	@# Copy headers
	@cp -a $(PREFIX)/include/* $(ARTIFACTS_DIR)/include/
	@# Generate version info with license metadata
	@echo '{"ffmpeg": "$(FFMPEG_VERSION)", "platform": "$(PLATFORM)", "license": "$(LICENSE_LABEL)", "tier": "$(LICENSE)", "codecs": "$(ACTIVE_CODECS)"}' > $(ARTIFACTS_DIR)/versions.json
	$(call log_info,Artifacts packaged successfully)

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
