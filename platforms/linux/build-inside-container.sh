#!/usr/bin/env bash
#
# FFmpeg Build Script - Runs INSIDE Docker container
#
# This script is mounted into the container and executed.
# The /src directory contains the entire linux/ platform directory.
#
# Required environment variables:
#   PLATFORM         - Target platform (e.g., linux-x64-glibc)
#
# Optional environment variables:
#   FFMPEG_FLAGS_FILE   - Path to variant-specific FFmpeg flags (e.g., /src/glibc/x64-vaapi/ffmpeg-flags.sh)
#   OPENSSL_TARGET      - OpenSSL target platform (e.g., linux-x86_64)
#   SKIP_OPENSSL        - Set to 1 to skip OpenSSL (musl builds)
#   STATIC_BUILD        - Set to 1 for fully static linking (musl builds)
#
# Usage:
#   docker run -v /path/to/linux:/src:ro -e PLATFORM=linux-x64-glibc ... /src/build-inside-container.sh

set -euo pipefail

echo "=========================================="
echo "FFmpeg Build: ${PLATFORM:-unknown}"
echo "=========================================="

# Validate we're running inside container with mounted source
if [[ ! -d /src/codecs ]]; then
    echo "ERROR: /src/codecs not found. Mount the linux/ directory to /src" >&2
    exit 1
fi

# Source versions and common config from mounted directory
source /src/versions.sh
source /src/codecs/common.sh

# Build environment
export PREFIX="${PREFIX:-/build}"
export PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig"
export PATH="$PREFIX/bin:$PATH"
export MAKEFLAGS="${MAKEFLAGS:--j$(nproc)}"
export CFLAGS="${CFLAGS:--fPIC}"
export CXXFLAGS="${CXXFLAGS:--fPIC}"
export PATCH_DIR=/src/patches

# Create build directories
mkdir -p "$PREFIX"/{bin,lib,include}

echo ""
echo "=== Build Configuration ==="
echo "PLATFORM:      ${PLATFORM:-not set}"
echo "PREFIX:        $PREFIX"
echo "FFMPEG:        $FFMPEG_VERSION"
echo "PARALLEL JOBS: $(nproc)"
echo ""

# =============================================================================
# Build Codecs
# =============================================================================

echo "=========================================="
echo "Building Codecs"
echo "=========================================="

# Video codecs
log "Building video codecs..."
/src/codecs/x264.sh
/src/codecs/x265.sh
/src/codecs/libvpx.sh
/src/codecs/libaom.sh
/src/codecs/dav1d.sh
/src/codecs/svt-av1.sh
/src/codecs/xvid.sh

# Audio codecs (order matters: ogg before vorbis/theora)
log "Building audio codecs..."
/src/codecs/ogg.sh
/src/codecs/vorbis.sh
/src/codecs/theora.sh
/src/codecs/opus.sh
/src/codecs/lame.sh
/src/codecs/fdk-aac.sh
/src/codecs/flac.sh
/src/codecs/speex.sh

# Support libraries
log "Building support libraries..."
/src/codecs/freetype.sh
/src/codecs/libass.sh

# OpenSSL (optional, skipped for musl static builds)
if [[ "${SKIP_OPENSSL:-0}" != "1" ]]; then
    log "Building OpenSSL..."
    export OPENSSL_TARGET="${OPENSSL_TARGET:-linux-x86_64}"
    /src/codecs/openssl.sh
fi

# =============================================================================
# Build FFmpeg
# =============================================================================

echo ""
echo "=========================================="
echo "Building FFmpeg ${FFMPEG_VERSION}"
echo "=========================================="

cd /src
if [[ ! -d ffmpeg ]]; then
    git clone --depth 1 --branch "${FFMPEG_VERSION}" "${FFMPEG_GIT_URL}" ffmpeg
fi
cd ffmpeg

# Base FFmpeg configure flags
FFMPEG_CONFIGURE_FLAGS=(
    --prefix="$PREFIX"
    --pkg-config-flags="--static"
    --extra-cflags="-I$PREFIX/include ${CFLAGS:-}"
    --extra-ldflags="-L$PREFIX/lib"
    --extra-libs="-lpthread -lm -lstdc++"
    --enable-gpl
    --enable-version3
    --enable-nonfree
    --enable-static
    --disable-shared
    --enable-pic
    --disable-ffplay
    --disable-doc
    --disable-debug
    # Video codecs
    --enable-libx264
    --enable-libx265
    --enable-libvpx
    --enable-libaom
    --enable-libsvtav1
    --enable-libdav1d
    --enable-libtheora
    --enable-libxvid
    # Audio codecs
    --enable-libopus
    --enable-libmp3lame
    --enable-libfdk-aac
    --enable-libspeex
    --enable-libvorbis
    # Subtitle/rendering
    --enable-libfreetype
    --enable-libass
)

# Add OpenSSL and network protocols if not skipped
if [[ "${SKIP_OPENSSL:-0}" != "1" ]]; then
    FFMPEG_CONFIGURE_FLAGS+=(
        --enable-openssl
        --enable-protocol=file,http,https,tcp,tls
    )
fi

# Add static linking flags for musl builds
if [[ "${STATIC_BUILD:-0}" == "1" ]]; then
    FFMPEG_CONFIGURE_FLAGS+=(
        --extra-cflags="-I$PREFIX/include -fPIC -static"
        --extra-ldflags="-L$PREFIX/lib -static"
        --disable-network
    )
fi

# Load variant-specific flags (vaapi, nvenc, etc.)
if [[ -n "${FFMPEG_FLAGS_FILE:-}" && -f "${FFMPEG_FLAGS_FILE}" ]]; then
    echo "Loading variant flags from: $FFMPEG_FLAGS_FILE"
    # shellcheck source=/dev/null
    source "$FFMPEG_FLAGS_FILE"
    if [[ -n "${VARIANT_FLAGS:-}" ]]; then
        # VARIANT_FLAGS is expected to be an array
        FFMPEG_CONFIGURE_FLAGS+=("${VARIANT_FLAGS[@]}")
    fi
fi

echo ""
echo "=== FFmpeg Configure Flags ==="
printf '%s\n' "${FFMPEG_CONFIGURE_FLAGS[@]}"
echo ""

./configure "${FFMPEG_CONFIGURE_FLAGS[@]}"
make -j"$(nproc)"
make install

# =============================================================================
# Cleanup and Verify
# =============================================================================

echo ""
echo "=========================================="
echo "Cleanup and Verification"
echo "=========================================="

# Remove unnecessary files
rm -rf "$PREFIX/lib/pkgconfig"
find "$PREFIX/lib" -name "*.la" -type f -delete
rm -rf "$PREFIX/lib/cmake"

# Strip binaries
strip "$PREFIX/bin/ffmpeg" "$PREFIX/bin/ffprobe"

# Verify
echo ""
echo "=== Binary Sizes ==="
ls -lh "$PREFIX/bin/ffmpeg" "$PREFIX/bin/ffprobe"

echo ""
echo "=== FFmpeg Version ==="
"$PREFIX/bin/ffmpeg" -version

echo ""
echo "=========================================="
echo "Build Complete: ${PLATFORM:-unknown}"
echo "Output: $PREFIX"
echo "=========================================="
