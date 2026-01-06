# =============================================================================
# libvorbis - Vorbis Audio Codec (BSD-3-Clause)
# =============================================================================
# Audio codec for WebM format.
# Depends on libogg.
# Uses autoconf build system.
# =============================================================================

VORBIS_SRC := $(SOURCES_DIR)/vorbis-$(patsubst v%,%,$(VORBIS_VERSION))

vorbis.stamp: ogg.stamp
	$(call log_info,Building libvorbis $(VORBIS_VERSION)...)
	@mkdir -p $(SOURCES_DIR) $(STAMPS_DIR)
	$(call download_and_extract,vorbis,$(VORBIS_URL),$(SOURCES_DIR))
	cd $(VORBIS_SRC) && \
		./autogen.sh && \
		./configure \
			--prefix=$(PREFIX) \
			--enable-static \
			--disable-shared \
			--disable-oggtest \
			--with-ogg=$(PREFIX) \
			--with-pic \
			CFLAGS="$(CFLAGS) -I$(PREFIX)/include" \
			LDFLAGS="$(LDFLAGS) -L$(PREFIX)/lib" \
			PKG_CONFIG_PATH="$(PREFIX)/lib/pkgconfig" && \
		$(MAKE) -j$(NPROC) && \
		$(MAKE) install
	$(call verify_static_lib,libvorbis,$(PREFIX))
	$(call verify_static_lib,libvorbisenc,$(PREFIX))
	@touch $(STAMPS_DIR)/$@

.PHONY: vorbis-clean
vorbis-clean:
	$(call clean_codec,vorbis,$(SOURCES_DIR))
	rm -f $(STAMPS_DIR)/vorbis.stamp
