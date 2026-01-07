# =============================================================================
# Codec Build Configuration - linux-armv6
# =============================================================================
# Defines codec tiers and common build patterns for ARMv6 platform.
# Note: SVT-AV1 is excluded as it requires 64-bit architecture.
#
# License tiers (cumulative):
#   bsd  - Open source, permissive (VP8/9, AV1, Opus, Vorbis)
#   lgpl - Adds MP3 encoding
#   gpl  - Adds H.264/H.265 encoding
# =============================================================================

# -----------------------------------------------------------------------------
# License Tier Definitions
# -----------------------------------------------------------------------------

# BSD-licensed codecs (no SVT-AV1 on armv6)
BSD_CODECS := libvpx aom dav1d opus ogg vorbis

# LGPL-licensed codecs
LGPL_CODECS := lame

# GPL-licensed codecs
GPL_CODECS := x264 x265

# -----------------------------------------------------------------------------
# Active Codec Selection
# -----------------------------------------------------------------------------

# Default to GPL (most complete)
LICENSE ?= gpl

# Map LICENSE_TIER env var to LICENSE make var
ifdef LICENSE_TIER
    LICENSE := $(LICENSE_TIER)
endif

# Build codec list based on license tier
ifeq ($(LICENSE),bsd)
    ACTIVE_CODECS := $(BSD_CODECS)
    LICENSE_LABEL := BSD-3-Clause
else ifeq ($(LICENSE),lgpl)
    ACTIVE_CODECS := $(BSD_CODECS) $(LGPL_CODECS)
    LICENSE_LABEL := LGPL-2.1+
else ifeq ($(LICENSE),gpl)
    ACTIVE_CODECS := $(BSD_CODECS) $(LGPL_CODECS) $(GPL_CODECS)
    LICENSE_LABEL := GPL-2.0+
else
    $(error Unknown LICENSE tier: $(LICENSE). Use bsd, lgpl, or gpl)
endif

# -----------------------------------------------------------------------------
# Codec Stamp Files
# -----------------------------------------------------------------------------

CODEC_STAMPS := $(addsuffix .stamp,$(ACTIVE_CODECS))

# -----------------------------------------------------------------------------
# Common Targets
# -----------------------------------------------------------------------------

.PHONY: codecs codecs-info codecs-clean

codecs: $(CODEC_STAMPS)
	$(call log_info,All $(LICENSE) tier codecs built successfully)

codecs-info:
	@echo "=== Codec Build Status ($(LICENSE) tier) ==="
	@echo "License: $(LICENSE_LABEL)"
	@echo "Note: SVT-AV1 excluded (requires 64-bit)"
	@echo ""
	@for codec in $(ACTIVE_CODECS); do \
		if [ -f "$(STAMPS_DIR)/$$codec.stamp" ]; then \
			echo "  [✓] $$codec"; \
		else \
			echo "  [ ] $$codec"; \
		fi; \
	done
	@echo ""
	@echo "Stamps directory: $(STAMPS_DIR)"

codecs-clean:
	$(call log_info,Cleaning codec sources and stamps...)
	@for codec in $(BSD_CODECS) $(LGPL_CODECS) $(GPL_CODECS); do \
		rm -rf $(SOURCES_DIR)/$$codec* 2>/dev/null || true; \
		rm -f $(STAMPS_DIR)/$$codec.stamp 2>/dev/null || true; \
	done
