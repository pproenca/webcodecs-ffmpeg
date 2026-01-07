# =============================================================================
# x265 - H.265/HEVC Encoder (GPL-2.0+)
# =============================================================================
# High Efficiency Video Coding - better compression than H.264.
# Uses CMake build system.
# =============================================================================

X265_SRC := $(SOURCES_DIR)/x265_$(X265_VERSION)
X265_BUILD := $(X265_SRC)/build/arm-linux

x265.stamp:
	$(call log_info,Building x265 $(X265_VERSION)...)
	@mkdir -p $(SOURCES_DIR) $(STAMPS_DIR)
	$(call download_and_extract,x265,$(X265_URL),$(SOURCES_DIR))
	@mkdir -p $(X265_BUILD)
	cd $(X265_BUILD) && \
		cmake $(X265_SRC)/source \
			$(CMAKE_OPTS) \
			-DENABLE_SHARED=OFF \
			-DENABLE_CLI=OFF \
			-DENABLE_LIBNUMA=OFF \
			-DHIGH_BIT_DEPTH=OFF \
			-DENABLE_ASSEMBLY=OFF && \
		$(MAKE) -j$(NPROC) && \
		$(MAKE) install
	$(call verify_static_lib,libx265,$(PREFIX))
	$(call verify_pkgconfig,x265,$(PREFIX))
	@touch $(STAMPS_DIR)/$@

.PHONY: x265-clean
x265-clean:
	$(call clean_codec,x265,$(SOURCES_DIR))
	rm -f $(STAMPS_DIR)/x265.stamp
