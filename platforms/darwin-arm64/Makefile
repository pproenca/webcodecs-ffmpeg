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

# Output directories
ARTIFACTS_DIR := $(PROJECT_ROOT)/artifacts/$(PLATFORM)

# =============================================================================
# Include Configurations
# =============================================================================

# Shared version definitions
include $(PROJECT_ROOT)/shared/versions.mk

# Shared utility functions
include $(PROJECT_ROOT)/shared/common.mk

# Platform-specific configuration
include $(ROOT_DIR)/config.mk

# Common codec patterns
include $(ROOT_DIR)/codecs/codec.mk

# =============================================================================
# Include Individual Codec Build Rules
# =============================================================================

# BSD-licensed codecs
include $(ROOT_DIR)/codecs/libvpx.mk
include $(ROOT_DIR)/codecs/aom.mk
include $(ROOT_DIR)/codecs/dav1d.mk
include $(ROOT_DIR)/codecs/svt-av1.mk
include $(ROOT_DIR)/codecs/opus.mk
include $(ROOT_DIR)/codecs/ogg.mk
include $(ROOT_DIR)/codecs/vorbis.mk

# LGPL-licensed codecs
include $(ROOT_DIR)/codecs/lame.mk

# GPL-licensed codecs
include $(ROOT_DIR)/codecs/x264.mk
include $(ROOT_DIR)/codecs/x265.mk

# =============================================================================
# Main Targets
# =============================================================================

.DEFAULT_GOAL := all

.PHONY: all ffmpeg package verify clean distclean help dirs

all: package verify
	$(call log_info,Build complete: $(ARTIFACTS_DIR))

# Create necessary directories
dirs:
	@mkdir -p $(BUILD_DIR) $(PREFIX) $(SOURCES_DIR) $(STAMPS_DIR) $(ARTIFACTS_DIR)

# =============================================================================
# FFmpeg Build
# =============================================================================

FFMPEG_SRC := $(SOURCES_DIR)/FFmpeg-$(patsubst n%,%,$(FFMPEG_VERSION))

ffmpeg.stamp: dirs $(addsuffix .stamp,$(ALL_CODECS))
	$(call log_info,Building FFmpeg $(FFMPEG_VERSION)...)
	$(call download_and_extract,ffmpeg,$(FFMPEG_URL),$(SOURCES_DIR))
	cd $(FFMPEG_SRC) && \
		PKG_CONFIG_PATH="$(PREFIX)/lib/pkgconfig" \
		./configure \
			--prefix=$(PREFIX) \
			--arch=arm64 \
			--enable-gpl \
			--enable-version3 \
			--enable-static \
			--disable-shared \
			--enable-pic \
			--enable-pthreads \
			--enable-videotoolbox \
			--enable-audiotoolbox \
			--enable-libx264 \
			--enable-libx265 \
			--enable-libvpx \
			--enable-libaom \
			--enable-libsvtav1 \
			--enable-libdav1d \
			--enable-libopus \
			--enable-libvorbis \
			--enable-libmp3lame \
			--disable-debug \
			--disable-doc \
			--disable-htmlpages \
			--disable-manpages \
			--disable-podpages \
			--disable-txtpages \
			--extra-cflags="-I$(PREFIX)/include $(CFLAGS)" \
			--extra-ldflags="-L$(PREFIX)/lib $(LDFLAGS)" \
			--extra-libs="-lpthread -lm" && \
		$(MAKE) -j$(NPROC) && \
		$(MAKE) install
	@touch $(STAMPS_DIR)/$@

ffmpeg: ffmpeg.stamp

# =============================================================================
# Packaging
# =============================================================================

package: ffmpeg.stamp
	$(call log_info,Packaging artifacts to $(ARTIFACTS_DIR)...)
	@mkdir -p $(ARTIFACTS_DIR)/bin $(ARTIFACTS_DIR)/lib $(ARTIFACTS_DIR)/include
	@# Copy binaries
	@cp -a $(PREFIX)/bin/ffmpeg $(ARTIFACTS_DIR)/bin/
	@cp -a $(PREFIX)/bin/ffprobe $(ARTIFACTS_DIR)/bin/
	@# Copy static libraries
	@cp -a $(PREFIX)/lib/*.a $(ARTIFACTS_DIR)/lib/ 2>/dev/null || true
	@# Copy headers
	@cp -a $(PREFIX)/include/* $(ARTIFACTS_DIR)/include/
	@# Generate version info
	@echo '{"ffmpeg": "$(FFMPEG_VERSION)", "platform": "$(PLATFORM)", "license": "GPL-2.0+"}' > $(ARTIFACTS_DIR)/versions.json
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
	@echo "Main targets:"
	@echo "  all        - Build everything (default)"
	@echo "  codecs     - Build all codec dependencies"
	@echo "  ffmpeg     - Build FFmpeg"
	@echo "  package    - Package artifacts for distribution"
	@echo "  verify     - Verify the build"
	@echo "  clean      - Remove build directory"
	@echo "  distclean  - Remove build and artifacts"
	@echo "  help       - Show this help"
	@echo ""
	@echo "Codec targets (by license):"
	@echo "  BSD:  libvpx aom dav1d svt-av1 opus ogg vorbis"
	@echo "  LGPL: lame"
	@echo "  GPL:  x264 x265"
	@echo ""
	@echo "Directories:"
	@echo "  PREFIX     = $(PREFIX)"
	@echo "  BUILD_DIR  = $(BUILD_DIR)"
	@echo "  ARTIFACTS  = $(ARTIFACTS_DIR)"
	@echo ""
	@echo "Status:"
	@$(MAKE) -s codecs-info
