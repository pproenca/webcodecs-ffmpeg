#!/usr/bin/env bash
#
# macOS x64 (Intel) FFmpeg Build
#
# Usage: ./platforms/darwin/x64/build.sh
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# Set architecture BEFORE sourcing common.sh
export MACOS_ARCH="x86_64"
source "$SCRIPT_DIR/../common.sh"

PLATFORM="darwin-x64"

echo "=========================================="
echo "macOS Native Build: $PLATFORM"
echo "=========================================="
echo "Architecture: $MACOS_ARCH"
echo "Deployment Target: $MACOS_DEPLOYMENT_TARGET"
echo ""

#######################################
# Build Environment
#######################################

export PREFIX="$PROJECT_ROOT/artifacts/$PLATFORM"
export PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig"
export PATH="$PREFIX/bin:$PATH"
export WORK_DIR="$PROJECT_ROOT/ffmpeg_sources"

mkdir -p "$PREFIX"/{include,lib,bin}
mkdir -p "$WORK_DIR"

#######################################
# Setup
#######################################

setup_ccache
install_prerequisites

# Clean previous builds
cd "$WORK_DIR"
rm -rf x264 x265_git libvpx aom aom_build opus-* lame-* nasm-* \
    SVT-AV1 libtheora-* xvidcore speex-* flac-* \
    fdk-aac freetype-* libass-* libogg-* libvorbis-* \
    openssl-* dav1d-*

#######################################
# Build Codecs
#######################################

# Build Tools
build_codec nasm

# Video Codecs
build_codec x264
build_codec x265
build_codec libvpx
build_codec libaom
build_codec dav1d
build_codec svt-av1
build_codec theora
build_codec xvid

# Audio Codecs (ogg must come before vorbis)
build_codec ogg
build_codec vorbis
build_codec opus
build_codec lame
build_codec fdk-aac
build_codec flac
build_codec speex

# Support Libraries
build_codec freetype
build_codec libass
build_codec openssl

#######################################
# Build FFmpeg
#######################################

echo ""
echo "=== Building FFmpeg ${FFMPEG_VERSION} ==="

cd "$WORK_DIR"

if [[ ! -d ffmpeg ]]; then
    for i in 1 2 3; do
        git clone --depth 1 --branch "${FFMPEG_VERSION}" \
            "${FFMPEG_GIT_URL}" ffmpeg && break
        echo "Clone attempt $i failed, retrying in 10s..."
        sleep 10
    done
    if [[ ! -d ffmpeg ]]; then
        echo "ERROR: Failed to clone FFmpeg after 3 attempts"
        exit 1
    fi
fi

cd ffmpeg
make distclean 2>/dev/null || true

./configure \
    --cc="clang -arch $MACOS_ARCH" \
    --prefix="$PREFIX" \
    --extra-cflags="-I$PREFIX/include -fno-stack-check -mmacosx-version-min=$MACOS_DEPLOYMENT_TARGET" \
    --extra-ldflags="-L$PREFIX/lib -mmacosx-version-min=$MACOS_DEPLOYMENT_TARGET" \
    --pkg-config-flags="--static" \
    --enable-static \
    --disable-shared \
    --enable-gpl \
    --enable-version3 \
    --enable-nonfree \
    --enable-pthreads \
    --enable-runtime-cpudetect \
    --disable-ffplay \
    --disable-doc \
    --disable-debug \
    --enable-libx264 \
    --enable-libx265 \
    --enable-libvpx \
    --enable-libaom \
    --enable-libsvtav1 \
    --enable-libdav1d \
    --enable-libtheora \
    --enable-libxvid \
    --enable-libvorbis \
    --enable-libopus \
    --enable-libmp3lame \
    --enable-libfdk-aac \
    --enable-libspeex \
    --enable-libfreetype \
    --enable-libass \
    --enable-openssl \
    --enable-videotoolbox

make -j"$(sysctl -n hw.ncpu)"
make install

#######################################
# Finalize
#######################################

cleanup_artifacts
verify_build

echo ""
echo "=========================================="
echo "Build Complete: $PLATFORM"
echo "=========================================="
echo "Output: $PREFIX"
