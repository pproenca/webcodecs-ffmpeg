# =============================================================================
# Common Codec Build Patterns for linux-arm64v8
# =============================================================================

LICENSE ?= gpl

ifeq ($(filter $(LICENSE),bsd lgpl gpl),)
    $(error Invalid LICENSE=$(LICENSE). Must be one of: bsd, lgpl, gpl)
endif

BSD_CODECS := libvpx aom dav1d svt-av1 opus ogg vorbis
LGPL_CODECS := lame
GPL_CODECS := x264 x265
ALL_CODECS := $(BSD_CODECS) $(LGPL_CODECS) $(GPL_CODECS)

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

PARALLEL_CODECS := libvpx aom dav1d svt-av1 opus ogg lame x264 x265

AUTOCONF_STATIC_ARGS := \
    --prefix=$(PREFIX) \
    --enable-static \
    --disable-shared \
    --with-pic

AUTOCONF_LINUX_ARGS := $(AUTOCONF_STATIC_ARGS)

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
