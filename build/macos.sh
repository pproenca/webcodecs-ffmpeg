#!/usr/bin/env bash
#
# macOS FFmpeg Build Script
# Supports: darwin-x64, darwin-arm64
#
# This script builds FFmpeg and all codec dependencies natively on macOS.
# Ported from node-webcodecs/scripts/ci/build-ffmpeg-workflow.ts

set -euo pipefail

PLATFORM="${1:-}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

if [[ -z "$PLATFORM" ]]; then
  echo "ERROR: Platform argument required"
  exit 1
fi

# Extract architecture from platform
case "$PLATFORM" in
  darwin-x64)
    ARCH="x86_64"
    ;;
  darwin-arm64)
    ARCH="arm64"
    ;;
  *)
    echo "ERROR: Invalid macOS platform '$PLATFORM'"
    echo "Supported: darwin-x64, darwin-arm64"
    exit 1
    ;;
esac

echo "=========================================="
echo "macOS Native Build: $PLATFORM"
echo "=========================================="
echo "Architecture: $ARCH"
echo "Deployment Target: $MACOS_DEPLOYMENT_TARGET"
echo ""

# Set up build environment
export TARGET="$PROJECT_ROOT/artifacts/$PLATFORM"
export PKG_CONFIG_PATH="$TARGET/lib/pkgconfig"
export PATH="$TARGET/bin:$PATH"

mkdir -p "$TARGET"/{include,lib,bin}
mkdir -p "$PROJECT_ROOT/ffmpeg_sources"

# Install Homebrew dependencies
echo "Installing Homebrew dependencies..."
brew install autoconf automake libtool cmake pkg-config || {
  echo "WARNING: Homebrew install failed, assuming dependencies already installed"
}

cd "$PROJECT_ROOT/ffmpeg_sources"

# Clean previous builds
rm -rf x264 x265_git libvpx aom aom_build opus-* lame-* nasm-*

#=============================================================================
# Build NASM (assembler required for x264/x265)
#=============================================================================
echo ""
echo "=== Building NASM ${NASM_VERSION} ==="
NASM_URL="https://github.com/netwide-assembler/nasm/archive/refs/tags/nasm-${NASM_VERSION}.tar.gz"

curl -fSL --retry 3 --retry-delay 5 "$NASM_URL" -o nasm.tar.gz || {
  echo "ERROR: Failed to download NASM from $NASM_URL"
  exit 1
}

echo "${NASM_SHA256}  nasm.tar.gz" | shasum -a 256 -c - || {
  echo "ERROR: NASM checksum verification failed!"
  echo "Expected: ${NASM_SHA256}"
  echo "Got:      $(shasum -a 256 nasm.tar.gz | cut -d' ' -f1)"
  exit 1
}
echo "✓ NASM checksum verified"

tar xzf nasm.tar.gz
cd "nasm-nasm-${NASM_VERSION}"
./autogen.sh
./configure --prefix="$TARGET"
make -j"$(sysctl -n hw.ncpu)"
install -c nasm ndisasm "$TARGET/bin/"
cd ..

#=============================================================================
# Build x264 (H.264 encoder, GPL)
#=============================================================================
echo ""
echo "=== Building x264 ${X264_VERSION} ==="
git clone --depth 1 --branch "${X264_VERSION}" https://code.videolan.org/videolan/x264.git
cd x264
./configure \
  --prefix="$TARGET" \
  --enable-static \
  --disable-shared \
  --enable-pic \
  --disable-cli \
  --extra-cflags="-arch $ARCH -mmacosx-version-min=${MACOS_DEPLOYMENT_TARGET}" \
  --extra-ldflags="-arch $ARCH -mmacosx-version-min=${MACOS_DEPLOYMENT_TARGET}"
make -j"$(sysctl -n hw.ncpu)"
make install
cd ..

#=============================================================================
# Build x265 (H.265 encoder, GPL)
#=============================================================================
echo ""
echo "=== Building x265 ${X265_VERSION} ==="
git clone --depth 1 --branch "${X265_VERSION}" https://bitbucket.org/multicoreware/x265_git.git

# Apply CMake 4.x compatibility patch
echo "Applying CMake 4.x compatibility patch..."
patch -p1 -d x265_git < "$SCRIPT_DIR/patches/x265-cmake4-compat.patch"

