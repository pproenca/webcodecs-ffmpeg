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

# BSD-licensed codecs (most permissive)
BSD_CODECS := libvpx aom dav1d svt-av1 opus ogg vorbis

# LGPL-licensed codecs
LGPL_CODECS := lame

# GPL-licensed codecs (strong copyleft)
GPL_CODECS := x264 x265

# All codecs
ALL_CODECS := $(BSD_CODECS) $(LGPL_CODECS) $(GPL_CODECS)

# =============================================================================
# Dependency Graph
# =============================================================================
# Most codecs have no inter-dependencies and can build in parallel.
# Exception: vorbis depends on ogg

# Codecs with no dependencies (parallel group)
PARALLEL_CODECS := libvpx aom dav1d svt-av1 opus ogg lame x264 x265

# Codecs with dependencies (must wait)
# vorbis.stamp depends on ogg.stamp (defined in vorbis.mk)

# =============================================================================
# Common Configure Arguments
# =============================================================================

# Standard autoconf args for static builds
AUTOCONF_STATIC_ARGS := \
    --prefix=$(PREFIX) \
    --enable-static \
    --disable-shared \
    --with-pic

# Add extra flags for cross-compilation awareness
AUTOCONF_DARWIN_ARGS := $(AUTOCONF_STATIC_ARGS)

# =============================================================================
# Phony Targets
# =============================================================================

.PHONY: codecs codecs-clean codecs-info

# Build all codecs
codecs: $(addsuffix .stamp,$(ALL_CODECS))

# Clean all codec builds
codecs-clean:
	rm -rf $(SOURCES_DIR)
	rm -f $(STAMPS_DIR)/*.stamp

# Show codec build status
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
