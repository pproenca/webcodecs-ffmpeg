# =============================================================================
# x264 - H.264/AVC Encoder (GPL-2.0+)
# =============================================================================
# The most widely compatible video codec for web delivery.
# Uses git clone since tarballs don't include proper version info.
# =============================================================================

X264_SRC := $(SOURCES_DIR)/x264

x264.stamp:
	$(call log_info,Building x264 $(X264_VERSION)...)
	@mkdir -p $(SOURCES_DIR) $(STAMPS_DIR)
	$(call git_clone,x264,$(X264_REPO),$(X264_VERSION),$(SOURCES_DIR))
	cd $(X264_SRC) && \
		./configure \
			--host=x86_64-apple-darwin \
			--prefix=$(PREFIX) \
			--enable-static \
			--enable-pic \
			--disable-cli \
			--disable-opencl \
			--extra-cflags="$(CFLAGS)" \
			--extra-ldflags="$(LDFLAGS)" && \
		$(MAKE) -j$(NPROC) && \
		$(MAKE) install
	$(call verify_static_lib,libx264,$(PREFIX))
	$(call verify_pkgconfig,x264,$(PREFIX))
	@touch $(STAMPS_DIR)/$@

.PHONY: x264-clean
x264-clean:
	$(call clean_codec,x264,$(SOURCES_DIR))
	rm -f $(STAMPS_DIR)/x264.stamp
