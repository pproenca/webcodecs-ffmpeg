# =============================================================================
# Centralized Version Management for FFmpeg Build System
# =============================================================================
# This file is the single source of truth for all dependency versions.
# Grouped by license for clarity.
#
# To update: change version, update URL/SHA256, bump CACHE_VERSION
# =============================================================================

# Cache version - bump to invalidate CI cache when versions change
CACHE_VERSION := 1

# =============================================================================
# FFmpeg
# =============================================================================
FFMPEG_VERSION := n7.1
FFMPEG_URL := https://github.com/FFmpeg/FFmpeg/archive/refs/tags/$(FFMPEG_VERSION).tar.gz

# =============================================================================
# BSD-Licensed Codecs (Most Permissive)
# =============================================================================

# libvpx - VP8/VP9 (BSD-3-Clause)
LIBVPX_VERSION := v1.15.0
LIBVPX_URL := https://github.com/webmproject/libvpx/archive/refs/tags/$(LIBVPX_VERSION).tar.gz

# libaom - AV1 reference encoder/decoder (BSD-2-Clause)
AOM_VERSION := v3.12.0
AOM_URL := https://storage.googleapis.com/aom-releases/libaom-$(AOM_VERSION).tar.gz

# dav1d - Fast AV1 decoder (BSD-2-Clause)
DAV1D_VERSION := 1.5.0
DAV1D_URL := https://code.videolan.org/videolan/dav1d/-/archive/$(DAV1D_VERSION)/dav1d-$(DAV1D_VERSION).tar.gz

# SVT-AV1 - Fast AV1 encoder (BSD-2-Clause + Alliance for Open Media Patent License)
SVTAV1_VERSION := v2.3.0
SVTAV1_URL := https://gitlab.com/AOMediaCodec/SVT-AV1/-/archive/$(SVTAV1_VERSION)/SVT-AV1-$(SVTAV1_VERSION).tar.gz

# libopus - Opus audio codec (BSD-3-Clause)
OPUS_VERSION := v1.5.2
OPUS_URL := https://github.com/xiph/opus/archive/refs/tags/$(OPUS_VERSION).tar.gz

# libogg - Ogg container (BSD-3-Clause) - dependency for libvorbis
OGG_VERSION := v1.3.5
OGG_URL := https://github.com/xiph/ogg/archive/refs/tags/$(OGG_VERSION).tar.gz

# libvorbis - Vorbis audio codec (BSD-3-Clause)
VORBIS_VERSION := v1.3.7
VORBIS_URL := https://github.com/xiph/vorbis/archive/refs/tags/$(VORBIS_VERSION).tar.gz

# =============================================================================
# LGPL-Licensed Codecs
# =============================================================================

# libmp3lame - MP3 encoder (LGPL-2.0+)
LAME_VERSION := 3.100
LAME_URL := https://downloads.sourceforge.net/project/lame/lame/$(LAME_VERSION)/lame-$(LAME_VERSION).tar.gz

# =============================================================================
# GPL-Licensed Codecs (Strong Copyleft)
# =============================================================================

# libx264 - H.264/AVC encoder (GPL-2.0+)
# Note: Using git clone for x264 as tarballs don't include version info properly
X264_VERSION := stable
X264_REPO := https://code.videolan.org/videolan/x264.git

# libx265 - H.265/HEVC encoder (GPL-2.0+)
X265_VERSION := 4.0
X265_URL := https://bitbucket.org/multicoreware/x265_git/downloads/x265_$(X265_VERSION).tar.gz

# =============================================================================
# Build Tools (if needed)
# =============================================================================

# NASM - Assembler (BSD-2-Clause)
NASM_VERSION := 2.16.03
NASM_URL := https://www.nasm.us/pub/nasm/releasebuilds/$(NASM_VERSION)/nasm-$(NASM_VERSION).tar.gz
