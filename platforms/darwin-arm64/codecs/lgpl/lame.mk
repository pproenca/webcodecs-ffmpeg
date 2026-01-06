# =============================================================================
# LAME - MP3 Encoder (LGPL-2.0+)
# =============================================================================
# The standard MP3 encoder for legacy compatibility.
# Uses autoconf build system.
# =============================================================================

LAME_SRC := $(SOURCES_DIR)/lame-$(LAME_VERSION)

lame.stamp:
	$(call log_info,Building LAME $(LAME_VERSION)...)
	@mkdir -p $(SOURCES_DIR) $(STAMPS_DIR)
	$(call download_and_extract,lame,$(LAME_URL),$(SOURCES_DIR))
	cd $(LAME_SRC) && \
		./configure \
			--prefix=$(PREFIX) \
			--enable-static \
			--disable-shared \
			--disable-frontend \
			--disable-decoder \
			--enable-nasm \
			--with-pic \
			CFLAGS="$(CFLAGS)" \
			LDFLAGS="$(LDFLAGS)" && \
		$(MAKE) -j$(NPROC) && \
		$(MAKE) install
	$(call verify_static_lib,libmp3lame,$(PREFIX))
	@touch $(STAMPS_DIR)/$@

.PHONY: lame-clean
lame-clean:
	$(call clean_codec,lame,$(SOURCES_DIR))
	rm -f $(STAMPS_DIR)/lame.stamp
