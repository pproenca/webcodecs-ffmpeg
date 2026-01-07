# =============================================================================
# Common Codec Build Patterns for linux-s390x
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
#   LICENSE=bsd   - Only BSD codecs (VP8/9, AV1, Opus, Vorbis)
#   LICENSE=lgpl  - BSD + LGPL codecs (adds MP3)
#   LICENSE=gpl   - All codecs including x264/x265 (default)
# =============================================================================

LICENSE ?= gpl

ifeq ($(filter $(LICENSE),bsd lgpl gpl),)
    $(error Invalid LICENSE=$(LICENSE). Must be one of: bsd, lgpl, gpl)
endif

# =============================================================================
# Codec Categories (by license)
# =============================================================================

BSD_CODECS := libvpx aom dav1d svt-av1 opus ogg vorbis

LGPL_CODECS := lame

GPL_CODECS := x264 x265

ALL_CODECS := $(BSD_CODECS) $(LGPL_CODECS) $(GPL_CODECS)

# =============================================================================
# Active Codecs (based on LICENSE tier)
# =============================================================================

ifeq ($(LICENSE),bsd)
    ACTIVE_CODECS := $(BSD_CODECS)
    LICENSE_LABEL := BSD
else ifeq ($(LICENSE),lgpl)
    ACTIVE_CODECS := $(BSD_CODECS) $(LGPL_CODECS)
    LICENSE_LABEL := LGPL-2.0+
else
    ACTIVE_CODECS := $(ALL_CODECS)
    LICENSE_LABEL := GPL-2.0+
endif

# =============================================================================
# Dependency Graph
# =============================================================================
# Most codecs have no inter-dependencies and can build in parallel.
# Exception: vorbis depends on ogg

PARALLEL_CODECS := libvpx aom dav1d svt-av1 opus ogg lame x264 x265

# Codecs with dependencies (must wait)
# vorbis.stamp depends on ogg.stamp (defined in vorbis.mk)

# =============================================================================
# Common Configure Arguments
# =============================================================================

AUTOCONF_STATIC_ARGS := \
    --prefix=$(PREFIX) \
    --enable-static \
    --disable-shared \
    --with-pic

AUTOCONF_LINUX_ARGS := $(AUTOCONF_STATIC_ARGS)

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
	@echo "All license tiers:"
	@echo "  bsd:  $(BSD_CODECS)"
	@echo "  lgpl: + $(LGPL_CODECS)"
	@echo "  gpl:  + $(GPL_CODECS)"
