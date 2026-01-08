# =============================================================================
# Centralized Version Management for FFmpeg Build System
# =============================================================================
# This file is the single source of truth for all dependency versions.
# Grouped by license for clarity.
#
# To update: change version, update URL/SHA256, bump CACHE_VERSION
# =============================================================================

CACHE_VERSION := 1

# =============================================================================
# FFmpeg
# =============================================================================
# Security: Consider upgrading to 7.1.3+ for CVE patches (CVE-2024-7055, etc.)
# See: https://ffmpeg.org/security.html
FFMPEG_VERSION := n7.1
FFMPEG_URL := https://github.com/FFmpeg/FFmpeg/archive/refs/tags/$(FFMPEG_VERSION).tar.gz

# =============================================================================
# BSD-Licensed Codecs (Most Permissive)
# =============================================================================

LIBVPX_VERSION := v1.15.0
LIBVPX_URL := https://github.com/webmproject/libvpx/archive/refs/tags/$(LIBVPX_VERSION).tar.gz

AOM_VERSION := v3.12.0
AOM_URL := https://storage.googleapis.com/aom-releases/libaom-$(patsubst v%,%,$(AOM_VERSION)).tar.gz

DAV1D_VERSION := 1.5.0
DAV1D_URL := https://code.videolan.org/videolan/dav1d/-/archive/$(DAV1D_VERSION)/dav1d-$(DAV1D_VERSION).tar.gz

SVTAV1_VERSION := v2.3.0
SVTAV1_URL := https://gitlab.com/AOMediaCodec/SVT-AV1/-/archive/$(SVTAV1_VERSION)/SVT-AV1-$(SVTAV1_VERSION).tar.gz

OPUS_VERSION := v1.5.2
OPUS_URL := https://downloads.xiph.org/releases/opus/opus-$(patsubst v%,%,$(OPUS_VERSION)).tar.gz

OGG_VERSION := v1.3.5
OGG_URL := https://downloads.xiph.org/releases/ogg/libogg-$(patsubst v%,%,$(OGG_VERSION)).tar.gz

VORBIS_VERSION := v1.3.7
VORBIS_URL := https://downloads.xiph.org/releases/vorbis/libvorbis-$(patsubst v%,%,$(VORBIS_VERSION)).tar.gz

# =============================================================================
# LGPL-Licensed Codecs
# =============================================================================

LAME_VERSION := 3.100
LAME_URL := https://downloads.sourceforge.net/project/lame/lame/$(LAME_VERSION)/lame-$(LAME_VERSION).tar.gz

# =============================================================================
# GPL-Licensed Codecs (Strong Copyleft)
# =============================================================================

# Note: Using git clone for x264 as tarballs don't include version info properly
# Pin to commit hash for cache correctness (branch names cause stale cache hits)
X264_VERSION := b35605ace3ddf7c1a5d67a2eb553f034aef41d55
X264_REPO := https://code.videolan.org/videolan/x264.git

X265_VERSION := 4.0
X265_URL := https://bitbucket.org/multicoreware/x265_git/downloads/x265_$(X265_VERSION).tar.gz

# =============================================================================
# Build Tools (if needed)
# =============================================================================

NASM_VERSION := 2.16.03
NASM_URL := https://www.nasm.us/pub/nasm/releasebuilds/$(NASM_VERSION)/nasm-$(NASM_VERSION).tar.gz

# =============================================================================
# Parse-Time Version Validation
# =============================================================================
# Ensure git-cloned dependencies use immutable refs (commit hashes) for cache
# correctness. Branch names like "stable" cause stale cache hits.
#
# Note: This validation runs after verify.mk is included by platform Makefiles.
# We define the check here but it only executes if verify.mk is loaded.

# Defer validation until verify.mk functions are available
# This will be called by Makefiles that include both versions.mk and verify.mk
define validate_versions
$(call validate_immutable_ref,X264_VERSION,x264)
endef
