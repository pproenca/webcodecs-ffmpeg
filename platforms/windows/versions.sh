#!/usr/bin/env bash
# Windows FFmpeg Build Versions - Single source of truth for Windows builds

# Core FFmpeg
export FFMPEG_VERSION=n8.0.1
export FFMPEG_GIT_URL=https://git.ffmpeg.org/ffmpeg.git

# Video Codecs
export X264_VERSION=stable
export X264_GIT_URL=https://code.videolan.org/videolan/x264.git

export X265_VERSION=4.1
export X265_GIT_URL=https://bitbucket.org/multicoreware/x265_git.git

export LIBVPX_VERSION=v1.15.2
export LIBVPX_GIT_URL=https://chromium.googlesource.com/webm/libvpx.git

export LIBAOM_VERSION=v3.13.1
export LIBAOM_GIT_URL=https://aomedia.googlesource.com/aom

export SVTAV1_VERSION=v3.1.2
export SVTAV1_GIT_URL=https://gitlab.com/AOMediaCodec/SVT-AV1.git

export THEORA_VERSION=1.2.0
export THEORA_URL=https://ftp.osuosl.org/pub/xiph/releases/theora/libtheora-1.2.0.tar.gz
export THEORA_SHA256=279327339903b544c28a92aeada7d0dcfd0397b59c2f368cc698ac56f515906e

export XVID_VERSION=1.3.7
export XVID_URL=https://downloads.xvid.com/downloads/xvidcore-1.3.7.tar.gz
export XVID_SHA256=abbdcbd39555691dd1c9b4d08f0a031376a3b211652c0d8b3b8aa9be1303ce2d

# Audio Codecs
export OPUS_VERSION=1.6
export OPUS_URL=https://downloads.xiph.org/releases/opus/opus-1.6.tar.gz
export OPUS_SHA256=b7637334527201fdfd6dd6a02e67aceffb0e5e60155bbd89175647a80301c92c

export LAME_VERSION=3.100
export LAME_URL=https://downloads.sourceforge.net/project/lame/lame/3.100/lame-3.100.tar.gz
export LAME_SHA256=ddfe36cab873794038ae2c1210557ad34857a4b6bdc515785d1da9e175b1da1e

export OGG_VERSION=1.3.6
export OGG_GIT_URL=https://github.com/xiph/ogg.git

export VORBIS_VERSION=1.3.7
export VORBIS_GIT_URL=https://github.com/xiph/vorbis.git

export FDKAAC_VERSION=v2.0.3
export FDKAAC_GIT_URL=https://github.com/mstorsjo/fdk-aac.git

export FLAC_VERSION=1.5.0
export FLAC_URL=https://ftp.osuosl.org/pub/xiph/releases/flac/flac-1.5.0.tar.xz
export FLAC_SHA256=f2c1c76592a82ffff8413ba3c4a1299b6c7ab06c734dee03fd88630485c2b920

export SPEEX_VERSION=1.2.1
export SPEEX_URL=https://ftp.osuosl.org/pub/xiph/releases/speex/speex-1.2.1.tar.gz
export SPEEX_SHA256=4b44d4f2b38a370a2d98a78329fefc56a0cf93d1c1be70029217baae6628feea

# Support Libraries
export FREETYPE_VERSION=2.14.1
export FREETYPE_URL=https://download.savannah.gnu.org/releases/freetype/freetype-2.14.1.tar.xz
export FREETYPE_SHA256=32427e8c471ac095853212a37aef816c60b42052d4d9e48230bab3bdf2936ccc

export LIBASS_VERSION=0.17.4
export LIBASS_URL=https://github.com/libass/libass/releases/download/0.17.4/libass-0.17.4.tar.gz
export LIBASS_SHA256=a886b3b80867f437bc55cff3280a652bfa0d37b43d2aff39ddf3c4f288b8c5a8

# Build Tools
export NASM_VERSION=2.16.03
export NASM_URL=https://github.com/netwide-assembler/nasm/archive/refs/tags/nasm-2.16.03.tar.gz
export NASM_SHA256=b7f75b9a0e7d7f58f42a99c0e0ab4ef46656c497b25be29ae84332d86c4eec7f

# Cache Version (increment to invalidate CI caches)
export CACHE_VERSION=12
