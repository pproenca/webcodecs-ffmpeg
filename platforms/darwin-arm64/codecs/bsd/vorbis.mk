# =============================================================================
# libvorbis - Vorbis Audio Codec (BSD-3-Clause)
# =============================================================================
# Audio codec for WebM format.
# Depends on libogg.
# Uses autoconf build system.
#
# Note: libvorbis 1.3.7 hardcodes -force_cpusubtype_ALL for darwin targets
# in both the configure script (CFLAGS) and libtool. This flag is PowerPC-only
# and rejected by Xcode 15+ linkers. We patch both before/after configure.
# See: https://github.com/xiph/vorbis/issues/107
# =============================================================================

VORBIS_SRC := $(SOURCES_DIR)/libvorbis-$(patsubst v%,%,$(VORBIS_VERSION))

vorbis.stamp: ogg.stamp
	$(call log_info,Building libvorbis $(VORBIS_VERSION)...)
	@mkdir -p $(SOURCES_DIR) $(STAMPS_DIR)
	$(call download_and_extract,vorbis,$(VORBIS_URL),$(SOURCES_DIR))
	cd $(VORBIS_SRC) && \
		sed -i '' 's/-force_cpusubtype_ALL//g' configure && \
		./configure \
			--prefix=$(PREFIX) \
			--enable-static \
			--disable-shared \
			--disable-oggtest \
			--disable-examples \
			--disable-docs \
			--with-ogg=$(PREFIX) \
			--with-pic \
			CFLAGS="$(CFLAGS) -I$(PREFIX)/include" \
			LDFLAGS="$(LDFLAGS) -L$(PREFIX)/lib" && \
		sed -i '' 's/-force_cpusubtype_ALL//g' libtool && \
		$(MAKE) -j$(NPROC) && \
		$(MAKE) install
	$(call verify_static_lib,libvorbis,$(PREFIX))
	$(call verify_static_lib,libvorbisenc,$(PREFIX))
	$(call verify_pkgconfig,vorbis,$(PREFIX))
	@touch $(STAMPS_DIR)/$@

.PHONY: vorbis-clean
vorbis-clean:
	$(call clean_codec,vorbis,$(SOURCES_DIR))
	rm -f $(STAMPS_DIR)/vorbis.stamp
