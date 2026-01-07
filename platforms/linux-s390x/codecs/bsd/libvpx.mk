# =============================================================================
# libvpx - VP8/VP9 Video Codec (BSD-3-Clause)
# =============================================================================
# WebM video codec, essential for web video compatibility.
# Uses custom configure script (not autoconf).
# Note: Using generic-gnu target for s390x (no optimized target available)
# =============================================================================

VPX_SRC := $(SOURCES_DIR)/libvpx-$(patsubst v%,%,$(VPX_VERSION))

libvpx.stamp:
	$(call log_info,Building libvpx $(VPX_VERSION)...)
	@mkdir -p $(SOURCES_DIR) $(STAMPS_DIR)
	$(call download_and_extract,vpx,$(VPX_URL),$(SOURCES_DIR))
	cd $(VPX_SRC) && \
		./configure \
			--prefix=$(PREFIX) \
			--target=generic-gnu \
			--enable-static \
			--disable-shared \
			--enable-pic \
			--disable-examples \
			--disable-tools \
			--disable-docs \
			--disable-unit-tests \
			--enable-vp8 \
			--enable-vp9 \
			--enable-vp9-highbitdepth \
			--extra-cflags="$(CFLAGS)" \
			--extra-cxxflags="$(CXXFLAGS)" && \
		$(MAKE) -j$(NPROC) && \
		$(MAKE) install
	$(call verify_static_lib,libvpx,$(PREFIX))
	$(call verify_pkgconfig,vpx,$(PREFIX))
	@touch $(STAMPS_DIR)/$@

.PHONY: libvpx-clean
libvpx-clean:
	$(call clean_codec,libvpx,$(SOURCES_DIR))
	rm -f $(STAMPS_DIR)/libvpx.stamp
