# =============================================================================
# FFmpeg Build System for Linux x86_64 (musl)
# =============================================================================
# Produces fully static binaries for Alpine Linux and scratch containers.
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
PLATFORM := linuxmusl-x64

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

# License tier (default: free for LGPL-safe codecs)
LICENSE ?= free

# Output directories
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
include $(PROJECT_ROOT)/shared/ffmpeg.mk

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

# LGPL codecs
include $(PROJECT_ROOT)/shared/codecs/lgpl/lame.mk

# GPL codecs (only in non-free tier)
ifeq ($(LICENSE),non-free)
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

preflight: dirs
	$(call verify_arch_toolchain,$(BUILD_DIR),$(CC),$(CFLAGS),$(ARCH_VERIFY_PATTERN))
	$(call verify_pkgconfig_isolation,$(PREFIX)/lib/pkgconfig)

# =============================================================================
# FFmpeg Build
# =============================================================================

FFMPEG_SRC := $(SOURCES_DIR)/FFmpeg-$(FFMPEG_VERSION)

# FFmpeg configure options for fully static musl build
FFMPEG_BASE_OPTS := \
	--prefix=$(PREFIX) \
	--arch=x86_64 \
	--pkg-config=pkg-config \
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

FFMPEG_CONFIGURE_OPTS := $(FFMPEG_BASE_OPTS) $(FFMPEG_LICENSE_OPTS)

ffmpeg.stamp: dirs $(addsuffix .stamp,$(ACTIVE_CODECS))
	$(call log_info,Building FFmpeg $(FFMPEG_VERSION) [$(LICENSE) tier - musl static]...)
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
	@echo '{"ffmpeg": "$(FFMPEG_VERSION)", "platform": "$(PLATFORM)", "license": "$(LICENSE_LABEL)", "tier": "$(LICENSE)", "codecs": "$(ACTIVE_CODECS)", "libc": "musl"}' > $(ARTIFACTS_DIR)/versions.json
	$(call log_info,Artifacts packaged successfully)

# =============================================================================
# Verification
# =============================================================================

verify: package
	$(call log_info,Verifying musl static build...)
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
	@file $(ARTIFACTS_DIR)/bin/ffmpeg | grep -q "$(ARCH_VERIFY_PATTERN)" && echo "OK x86_64 verified" || (echo "FAIL Not x86_64!" && exit 1)
	@echo ""
	@echo "=== Static Linking Verification ==="
	@file $(ARTIFACTS_DIR)/bin/ffmpeg | grep -q "statically linked" && echo "OK Fully static binary" || echo "WARN: Not fully static (may have musl dynamic deps)"
	@echo ""
	@echo "=== Dynamic Dependencies (should be empty or 'not a dynamic executable') ==="
	@ldd $(ARTIFACTS_DIR)/bin/ffmpeg 2>&1 || true
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
	@echo "FFmpeg Build System for $(PLATFORM) (musl - fully static)"
	@echo ""
	@echo "Usage:"
	@echo "  make                    - Build with default (free) license"
	@echo "  make LICENSE=free       - Build LGPL-safe codecs"
	@echo "  make LICENSE=non-free   - Build all codecs including GPL"
	@echo ""
	@echo "This platform produces FULLY STATIC binaries suitable for:"
	@echo "  - Alpine Linux"
	@echo "  - Scratch/distroless containers"
	@echo "  - Any Linux system (no glibc dependency)"
	@echo ""
	@echo "Current settings:"
	@echo "  LICENSE    = $(LICENSE)"
	@echo "  CODECS     = $(ACTIVE_CODECS)"
	@echo ""
	@echo "Directories:"
	@echo "  PREFIX     = $(PREFIX)"
	@echo "  BUILD_DIR  = $(BUILD_DIR)"
	@echo "  ARTIFACTS  = $(ARTIFACTS_DIR)"

# =============================================================================
# NPM Package
# =============================================================================

.PHONY: npm

npm: package
	$(call log_info,Populating npm package...)
	$(PROJECT_ROOT)/scripts/populate-npm.sh
