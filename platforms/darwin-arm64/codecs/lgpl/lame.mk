# =============================================================================
# LAME - MP3 Encoder (LGPL-2.0+)
# =============================================================================
# The standard MP3 encoder for legacy compatibility.
# Uses autoconf build system.
# =============================================================================

LAME_SRC := $(SOURCES_DIR)/lame-$(LAME_VERSION)

lame.stamp:
	$(call log_info,Building LAME $(LAME_VERSION)...)
	@mkdir -p $(SOURCES_DIR) $(STAMPS_DIR)
	$(call download_and_extract,lame,$(LAME_URL),$(SOURCES_DIR))
	cd $(LAME_SRC) && \
		./configure \
			--prefix=$(PREFIX) \
			--enable-static \
			--disable-shared \
			--disable-frontend \
			--disable-decoder \
			--enable-nasm \
			--with-pic \
			CFLAGS="$(CFLAGS)" \
			LDFLAGS="$(LDFLAGS)" && \
		$(MAKE) -j$(NPROC) && \
		$(MAKE) install
	$(call verify_static_lib,libmp3lame,$(PREFIX))
	@# Create pkg-config file (LAME doesn't ship one)
	@mkdir -p $(PREFIX)/lib/pkgconfig
	@echo 'prefix=$(PREFIX)' > $(PREFIX)/lib/pkgconfig/mp3lame.pc
	@echo 'exec_prefix=$${prefix}' >> $(PREFIX)/lib/pkgconfig/mp3lame.pc
	@echo 'libdir=$${exec_prefix}/lib' >> $(PREFIX)/lib/pkgconfig/mp3lame.pc
	@echo 'includedir=$${prefix}/include' >> $(PREFIX)/lib/pkgconfig/mp3lame.pc
	@echo '' >> $(PREFIX)/lib/pkgconfig/mp3lame.pc
	@echo 'Name: mp3lame' >> $(PREFIX)/lib/pkgconfig/mp3lame.pc
	@echo 'Description: LAME MP3 encoder library' >> $(PREFIX)/lib/pkgconfig/mp3lame.pc
	@echo 'Version: $(LAME_VERSION)' >> $(PREFIX)/lib/pkgconfig/mp3lame.pc
	@echo 'Libs: -L$${libdir} -lmp3lame' >> $(PREFIX)/lib/pkgconfig/mp3lame.pc
	@echo 'Libs.private: -lm' >> $(PREFIX)/lib/pkgconfig/mp3lame.pc
	@echo 'Cflags: -I$${includedir}' >> $(PREFIX)/lib/pkgconfig/mp3lame.pc
	$(call verify_pkgconfig,mp3lame,$(PREFIX))
	@touch $(STAMPS_DIR)/$@

.PHONY: lame-clean
lame-clean:
	$(call clean_codec,lame,$(SOURCES_DIR))
	rm -f $(STAMPS_DIR)/lame.stamp
