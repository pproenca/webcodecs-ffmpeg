# =============================================================================
# NASM - Netwide Assembler (BSD-2-Clause)
# =============================================================================
# Built from source for x86_64 architecture to support cross-compilation
# on ARM64 hosts. Homebrew's ARM64 NASM fails libaom's multipass tests.
#
# NASM is an x86/x86_64 assembler that outputs object files for Intel/AMD
# architectures. When building on ARM64 macOS, the x86_64 NASM binary runs
# via Rosetta 2 translation.
# =============================================================================

NASM_SRC := $(SOURCES_DIR)/nasm-$(NASM_VERSION)

nasm.stamp: dirs
	$(call log_info,Building NASM $(NASM_VERSION) for x86_64...)
	@mkdir -p $(SOURCES_DIR) $(STAMPS_DIR)
	$(call download_and_extract,nasm,$(NASM_URL),$(SOURCES_DIR))
	cd $(NASM_SRC) && \
		./configure \
			--prefix=$(PREFIX) \
			CC="$(CC)" \
			CFLAGS="$(CFLAGS)" \
			LDFLAGS="$(LDFLAGS)" && \
		$(MAKE) -j$(NPROC) && \
		$(MAKE) install
	@# Verify NASM binary is x86_64 architecture
	@file $(PREFIX)/bin/nasm | grep -q "x86_64" && \
		$(call log_info,NASM x86_64 binary verified: $$($(PREFIX)/bin/nasm --version | head -1)) || \
		(echo "[ERROR] NASM is not x86_64 architecture!" && exit 1)
	@touch $(STAMPS_DIR)/$@

.PHONY: nasm-clean
nasm-clean:
	$(call clean_codec,nasm,$(SOURCES_DIR))
	rm -f $(STAMPS_DIR)/nasm.stamp
