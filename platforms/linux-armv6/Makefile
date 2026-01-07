# =============================================================================
# FFmpeg Build System for Linux ARMv6 (glibc)
# =============================================================================
# Main build orchestrator for linux-armv6 platform (Raspberry Pi Zero/1).
# Note: SVT-AV1 is excluded as it requires 64-bit architecture.
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
# =============================================================================

# Platform identification
PLATFORM := linux-armv6

# =============================================================================
# Directory Structure
# =============================================================================

ROOT_DIR := $(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))
PROJECT_ROOT := $(realpath $(ROOT_DIR)/../..)

BUILD_DIR := $(PROJECT_ROOT)/build/$(PLATFORM)
PREFIX := $(BUILD_DIR)/prefix
SOURCES_DIR := $(BUILD_DIR)/sources
STAMPS_DIR := $(BUILD_DIR)/stamps

ARTIFACTS_DIR := $(PROJECT_ROOT)/artifacts/$(PLATFORM)-$(LICENSE)

# =============================================================================
# Include Configurations
# =============================================================================

include $(PROJECT_ROOT)/shared/versions.mk
include $(PROJECT_ROOT)/shared/common.mk
include $(ROOT_DIR)/config.mk
include $(ROOT_DIR)/codecs/codec.mk

# =============================================================================
# Include Individual Codec Build Rules
# =============================================================================

# Note: SVT-AV1 is excluded - requires 64-bit architecture
include $(ROOT_DIR)/codecs/bsd/libvpx.mk
include $(ROOT_DIR)/codecs/bsd/aom.mk
include $(ROOT_DIR)/codecs/bsd/dav1d.mk
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
# FFmpeg Build
# =============================================================================

FFMPEG_SRC := $(SOURCES_DIR)/FFmpeg-$(FFMPEG_VERSION)

FFMPEG_BASE_OPTS := \
	--prefix=$(PREFIX) \
	--arch=arm \
	--cpu=armv6 \
	--enable-version3 \
	--enable-static \
	--disable-shared \
	--enable-pic \
	--enable-pthreads \
	--disable-debug \
	--disable-doc \
	--disable-htmlpages \
	--disable-manpages \
	--disable-podpages \
	--disable-txtpages

# Note: No --enable-libsvtav1 for armv6 (requires 64-bit)
FFMPEG_BSD_OPTS := \
	--enable-libvpx \
	--enable-libaom \
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

ffmpeg.stamp: dirs $(addsuffix .stamp,$(ACTIVE_CODECS))
	$(call log_info,Building FFmpeg $(FFMPEG_VERSION) [$(LICENSE) tier]...)
	$(call download_and_extract,ffmpeg,$(FFMPEG_URL),$(SOURCES_DIR))
	cd $(FFMPEG_SRC) && \
		export PKG_CONFIG_LIBDIR="$(PREFIX)/lib/pkgconfig" && \
		./configure \
			$(FFMPEG_CONFIGURE_OPTS) \
			--pkg-config-flags="--static" \
			--extra-cflags="-I$(PREFIX)/include $(CFLAGS)" \
			--extra-ldflags="-L$(PREFIX)/lib $(LDFLAGS)" \
			--extra-libs="-lpthread -lm -lstdc++" && \
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
	@$(ARTIFACTS_DIR)/bin/ffmpeg -encoders 2>&1 | grep -E "(libx264|libx265|libvpx|libaom|libopus)" || true
	@echo ""
	@echo "=== Binary Architecture ==="
	@file $(ARTIFACTS_DIR)/bin/ffmpeg
	@file $(ARTIFACTS_DIR)/bin/ffmpeg | grep -qE "(ARM|32-bit)" && echo "OK: ARM verified" || (echo "ERROR: Not ARM!" && exit 1)
	@echo ""
	@echo "=== Dynamic Library Dependencies ==="
	@ldd $(ARTIFACTS_DIR)/bin/ffmpeg || echo "(statically linked)"
	@if ldd $(ARTIFACTS_DIR)/bin/ffmpeg 2>/dev/null | grep -vE "(linux-vdso|ld-linux|libc\.so|libm\.so|libpthread|libdl|librt|libresolv|libgcc)" | grep "=>" | grep -qv "not found"; then \
		echo "WARNING: Unexpected dynamic libraries found"; \
	else \
		echo "OK: Static linkage verified (only system libs)"; \
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
	@echo "Note: SVT-AV1 is excluded on this platform (requires 64-bit)"
	@echo ""
	@echo "Current settings:"
	@echo "  LICENSE    = $(LICENSE)"
	@echo "  CODECS     = $(ACTIVE_CODECS)"
	@echo ""
	@$(MAKE) -s LICENSE=$(LICENSE) codecs-info

.PHONY: pkg-config-debug
pkg-config-debug:
	@echo "=== PKG_CONFIG_LIBDIR ==="
	@echo "$(PREFIX)/lib/pkgconfig"
	@ls -la $(PREFIX)/lib/pkgconfig/ 2>/dev/null || echo "(directory not found)"

.PHONY: npm
npm: package
	$(call log_info,Populating npm package...)
	$(PROJECT_ROOT)/scripts/populate-npm.sh
