# =============================================================================
# SVT-AV1 - Fast AV1 Encoder (BSD-2-Clause + Patent License)
# =============================================================================
# Intel/Netflix's high-performance AV1 encoder.
# Uses CMake build system.
# =============================================================================

SVTAV1_SRC := $(SOURCES_DIR)/SVT-AV1-$(SVTAV1_VERSION)
SVTAV1_BUILD := $(SVTAV1_SRC)/build

svt-av1.stamp:
	$(call log_info,Building SVT-AV1 $(SVTAV1_VERSION)...)
	@mkdir -p $(SOURCES_DIR) $(STAMPS_DIR)
	$(call download_and_extract,svt-av1,$(SVTAV1_URL),$(SOURCES_DIR))
	@mkdir -p $(SVTAV1_BUILD)
	cd $(SVTAV1_BUILD) && \
		cmake $(SVTAV1_SRC) \
			$(CMAKE_OPTS) \
			-DBUILD_SHARED_LIBS=OFF \
			-DBUILD_APPS=OFF \
			-DBUILD_DEC=ON \
			-DBUILD_ENC=ON \
			-DENABLE_NASM=ON && \
		$(MAKE) -j$(NPROC) && \
		$(MAKE) install
	$(call verify_static_lib,libSvtAv1Enc,$(PREFIX))
	$(call verify_pkgconfig,SvtAv1Enc,$(PREFIX))
	@touch $(STAMPS_DIR)/$@

.PHONY: svt-av1-clean
svt-av1-clean:
	$(call clean_codec,SVT-AV1,$(SOURCES_DIR))
	rm -f $(STAMPS_DIR)/svt-av1.stamp
