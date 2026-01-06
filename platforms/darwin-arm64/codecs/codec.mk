# =============================================================================
# Common Codec Build Patterns for darwin-arm64
# =============================================================================
# This file is included by the main Makefile and provides shared patterns
# that individual codec makefiles can use.
# =============================================================================

# Codec source and stamp directories are set by main Makefile:
#   SOURCES_DIR - where sources are downloaded/extracted
#   STAMPS_DIR  - where .stamp files are created
#   PREFIX      - installation prefix for all codecs

# =============================================================================
# Codec Categories (by license)
# =============================================================================

BSD_CODECS := libvpx aom dav1d svt-av1 opus ogg vorbis

LGPL_CODECS := lame

GPL_CODECS := x264 x265

ALL_CODECS := $(BSD_CODECS) $(LGPL_CODECS) $(GPL_CODECS)

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

AUTOCONF_DARWIN_ARGS := $(AUTOCONF_STATIC_ARGS)

# =============================================================================
# Phony Targets
# =============================================================================

.PHONY: codecs codecs-clean codecs-info

codecs: $(addsuffix .stamp,$(ALL_CODECS))

codecs-clean:
	rm -rf $(SOURCES_DIR)
	rm -f $(STAMPS_DIR)/*.stamp

codecs-info:
	@echo "=== Codec Build Status ==="
	@for codec in $(ALL_CODECS); do \
		if [ -f "$(STAMPS_DIR)/$$codec.stamp" ]; then \
			echo "[DONE] $$codec"; \
		else \
			echo "[    ] $$codec"; \
		fi; \
	done
	@echo ""
	@echo "License groups:"
	@echo "  BSD:  $(BSD_CODECS)"
	@echo "  LGPL: $(LGPL_CODECS)"
	@echo "  GPL:  $(GPL_CODECS)"
