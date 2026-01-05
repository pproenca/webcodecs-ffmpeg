# =============================================================================
# libopus - Opus Audio Codec (BSD-3-Clause)
# =============================================================================
# The primary audio codec for WebRTC and modern web audio.
# Uses autoconf build system.
# =============================================================================

OPUS_SRC := $(SOURCES_DIR)/opus-$(patsubst v%,%,$(OPUS_VERSION))

opus.stamp:
	$(call log_info,Building opus $(OPUS_VERSION)...)
	@mkdir -p $(SOURCES_DIR) $(STAMPS_DIR)
	$(call download_and_extract,opus,$(OPUS_URL),$(SOURCES_DIR))
	cd $(OPUS_SRC) && \
		./autogen.sh && \
		./configure \
			--prefix=$(PREFIX) \
			--enable-static \
			--disable-shared \
			--disable-doc \
			--disable-extra-programs \
			CFLAGS="$(CFLAGS)" \
			LDFLAGS="$(LDFLAGS)" && \
		$(MAKE) -j$(NPROC) && \
		$(MAKE) install
	$(call verify_static_lib,libopus,$(PREFIX))
	@touch $(STAMPS_DIR)/$@

.PHONY: opus-clean
opus-clean:
	$(call clean_codec,opus,$(SOURCES_DIR))
	rm -f $(STAMPS_DIR)/opus.stamp
