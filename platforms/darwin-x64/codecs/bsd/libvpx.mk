# =============================================================================
# libvpx - VP8/VP9 Encoder/Decoder (BSD-3-Clause)
# =============================================================================
# Google's VP8/VP9 codec for WebM format.
#
# Note: The target must be x86_64-darwin19-gcc (not x86_64-darwin-gcc).
# The generic x86_64-darwin-gcc target builds for iOS, which causes linking
# failures when used with macOS builds. darwin19 = macOS Catalina (10.15).
# =============================================================================

LIBVPX_SRC := $(SOURCES_DIR)/libvpx-$(patsubst v%,%,$(LIBVPX_VERSION))

libvpx.stamp:
	$(call log_info,Building libvpx $(LIBVPX_VERSION)...)
	@mkdir -p $(SOURCES_DIR) $(STAMPS_DIR)
	$(call download_and_extract,libvpx,$(LIBVPX_URL),$(SOURCES_DIR))
	cd $(LIBVPX_SRC) && \
		./configure \
			--prefix=$(PREFIX) \
			--target=x86_64-darwin19-gcc \
			--enable-static \
			--disable-shared \
			--enable-pic \
			--enable-vp8 \
			--enable-vp9 \
			--enable-vp9-highbitdepth \
			--enable-postproc \
			--enable-vp9-postproc \
			--disable-examples \
			--disable-tools \
			--disable-docs \
			--disable-unit-tests && \
		$(MAKE) -j$(NPROC) && \
		$(MAKE) install
	$(call verify_static_lib,libvpx,$(PREFIX))
	$(call verify_pkgconfig,vpx,$(PREFIX))
	@touch $(STAMPS_DIR)/$@

.PHONY: libvpx-clean
libvpx-clean:
	$(call clean_codec,libvpx,$(SOURCES_DIR))
	rm -f $(STAMPS_DIR)/libvpx.stamp
