# =============================================================================
# dav1d - Fast AV1 Decoder (BSD-2-Clause)
# =============================================================================
# VideoLAN's optimized AV1 decoder - much faster than libaom for decoding.
# Uses Meson build system.
# =============================================================================

DAV1D_SRC := $(SOURCES_DIR)/dav1d-$(DAV1D_VERSION)
DAV1D_BUILD := $(DAV1D_SRC)/build

dav1d.stamp:
	$(call log_info,Building dav1d $(DAV1D_VERSION)...)
	@mkdir -p $(SOURCES_DIR) $(STAMPS_DIR)
	$(call download_and_extract,dav1d,$(DAV1D_URL),$(SOURCES_DIR))
	cd $(DAV1D_SRC) && \
		meson setup $(DAV1D_BUILD) \
			$(MESON_OPTS) \
			-Denable_tools=false \
			-Denable_tests=false \
			-Denable_examples=false && \
		ninja -C $(DAV1D_BUILD) && \
		ninja -C $(DAV1D_BUILD) install
	$(call verify_static_lib,libdav1d,$(PREFIX))
	@touch $(STAMPS_DIR)/$@

.PHONY: dav1d-clean
dav1d-clean:
	$(call clean_codec,dav1d,$(SOURCES_DIR))
	rm -f $(STAMPS_DIR)/dav1d.stamp
