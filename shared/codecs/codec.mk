# =============================================================================
# Common Codec Build Patterns
# =============================================================================
# This file is included by the main Makefile and provides shared patterns
# that individual codec makefiles can use.
# =============================================================================

# Codec source and stamp directories are set by main Makefile:
#   SOURCES_DIR - where sources are downloaded/extracted
#   STAMPS_DIR  - where .stamp files are created
#   PREFIX      - installation prefix for all codecs

# =============================================================================
# License Tier Configuration
# =============================================================================
# LICENSE controls which codecs are built:
#   LICENSE=free      - LGPL-safe codecs (VP8/9, AV1, Opus, Vorbis, MP3)
#   LICENSE=non-free  - All codecs including GPL x264/x265 (requires --enable-gpl)
#
# Backwards compatibility (deprecated, will be removed):
#   LICENSE=bsd   → mapped to 'free'
#   LICENSE=lgpl  → mapped to 'free'
#   LICENSE=gpl   → mapped to 'non-free'
# =============================================================================

LICENSE ?= free

# Backwards compatibility: map old values to new
ifeq ($(LICENSE),bsd)
    $(warning DEPRECATION: LICENSE=bsd is deprecated. Use LICENSE=free instead.)
    override LICENSE := free
else ifeq ($(LICENSE),lgpl)
    $(warning DEPRECATION: LICENSE=lgpl is deprecated. Use LICENSE=free instead.)
    override LICENSE := free
else ifeq ($(LICENSE),gpl)
    $(warning DEPRECATION: LICENSE=gpl is deprecated. Use LICENSE=non-free instead.)
    override LICENSE := non-free
endif

# Validate LICENSE value
ifeq ($(filter $(LICENSE),free non-free),)
    $(error Invalid LICENSE=$(LICENSE). Must be one of: free, non-free)
endif

# =============================================================================
# Codec Categories (by license compatibility)
# =============================================================================

# LGPL-safe codecs (can be used in proprietary software with LGPL compliance)
FREE_CODECS := libvpx aom dav1d svt-av1 opus ogg vorbis lame

# GPL codecs (require full source disclosure if linked)
GPL_CODECS := x264 x265

ALL_CODECS := $(FREE_CODECS) $(GPL_CODECS)

# =============================================================================
# Active Codecs (based on LICENSE tier)
# =============================================================================

ifeq ($(LICENSE),free)
    ACTIVE_CODECS := $(FREE_CODECS)
    LICENSE_LABEL := LGPL-2.1+
else
    ACTIVE_CODECS := $(ALL_CODECS)
    LICENSE_LABEL := GPL-2.0+
endif

# =============================================================================
# Dependency Graph
# =============================================================================
# Most codecs have no inter-dependencies and can build in parallel.
# Exception: vorbis depends on ogg (defined in vorbis.mk)

# =============================================================================
# Common Configure Arguments
# =============================================================================

AUTOCONF_STATIC_ARGS := \
    --prefix=$(PREFIX) \
    --enable-static \
    --disable-shared \
    --with-pic

# =============================================================================
# Phony Targets
# =============================================================================

.PHONY: codecs codecs-clean codecs-info

codecs: $(addsuffix .stamp,$(ACTIVE_CODECS))

codecs-clean:
	rm -rf $(SOURCES_DIR)
	rm -f $(STAMPS_DIR)/*.stamp

codecs-info:
	@echo "=== Codec Build Status (LICENSE=$(LICENSE)) ==="
	@for codec in $(ACTIVE_CODECS); do \
		if [ -f "$(STAMPS_DIR)/$$codec.stamp" ]; then \
			echo "[DONE] $$codec"; \
		else \
			echo "[    ] $$codec"; \
		fi; \
	done
	@echo ""
	@echo "Active codecs for $(LICENSE) tier: $(ACTIVE_CODECS)"
	@echo ""
	@echo "License tiers:"
	@echo "  free:     $(FREE_CODECS)"
	@echo "  non-free: + $(GPL_CODECS)"
