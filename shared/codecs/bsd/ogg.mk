# =============================================================================
# libogg - Ogg Container Format (BSD-3-Clause)
# =============================================================================
# Required dependency for libvorbis.
# Uses autoconf build system.
# =============================================================================

OGG_SRC := $(SOURCES_DIR)/libogg-$(patsubst v%,%,$(OGG_VERSION))

ogg.stamp:
	$(call log_info,Building libogg $(OGG_VERSION)...)
	@mkdir -p $(SOURCES_DIR) $(STAMPS_DIR)
	$(call download_and_extract,ogg,$(OGG_URL),$(SOURCES_DIR))
	cd $(OGG_SRC) && \
		./configure \
			--prefix=$(PREFIX) \
			--enable-static \
			--disable-shared \
			--with-pic \
			$(if $(HOST_TRIPLET),--host=$(HOST_TRIPLET)) \
			CFLAGS="$(CFLAGS)" \
			LDFLAGS="$(LDFLAGS)" && \
		$(MAKE) -j$(NPROC) && \
		$(MAKE) install
	$(call verify_static_lib,libogg,$(PREFIX))
	$(call verify_pkgconfig,ogg,$(PREFIX))
	@touch $(STAMPS_DIR)/$@

.PHONY: ogg-clean
ogg-clean:
	$(call clean_codec,ogg,$(SOURCES_DIR))
	rm -f $(STAMPS_DIR)/ogg.stamp
