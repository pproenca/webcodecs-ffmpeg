# =============================================================================
# FFmpeg Build - darwin-arm64
# =============================================================================
# Thin wrapper that includes shared infrastructure.
# Platform-specific configuration is in config.mk.
# =============================================================================

PLATFORM := darwin-arm64

# =============================================================================
# FFmpeg Configuration
# =============================================================================

# macOS SDK (set by build.sh or environment)
SDKROOT ?= $(shell xcrun --show-sdk-path 2>/dev/null)

FFMPEG_BASE_OPTS := \
	--prefix=$(PREFIX) \
	--arch=arm64 \
	--enable-cross-compile \
	--target-os=darwin \
	--enable-videotoolbox \
	--enable-audiotoolbox \
	--enable-version3 \
	--enable-static \
	--disable-shared \
	--disable-debug \
	--disable-doc \
	--disable-programs \
	--enable-ffmpeg \
	--enable-ffprobe \
	--disable-network \
	--disable-autodetect

FFMPEG_EXTRA_LIBS := -lpthread -lm -lc++

# =============================================================================
# Include Shared Platform Template
# =============================================================================

include ../../shared/platform.mk

# =============================================================================
# Platform-Specific Verification
# =============================================================================

.PHONY: verify

verify: package
	$(call log_info,Verifying darwin build...)
	@# Check FFmpeg runs
	@$(ARTIFACTS_DIR)/bin/ffmpeg -version > /dev/null
	@$(ARTIFACTS_DIR)/bin/ffprobe -version > /dev/null
	@# Verify architecture
	@file $(ARTIFACTS_DIR)/bin/ffmpeg | grep -q "arm64" || \
		(echo "ERROR: Wrong architecture" && exit 1)
	@# Check for dynamic library dependencies (should only have system libs)
	@otool -L $(ARTIFACTS_DIR)/bin/ffmpeg | grep -v "^$(ARTIFACTS_DIR)" | \
		grep -v "/usr/lib/" | grep -v "/System/" | grep -v ":" || true
	$(call log_info,Verification passed for $(PLATFORM))
