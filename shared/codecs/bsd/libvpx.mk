# =============================================================================
# libvpx - VP8/VP9 Encoder/Decoder (BSD-3-Clause)
# =============================================================================
# Google's VP8/VP9 codec for WebM format.
#
# Platform-specific configuration:
#   LIBVPX_TARGET     - Required. Target triplet (e.g., arm64-darwin23-gcc,
#                       x86_64-linux-gcc, generic-gnu)
#   LIBVPX_EXTRA_OPTS - Optional. Additional configure flags
#
# Note for macOS: Use arm64-darwin23-gcc (not arm64-darwin-gcc).
# The generic arm64-darwin-gcc target builds for iOS, which causes linking
# failures when used with macOS builds. darwin23 = macOS Sonoma (14.x).
# =============================================================================

ifndef LIBVPX_TARGET
$(error LIBVPX_TARGET must be defined (e.g., arm64-darwin23-gcc, x86_64-linux-gcc))
endif

LIBVPX_SRC := $(SOURCES_DIR)/libvpx-$(patsubst v%,%,$(LIBVPX_VERSION))

libvpx.stamp:
	$(call log_info,Building libvpx $(LIBVPX_VERSION)...)
	@mkdir -p $(SOURCES_DIR) $(STAMPS_DIR)
	$(call download_and_extract,libvpx,$(LIBVPX_URL),$(SOURCES_DIR))
	cd $(LIBVPX_SRC) && \
		./configure \
			--prefix=$(PREFIX) \
			--target=$(LIBVPX_TARGET) \
			$(LIBVPX_EXTRA_OPTS) \
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
