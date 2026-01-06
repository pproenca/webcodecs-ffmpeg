# =============================================================================
# libaom - AV1 Reference Encoder/Decoder (BSD-2-Clause)
# =============================================================================
# Alliance for Open Media's reference AV1 implementation.
# Uses CMake build system.
# =============================================================================

AOM_SRC := $(SOURCES_DIR)/libaom-$(patsubst v%,%,$(AOM_VERSION))
AOM_BUILD := $(AOM_SRC)/build

aom.stamp:
	$(call log_info,Building libaom $(AOM_VERSION)...)
	@mkdir -p $(SOURCES_DIR) $(STAMPS_DIR)
	$(call download_and_extract,aom,$(AOM_URL),$(SOURCES_DIR))
	@mkdir -p $(AOM_BUILD)
	cd $(AOM_BUILD) && \
		cmake $(AOM_SRC) \
			$(CMAKE_OPTS) \
			-DBUILD_SHARED_LIBS=OFF \
			-DENABLE_DOCS=OFF \
			-DENABLE_EXAMPLES=OFF \
			-DENABLE_TESTDATA=OFF \
			-DENABLE_TESTS=OFF \
			-DENABLE_TOOLS=OFF \
			-DCONFIG_AV1_HIGHBITDEPTH=1 && \
		$(MAKE) -j$(NPROC) && \
		$(MAKE) install
	$(call verify_static_lib,libaom,$(PREFIX))
	$(call verify_pkgconfig,aom,$(PREFIX))
	@touch $(STAMPS_DIR)/$@

.PHONY: aom-clean
aom-clean:
	$(call clean_codec,aom,$(SOURCES_DIR))
	rm -f $(STAMPS_DIR)/aom.stamp
