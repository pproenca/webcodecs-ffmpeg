# =============================================================================
# FFmpeg Build - linux-arm64v8
# =============================================================================
# Thin wrapper that includes shared infrastructure.
# Platform-specific configuration is in config.mk.
# =============================================================================

PLATFORM := linux-arm64v8

# =============================================================================
# FFmpeg Configuration
# =============================================================================

FFMPEG_BASE_OPTS := \
	--prefix=$(PREFIX) \
	--arch=aarch64 \
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

FFMPEG_EXTRA_LIBS := -lpthread -lm -lstdc++

# =============================================================================
# Include Shared Platform Template
# =============================================================================

include ../../shared/platform.mk

# =============================================================================
# Platform-Specific Verification
# =============================================================================

.PHONY: verify

verify: package
	$(call log_info,Verifying Linux build...)
	@# Check FFmpeg runs
	@$(ARTIFACTS_DIR)/bin/ffmpeg -version > /dev/null
	@$(ARTIFACTS_DIR)/bin/ffprobe -version > /dev/null
	@# Verify architecture
	@file $(ARTIFACTS_DIR)/bin/ffmpeg | grep -q "aarch64" || \
		(echo "ERROR: Wrong architecture" && exit 1)
	@# Check for dynamic library dependencies (should be minimal)
	@echo "Dynamic dependencies:"
	@ldd $(ARTIFACTS_DIR)/bin/ffmpeg 2>/dev/null || echo "(statically linked)"
	$(call log_info,Verification passed for $(PLATFORM))
