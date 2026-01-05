#!/usr/bin/env bash
# macOS FFmpeg Build Versions
# Single source of truth for all darwin builds

# Core FFmpeg
FFMPEG_VERSION=n8.0.1
FFMPEG_GIT_URL=https://git.ffmpeg.org/ffmpeg.git

# Video Codecs
X264_VERSION=stable
X264_GIT_URL=https://code.videolan.org/videolan/x264.git

X265_VERSION=4.1
X265_GIT_URL=https://bitbucket.org/multicoreware/x265_git.git

LIBVPX_VERSION=v1.15.2
LIBVPX_GIT_URL=https://chromium.googlesource.com/webm/libvpx.git

LIBAOM_VERSION=v3.13.1
LIBAOM_GIT_URL=https://aomedia.googlesource.com/aom

SVTAV1_VERSION=v3.1.2
SVTAV1_GIT_URL=https://gitlab.com/AOMediaCodec/SVT-AV1.git

DAV1D_VERSION=1.5.3
DAV1D_URL=https://downloads.videolan.org/pub/videolan/dav1d/1.5.3/dav1d-1.5.3.tar.xz
DAV1D_SHA256=732010aa5ef461fa93355ed2c6c5fedb48ddc4b74e697eaabe8907eaeb943011

THEORA_VERSION=1.2.0
THEORA_URL=https://ftp.osuosl.org/pub/xiph/releases/theora/libtheora-1.2.0.tar.gz
THEORA_SHA256=279327339903b544c28a92aeada7d0dcfd0397b59c2f368cc698ac56f515906e

XVID_VERSION=1.3.7
XVID_URL=https://downloads.xvid.com/downloads/xvidcore-1.3.7.tar.gz
XVID_SHA256=abbdcbd39555691dd1c9b4d08f0a031376a3b211652c0d8b3b8aa9be1303ce2d

# Audio Codecs
OPUS_VERSION=1.6
OPUS_URL=https://downloads.xiph.org/releases/opus/opus-1.6.tar.gz
OPUS_SHA256=b7637334527201fdfd6dd6a02e67aceffb0e5e60155bbd89175647a80301c92c

LAME_VERSION=3.100
LAME_URL=https://downloads.sourceforge.net/project/lame/lame/3.100/lame-3.100.tar.gz
LAME_SHA256=ddfe36cab873794038ae2c1210557ad34857a4b6bdc515785d1da9e175b1da1e

VORBIS_VERSION=1.3.7
VORBIS_URL=https://ftp.osuosl.org/pub/xiph/releases/vorbis/libvorbis-1.3.7.tar.gz
VORBIS_SHA256=b33cc4934322bcbf6efcbacf49e3ca01aadbea4114ec9589d1b1e9d20f72954b

OGG_VERSION=1.3.6
OGG_URL=https://ftp.osuosl.org/pub/xiph/releases/ogg/libogg-1.3.6.tar.gz
OGG_SHA256=83e6704730683d004d20e21b8f7f55dcb3383cdf84c0daedf30bde175f774638

FDKAAC_VERSION=v2.0.3
FDKAAC_GIT_URL=https://github.com/mstorsjo/fdk-aac.git

FLAC_VERSION=1.5.0
FLAC_URL=https://ftp.osuosl.org/pub/xiph/releases/flac/flac-1.5.0.tar.xz
FLAC_SHA256=f2c1c76592a82ffff8413ba3c4a1299b6c7ab06c734dee03fd88630485c2b920

SPEEX_VERSION=1.2.1
SPEEX_URL=https://ftp.osuosl.org/pub/xiph/releases/speex/speex-1.2.1.tar.gz
SPEEX_SHA256=4b44d4f2b38a370a2d98a78329fefc56a0cf93d1c1be70029217baae6628feea

# Subtitle/Rendering Libraries
LIBASS_VERSION=0.17.4
LIBASS_URL=https://github.com/libass/libass/releases/download/0.17.4/libass-0.17.4.tar.gz
LIBASS_SHA256=a886b3b80867f437bc55cff3280a652bfa0d37b43d2aff39ddf3c4f288b8c5a8

FREETYPE_VERSION=2.14.1
FREETYPE_URL=https://download.savannah.gnu.org/releases/freetype/freetype-2.14.1.tar.xz
FREETYPE_SHA256=32427e8c471ac095853212a37aef816c60b42052d4d9e48230bab3bdf2936ccc

# Build Tools
NASM_VERSION=3.01
NASM_URL=https://github.com/netwide-assembler/nasm/archive/refs/tags/nasm-3.01.tar.gz
NASM_SHA256=af2f241ecc061205d73ba4f781f075d025dabaeab020b676b7db144bf7015d6d

# Network Libraries
OPENSSL_VERSION=3.6.0
OPENSSL_URL=https://www.openssl.org/source/openssl-3.6.0.tar.gz
OPENSSL_SHA256=b6a5f44b7eb69e3fa35dbf15524405b44837a481d43d81daddde3ff21fcbb8e9

# Platform Constraints
MACOS_DEPLOYMENT_TARGET=11.0

# Cache Management
CACHE_VERSION=12
