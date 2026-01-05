#!/usr/bin/env bash
#
# macOS FFmpeg Build Script
#
# Builds FFmpeg and all codec dependencies natively on macOS using modular
# codec scripts from build/codecs/. Follows the official FFmpeg compilation
# guide pattern: setup -> dependencies -> FFmpeg -> verify.
#
# Supported platforms:
#   darwin-x64   - macOS Intel (x86_64)
#   darwin-arm64 - macOS Apple Silicon (arm64)
#
# Usage: Called from orchestrator.sh, not directly

set -euo pipefail

#######################################
# Constants and Setup
#######################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
readonly PROJECT_ROOT
CODECS_DIR="$SCRIPT_DIR/codecs"
readonly CODECS_DIR
PLATFORM="${1:-}"

#######################################
# Validate platform and set architecture
#######################################

if [[ -z "$PLATFORM" ]]; then
    echo "ERROR: Platform argument required"
    exit 1
fi

case "$PLATFORM" in
    darwin-x64)
        MACOS_ARCH="x86_64"
        ;;
    darwin-arm64)
        MACOS_ARCH="arm64"
        ;;
    *)
        echo "ERROR: Invalid macOS platform '$PLATFORM'"
        echo "Supported: darwin-x64, darwin-arm64"
        exit 1
        ;;
esac
export MACOS_ARCH

echo "=========================================="
echo "macOS Native Build: $PLATFORM"
echo "=========================================="
echo "Architecture: $MACOS_ARCH"
echo "Deployment Target: ${MACOS_DEPLOYMENT_TARGET:-11.0}"
echo ""

#######################################
# Build Environment
#######################################

export PREFIX="$PROJECT_ROOT/artifacts/$PLATFORM"
export PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig"
export PATH="$PREFIX/bin:$PATH"
export WORK_DIR="$PROJECT_ROOT/ffmpeg_sources"
export PATCH_DIR="$SCRIPT_DIR/patches"

# macOS-specific flags for codec scripts
export MACOS_DEPLOYMENT_TARGET="${MACOS_DEPLOYMENT_TARGET:-11.0}"
export EXTRA_CFLAGS="-arch $MACOS_ARCH -mmacosx-version-min=$MACOS_DEPLOYMENT_TARGET"
export EXTRA_LDFLAGS="-arch $MACOS_ARCH -mmacosx-version-min=$MACOS_DEPLOYMENT_TARGET"
export EXTRA_CMAKE_FLAGS="-DCMAKE_OSX_ARCHITECTURES=$MACOS_ARCH -DCMAKE_OSX_DEPLOYMENT_TARGET=$MACOS_DEPLOYMENT_TARGET"

mkdir -p "$PREFIX"/{include,lib,bin}
mkdir -p "$WORK_DIR"

#######################################
# Setup ccache (optional)
#######################################

setup_ccache() {
    if command -v ccache &>/dev/null; then
        export CCACHE_DIR="${CCACHE_DIR:-$HOME/.ccache}"
        export CC="ccache clang"
        export CXX="ccache clang++"
        echo "Using ccache for incremental builds (cache dir: $CCACHE_DIR)"
        echo "  First build: ~20-25 min, subsequent builds: ~2-5 min"
        ccache -s 2>/dev/null || true
    else
        echo "ccache not found - builds will be from scratch (~20-25 min)"
        echo "  Install ccache to speed up rebuilds: brew install ccache"
    fi
    echo ""
}

#######################################
# Install Homebrew Prerequisites
#######################################

install_prerequisites() {
    echo "Installing Homebrew dependencies..."
    brew install autoconf automake libtool cmake pkg-config meson ninja || {
        echo "WARNING: brew install failed, assuming dependencies installed"
    }
    echo ""
}

#######################################
# Build a codec using its modular script
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
# Build FFmpeg
#######################################

build_ffmpeg() {
    echo ""
    echo "=== Building FFmpeg ${FFMPEG_VERSION} ==="

    cd "$WORK_DIR"

    if [[ ! -d ffmpeg ]]; then
        for i in 1 2 3; do
            git clone --depth 1 --branch "${FFMPEG_VERSION}" \
                https://github.com/FFmpeg/FFmpeg.git ffmpeg && break
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

    local num_cpus
    num_cpus=$(sysctl -n hw.ncpu)
    make -j"$num_cpus"
    make install

    cd "$WORK_DIR"
}

#######################################
# Cleanup build artifacts
#######################################

cleanup_artifacts() {
    echo ""
    echo "=== Cleaning up build artifacts ==="

    # Remove pkgconfig files (not needed for static builds)
    if [[ -d "$PREFIX/lib/pkgconfig" ]]; then
        echo "Removing pkgconfig files..."
        rm -rf "$PREFIX/lib/pkgconfig"
    fi

    # Remove libtool .la files (can cause issues with relocation)
    if find "$PREFIX/lib" -name "*.la" -type f 2>/dev/null | grep -q .; then
        echo "Removing libtool .la files..."
        find "$PREFIX/lib" -name "*.la" -type f -delete
    fi

    # Remove CMake files (not needed for distribution)
    if [[ -d "$PREFIX/lib/cmake" ]]; then
        echo "Removing CMake files..."
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
    echo "=========================================="
    echo "Build Complete: $PLATFORM"
    echo "=========================================="
    echo "Target: $PREFIX"
    echo ""
    ls -lh "$PREFIX"/bin/*
    echo ""

    # Run full verification
    echo "Running verification..."
    "$SCRIPT_DIR/verify.sh" "$PLATFORM"

    echo ""
    echo "macOS build succeeded: $PLATFORM"
}

#######################################
# Main Build Sequence
#######################################

main() {
    setup_ccache
    install_prerequisites

    # Clean previous builds
    cd "$WORK_DIR"
    rm -rf x264 x265_git libvpx aom aom_build opus-* lame-* nasm-* \
        SVT-AV1 rav1e libtheora-* xvidcore speex-* flac-* \
        fdk-aac freetype-* libass-* libogg-* libvorbis-* \
        openssl-* dav1d-*

    # === Build Tools ===
    build_codec nasm

    # === Video Codecs ===
    build_codec x264
    build_codec x265    # Auto-detects ARM64 and disables ASM
    build_codec libvpx
    build_codec libaom
    build_codec dav1d
    build_codec svt-av1
    build_codec theora
    build_codec xvid

    # === Audio Codecs (ogg must come before vorbis) ===
    build_codec ogg
    build_codec vorbis
    build_codec opus
    build_codec lame
    build_codec fdk-aac
    build_codec flac
    build_codec speex

    # === Support Libraries ===
    build_codec freetype
    build_codec libass
    build_codec openssl  # Auto-detects macOS target

    # === Build FFmpeg ===
    build_ffmpeg

    # === Cleanup and Verify ===
    cleanup_artifacts
    verify_build
}

main "$@"
