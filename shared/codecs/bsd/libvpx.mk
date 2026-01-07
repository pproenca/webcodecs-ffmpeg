# =============================================================================
# libvpx - VP8/VP9 Encoder/Decoder (BSD-3-Clause)
# =============================================================================
# Google's VP8/VP9 codec for WebM format.
#
# Note: The target must match the platform (e.g., arm64-darwin23-gcc for
# macOS ARM64, x86_64-darwin-gcc for macOS Intel). The generic arm64-darwin-gcc
# target builds for iOS, which causes linking failures with macOS builds.
# =============================================================================

LIBVPX_SRC := $(SOURCES_DIR)/libvpx-$(patsubst v%,%,$(LIBVPX_VERSION))

ifndef LIBVPX_TARGET
    $(error LIBVPX_TARGET must be defined in config.mk)
endif

libvpx.stamp:
	$(call log_info,Building libvpx $(LIBVPX_VERSION)...)
	@mkdir -p $(SOURCES_DIR) $(STAMPS_DIR)
	$(call download_and_extract,libvpx,$(LIBVPX_URL),$(SOURCES_DIR))
	cd $(LIBVPX_SRC) && \
		./configure \
			--prefix=$(PREFIX) \
			--target=$(LIBVPX_TARGET) \
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