mkdir -p x265_git/build/xcode && cd x265_git/build/xcode
cmake \
  -DCMAKE_INSTALL_PREFIX="$TARGET" \
  -DLIB_INSTALL_DIR="$TARGET/lib" \
  -DENABLE_SHARED=OFF \
  -DENABLE_CLI=OFF \
  -DCMAKE_OSX_ARCHITECTURES="$ARCH" \
  -DCMAKE_OSX_DEPLOYMENT_TARGET="${MACOS_DEPLOYMENT_TARGET}" \
  ../../source
make -j"$(sysctl -n hw.ncpu)"
make install

# x265 doesn't generate pkg-config file, create manually
mkdir -p "$TARGET/lib/pkgconfig"
cat > "$TARGET/lib/pkgconfig/x265.pc" << PCEOF
prefix=$TARGET
exec_prefix=\${prefix}
libdir=\${prefix}/lib
includedir=\${prefix}/include

Name: x265
Description: H.265/HEVC video encoder
Version: ${X265_VERSION}
Libs: -L\${libdir} -lx265
Libs.private: -lc++ -lm -lpthread
Cflags: -I\${includedir}
PCEOF
cd ../../..

#=============================================================================
# Build libvpx (VP8/VP9, BSD)
#=============================================================================
echo ""
echo "=== Building libvpx ${LIBVPX_VERSION} ==="
git clone --depth 1 --branch "${LIBVPX_VERSION}" https://chromium.googlesource.com/webm/libvpx.git
cd libvpx

DARWIN_VERSION=$(uname -r | cut -d. -f1)
if [ "$ARCH" = "arm64" ]; then
  VPX_TARGET="arm64-darwin${DARWIN_VERSION}-gcc"
else
  VPX_TARGET="x86_64-darwin${DARWIN_VERSION}-gcc"
fi
echo "Using libvpx target: $VPX_TARGET"

LDFLAGS="-mmacosx-version-min=${MACOS_DEPLOYMENT_TARGET}" \
./configure \
  --prefix="$TARGET" \
  --target="$VPX_TARGET" \
  --enable-vp8 \
  --enable-vp9 \
  --disable-examples \
  --disable-unit-tests \
  --enable-vp9-highbitdepth \
  --enable-static \
  --disable-shared \
  --extra-cflags="-mmacosx-version-min=${MACOS_DEPLOYMENT_TARGET}"
make -j"$(sysctl -n hw.ncpu)"
make install
cd ..

#=============================================================================
# Build libaom (AV1, BSD)
#=============================================================================
echo ""
echo "=== Building libaom ${LIBAOM_VERSION} ==="
git clone --depth 1 --branch "${LIBAOM_VERSION}" https://aomedia.googlesource.com/aom
mkdir aom_build && cd aom_build
cmake \
  -DCMAKE_INSTALL_PREFIX="$TARGET" \
  -DBUILD_SHARED_LIBS=OFF \
  -DENABLE_DOCS=OFF \
  -DENABLE_EXAMPLES=OFF \
  -DENABLE_TESTS=OFF \
  -DCMAKE_OSX_ARCHITECTURES="$ARCH" \
  -DCMAKE_OSX_DEPLOYMENT_TARGET="${MACOS_DEPLOYMENT_TARGET}" \
  ../aom
make -j"$(sysctl -n hw.ncpu)"
make install
cd ..

#=============================================================================
# Build Opus (audio codec, BSD)
#=============================================================================
echo ""
echo "=== Building Opus ${OPUS_VERSION} ==="
curl -fSL --retry 3 "https://downloads.xiph.org/releases/opus/opus-${OPUS_VERSION}.tar.gz" -o opus.tar.gz || {
  echo "ERROR: Failed to download Opus from xiph.org"
  exit 1
}

echo "${OPUS_SHA256}  opus.tar.gz" | shasum -a 256 -c - || {
  echo "ERROR: Opus checksum verification failed!"
  echo "Expected: ${OPUS_SHA256}"
  echo "Got:      $(shasum -a 256 opus.tar.gz | cut -d' ' -f1)"
  exit 1
}
echo "✓ Opus checksum verified"

