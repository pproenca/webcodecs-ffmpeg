# =============================================================================
# pkg-config File Generation
# =============================================================================
# Macro for generating standard .pc files for codecs that don't ship one.
#
# Usage: $(call generate_pkgconfig,name,description,version,libs,libs_private,cflags)
# Example: $(call generate_pkgconfig,mp3lame,LAME MP3 encoder,3.100,-lmp3lame,-lm,)
# =============================================================================

define generate_pkgconfig
	@mkdir -p $(PREFIX)/lib/pkgconfig
	@printf '%s\n' \
		'prefix=$(PREFIX)' \
		'exec_prefix=$${prefix}' \
		'libdir=$${exec_prefix}/lib' \
		'includedir=$${prefix}/include' \
		'' \
		'Name: $(1)' \
		'Description: $(2)' \
		'Version: $(3)' \
		'Libs: -L$${libdir} $(4)' \
		'Libs.private: $(5)' \
		'Cflags: -I$${includedir} $(6)' \
		> $(PREFIX)/lib/pkgconfig/$(1).pc
endef
