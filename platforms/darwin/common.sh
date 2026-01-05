#!/usr/bin/env bash
# Shared macOS configuration
# Sourced by arm64/build.sh and x64/build.sh

set -euo pipefail

DARWIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly DARWIN_DIR

# Load versions
source "$DARWIN_DIR/versions.sh"

# Export all version variables
export FFMPEG_VERSION FFMPEG_GIT_URL
export X264_VERSION X264_GIT_URL
export X265_VERSION X265_GIT_URL
export LIBVPX_VERSION LIBVPX_GIT_URL
export LIBAOM_VERSION LIBAOM_GIT_URL
export SVTAV1_VERSION SVTAV1_GIT_URL
export DAV1D_VERSION DAV1D_URL DAV1D_SHA256
export THEORA_VERSION THEORA_URL THEORA_SHA256
export XVID_VERSION XVID_URL XVID_SHA256
export OPUS_VERSION OPUS_URL OPUS_SHA256
export LAME_VERSION LAME_URL LAME_SHA256
export VORBIS_VERSION VORBIS_URL VORBIS_SHA256
export OGG_VERSION OGG_URL OGG_SHA256
export FDKAAC_VERSION FDKAAC_GIT_URL
export FLAC_VERSION FLAC_URL FLAC_SHA256
export SPEEX_VERSION SPEEX_URL SPEEX_SHA256
export LIBASS_VERSION LIBASS_URL LIBASS_SHA256
export FREETYPE_VERSION FREETYPE_URL FREETYPE_SHA256
export NASM_VERSION NASM_URL NASM_SHA256
export OPENSSL_VERSION OPENSSL_URL OPENSSL_SHA256
export MACOS_DEPLOYMENT_TARGET

# Paths
export CODECS_DIR="$DARWIN_DIR/codecs"
export PATCH_DIR="$DARWIN_DIR/patches"

# macOS-specific build flags (MACOS_ARCH must be set by caller)
if [[ -z "${MACOS_ARCH:-}" ]]; then
    echo "ERROR: MACOS_ARCH must be set before sourcing common.sh"
    exit 1
fi

export EXTRA_CFLAGS="-arch $MACOS_ARCH -mmacosx-version-min=$MACOS_DEPLOYMENT_TARGET"
export EXTRA_LDFLAGS="-arch $MACOS_ARCH -mmacosx-version-min=$MACOS_DEPLOYMENT_TARGET"
export EXTRA_CMAKE_FLAGS="-DCMAKE_OSX_ARCHITECTURES=$MACOS_ARCH -DCMAKE_OSX_DEPLOYMENT_TARGET=$MACOS_DEPLOYMENT_TARGET"

#######################################
# Setup ccache (optional)
#######################################
setup_ccache() {
    if command -v ccache &>/dev/null; then
        export CCACHE_DIR="${CCACHE_DIR:-$HOME/.ccache}"
        export CC="ccache clang"
        export CXX="ccache clang++"
        echo "Using ccache (cache dir: $CCACHE_DIR)"
        ccache -s 2>/dev/null || true
    else
        echo "ccache not found - install with: brew install ccache"
    fi
}

#######################################
# Install Homebrew prerequisites
#######################################
install_prerequisites() {
    echo "Checking Homebrew dependencies..."
    brew install autoconf automake libtool cmake pkg-config meson ninja 2>/dev/null || {
        echo "Dependencies already installed or brew install failed"
    }
}

#######################################
# Build a codec using its script
#######################################
build_codec() {
    local name="$1"
    local script="$CODECS_DIR/${name}.sh"

    if [[ ! -f "$script" ]]; then
        echo "ERROR: Codec script not found: $script"
        exit 1
    fi

    echo ""
    echo "=== Building $name ==="
    bash "$script"
}

#######################################
# Cleanup build artifacts
#######################################
cleanup_artifacts() {
    echo ""
    echo "=== Cleaning up build artifacts ==="

    if [[ -d "$PREFIX/lib/pkgconfig" ]]; then
        rm -rf "$PREFIX/lib/pkgconfig"
    fi

    find "$PREFIX/lib" -name "*.la" -type f -delete 2>/dev/null || true

    if [[ -d "$PREFIX/lib/cmake" ]]; then
        rm -rf "$PREFIX/lib/cmake"
    fi

    echo "Build artifacts cleaned"
}

#######################################
# Verify and strip binaries
#######################################
verify_build() {
    echo ""
    echo "=== Verifying macOS binaries ==="
    otool -L "$PREFIX/bin/ffmpeg"
    otool -L "$PREFIX/bin/ffprobe"

    echo ""
    echo "=== Stripping debug symbols ==="
    strip "$PREFIX/bin/ffmpeg"
    strip "$PREFIX/bin/ffprobe"

    echo ""
    ls -lh "$PREFIX"/bin/*
}