tar xzf opus.tar.gz
cd "opus-${OPUS_VERSION}"
./configure \
  --prefix="$TARGET" \
  --disable-shared \
  --enable-static \
  CFLAGS="-arch $ARCH -mmacosx-version-min=${MACOS_DEPLOYMENT_TARGET}" \
  LDFLAGS="-arch $ARCH -mmacosx-version-min=${MACOS_DEPLOYMENT_TARGET}"
make -j"$(sysctl -n hw.ncpu)"
make install
cd ..

#=============================================================================
# Build LAME (MP3 encoder, LGPL)
#=============================================================================
echo ""
echo "=== Building LAME ${LAME_VERSION} ==="
curl -fSL --retry 3 "https://downloads.sourceforge.net/project/lame/lame/${LAME_VERSION}/lame-${LAME_VERSION}.tar.gz" -o lame.tar.gz || {
  echo "ERROR: Failed to download LAME from SourceForge"
  exit 1
}

echo "${LAME_SHA256}  lame.tar.gz" | shasum -a 256 -c - || {
  echo "ERROR: LAME checksum verification failed!"
  echo "Expected: ${LAME_SHA256}"
  echo "Got:      $(shasum -a 256 lame.tar.gz | cut -d' ' -f1)"
  exit 1
}
echo "✓ LAME checksum verified"

tar xzf lame.tar.gz
cd "lame-${LAME_VERSION}"
./configure \
  --prefix="$TARGET" \
  --disable-shared \
  --enable-static \
  --enable-nasm \
  CFLAGS="-arch $ARCH -mmacosx-version-min=${MACOS_DEPLOYMENT_TARGET}" \
  LDFLAGS="-arch $ARCH -mmacosx-version-min=${MACOS_DEPLOYMENT_TARGET}"
make -j"$(sysctl -n hw.ncpu)"
make install
cd ..

#=============================================================================
# Build FFmpeg
#=============================================================================
echo ""
echo "=== Building FFmpeg ${FFMPEG_VERSION} ==="

if [ ! -d ffmpeg ]; then
  for i in 1 2 3; do
    git clone --depth 1 --branch "${FFMPEG_VERSION}" https://github.com/FFmpeg/FFmpeg.git ffmpeg && break
    echo "Clone attempt $i failed, retrying in 10s..."
    sleep 10
  done
  if [ ! -d ffmpeg ]; then
    echo "ERROR: Failed to clone FFmpeg after 3 attempts"
    exit 1
  fi
fi

cd ffmpeg
make distclean 2>/dev/null || true

./configure \
  --cc="clang -arch $ARCH" \
  --prefix="$TARGET" \
  --extra-cflags="-I$TARGET/include -fno-stack-check -mmacosx-version-min=${MACOS_DEPLOYMENT_TARGET}" \
  --extra-ldflags="-L$TARGET/lib -mmacosx-version-min=${MACOS_DEPLOYMENT_TARGET}" \
  --pkg-config-flags="--static" \
  --enable-static \
  --disable-shared \
  --enable-gpl \
  --enable-version3 \
  --enable-pthreads \
  --enable-runtime-cpudetect \
  --disable-ffplay \
  --disable-doc \
  --disable-debug \
  --enable-libx264 \
  --enable-libx265 \
  --enable-libvpx \
  --enable-libaom \
  --enable-libopus \
  --enable-libmp3lame

make -j"$(sysctl -n hw.ncpu)"
make install
cd ..

#=============================================================================
# Verify and strip binaries
#=============================================================================
echo ""
echo "=== Verifying macOS binaries ==="
otool -L "$TARGET/bin/ffmpeg"
otool -L "$TARGET/bin/ffprobe"

echo ""
echo "=== Stripping debug symbols ==="
strip "$TARGET/bin/ffmpeg"
strip "$TARGET/bin/ffprobe"

echo ""
echo "=========================================="
echo "Build Complete: $PLATFORM"
echo "=========================================="
echo "Target: $TARGET"
echo ""
ls -lh "$TARGET"/bin/*
echo ""

# Run verification
echo "Running verification..."
"$SCRIPT_DIR/verify.sh" "$PLATFORM"

echo ""
echo "✓ macOS build succeeded: $PLATFORM"
