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

# Setup ccache for faster incremental builds (optional)
if command -v ccache &> /dev/null; then
  export CCACHE_DIR="${CCACHE_DIR:-$HOME/.ccache}"
  export CC="ccache clang"
  export CXX="ccache clang++"
  echo "✓ Using ccache for incremental builds (cache dir: $CCACHE_DIR)"
  echo "  First build: ~20-25 min, subsequent builds: ~2-5 min"
  ccache -s 2>/dev/null || true
else
  echo "ℹ ccache not found - builds will always be from scratch (~20-25 min)"
  echo "  Install ccache to speed up rebuilds: brew install ccache"
fi
echo ""

# Install Homebrew dependencies
echo "Installing Homebrew dependencies..."
brew install autoconf automake libtool cmake pkg-config || {
  echo "WARNING: Homebrew install failed, assuming dependencies already installed"
}

cd "$PROJECT_ROOT/ffmpeg_sources"

# Clean previous builds
rm -rf x264 x265_git libvpx aom aom_build opus-* lame-* nasm-* \
  SVT-AV1 rav1e libtheora-* xvidcore speex-* flac-* \
  fdk-aac freetype-* libass-*

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

# x265 doesn't generate pkg-config file, but we'll remove all .pc files later anyway
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
# Clean up any previous build
rm -rf aom aom_build

git clone --depth 1 --branch "${LIBAOM_VERSION}" https://aomedia.googlesource.com/aom
mkdir -p aom_build
cd aom_build

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
# Build SVT-AV1 (Intel's AV1 encoder, BSD)
#=============================================================================
echo ""
echo "=== Building SVT-AV1 ${SVTAV1_VERSION} ==="
# Clean up any previous build
rm -rf SVT-AV1

git clone --depth 1 --branch "${SVTAV1_VERSION}" "${SVTAV1_GIT_URL}"
cd SVT-AV1
mkdir -p build
cd build

cmake \
  -DCMAKE_INSTALL_PREFIX="$TARGET" \
  -DBUILD_SHARED_LIBS=OFF \
  -DBUILD_APPS=OFF \
  -DBUILD_DEC=OFF \
  -DBUILD_TESTING=OFF \
  -DCMAKE_OSX_ARCHITECTURES="$ARCH" \
  -DCMAKE_OSX_DEPLOYMENT_TARGET="${MACOS_DEPLOYMENT_TARGET}" \
  ..
make -j"$(sysctl -n hw.ncpu)"
make install
cd ../..

#=============================================================================
# Build rav1e (Rust AV1 encoder, BSD)
#=============================================================================
echo ""
echo "=== Building rav1e ${RAV1E_VERSION} ==="
# rav1e requires Rust toolchain - check if cargo is available
if command -v cargo &> /dev/null; then
  git clone --depth 1 --branch "${RAV1E_VERSION}" "${RAV1E_GIT_URL}"
  cd rav1e
  cargo install --path . --root "$TARGET" \
    --target-dir=target \
    --features=asm,threading \
    --no-default-features
  # Build C API library
  cargo cbuild --release --prefix "$TARGET" \
    --target-dir=target \
    --library-type=staticlib
  cd ..
else
  echo "WARNING: Rust/Cargo not found - skipping rav1e"
  echo "Install Rust from https://rustup.rs/ to enable rav1e support"
fi

#=============================================================================
# Build Theora (Ogg video codec, BSD)
#=============================================================================
echo ""
echo "=== Building Theora ${THEORA_VERSION} ==="
curl -fSL --retry 3 "${THEORA_URL}" -o theora.tar.gz || {
  echo "ERROR: Failed to download Theora"
  exit 1
}

echo "${THEORA_SHA256}  theora.tar.gz" | shasum -a 256 -c - || {
  echo "ERROR: Theora checksum verification failed!"
  exit 1
}
echo "✓ Theora checksum verified"

tar xzf theora.tar.gz
cd "libtheora-${THEORA_VERSION}"
./configure \
  --prefix="$TARGET" \
  --disable-shared \
  --enable-static \
  --disable-examples \
  CFLAGS="-arch $ARCH -mmacosx-version-min=${MACOS_DEPLOYMENT_TARGET}" \
  LDFLAGS="-arch $ARCH -mmacosx-version-min=${MACOS_DEPLOYMENT_TARGET}"
make -j"$(sysctl -n hw.ncpu)"
make install
cd ..

#=============================================================================
# Build Xvid (MPEG-4 ASP codec, GPL)
#=============================================================================
echo ""
echo "=== Building Xvid ${XVID_VERSION} ==="
curl -fSL --retry 3 "${XVID_URL}" -o xvid.tar.gz || {
  echo "ERROR: Failed to download Xvid"
  exit 1
}

echo "${XVID_SHA256}  xvid.tar.gz" | shasum -a 256 -c - || {
  echo "ERROR: Xvid checksum verification failed!"
  exit 1
}
echo "✓ Xvid checksum verified"

tar xzf xvid.tar.gz
cd "xvidcore/build/generic"
./configure \
  --prefix="$TARGET" \
  CFLAGS="-arch $ARCH -mmacosx-version-min=${MACOS_DEPLOYMENT_TARGET}" \
  LDFLAGS="-arch $ARCH -mmacosx-version-min=${MACOS_DEPLOYMENT_TARGET}"
make -j"$(sysctl -n hw.ncpu)"
make install
cd ../../..

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

# LAME doesn't generate pkg-config file, but we'll remove all .pc files later anyway
cd ..

#=============================================================================
# Build fdk-aac (High-quality AAC encoder, Non-free)
#=============================================================================
echo ""
echo "=== Building fdk-aac ${FDKAAC_VERSION} ==="
git clone --depth 1 --branch "${FDKAAC_VERSION}" "${FDKAAC_GIT_URL}"
cd fdk-aac
./autogen.sh
./configure \
  --prefix="$TARGET" \
  --disable-shared \
  --enable-static \
  CFLAGS="-arch $ARCH -mmacosx-version-min=${MACOS_DEPLOYMENT_TARGET}" \
  CXXFLAGS="-arch $ARCH -mmacosx-version-min=${MACOS_DEPLOYMENT_TARGET}" \
  LDFLAGS="-arch $ARCH -mmacosx-version-min=${MACOS_DEPLOYMENT_TARGET}"
make -j"$(sysctl -n hw.ncpu)"
make install
cd ..

#=============================================================================
# Build FLAC (Free Lossless Audio Codec, BSD)
#=============================================================================
echo ""
echo "=== Building FLAC ${FLAC_VERSION} ==="
curl -fSL --retry 3 "${FLAC_URL}" -o flac.tar.xz || {
  echo "ERROR: Failed to download FLAC"
  exit 1
}

echo "${FLAC_SHA256}  flac.tar.xz" | shasum -a 256 -c - || {
  echo "ERROR: FLAC checksum verification failed!"
  exit 1
}
echo "✓ FLAC checksum verified"

tar xf flac.tar.xz
cd "flac-${FLAC_VERSION}"
./configure \
  --prefix="$TARGET" \
  --disable-shared \
  --enable-static \
  --disable-examples \
  --disable-cpplibs \
  CFLAGS="-arch $ARCH -mmacosx-version-min=${MACOS_DEPLOYMENT_TARGET}" \
  CXXFLAGS="-arch $ARCH -mmacosx-version-min=${MACOS_DEPLOYMENT_TARGET}" \
  LDFLAGS="-arch $ARCH -mmacosx-version-min=${MACOS_DEPLOYMENT_TARGET}"
make -j"$(sysctl -n hw.ncpu)"
make install
cd ..

#=============================================================================
# Build Speex (Speech codec, BSD)
#=============================================================================
echo ""
echo "=== Building Speex ${SPEEX_VERSION} ==="
curl -fSL --retry 3 "${SPEEX_URL}" -o speex.tar.gz || {
  echo "ERROR: Failed to download Speex"
  exit 1
}

echo "${SPEEX_SHA256}  speex.tar.gz" | shasum -a 256 -c - || {
  echo "ERROR: Speex checksum verification failed!"
  exit 1
}
echo "✓ Speex checksum verified"

tar xzf speex.tar.gz
cd "speex-${SPEEX_VERSION}"
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
# Build libfreetype (Font rendering, FreeType License)
#=============================================================================
echo ""
echo "=== Building libfreetype ${FREETYPE_VERSION} ==="
curl -fSL --retry 3 "${FREETYPE_URL}" -o freetype.tar.xz || {
  echo "ERROR: Failed to download libfreetype"
  exit 1
}

echo "${FREETYPE_SHA256}  freetype.tar.xz" | shasum -a 256 -c - || {
  echo "ERROR: libfreetype checksum verification failed!"
  exit 1
}
echo "✓ libfreetype checksum verified"

tar xf freetype.tar.xz
cd "freetype-${FREETYPE_VERSION}"
./configure \
  --prefix="$TARGET" \
  --disable-shared \
  --enable-static \
  --without-harfbuzz \
  --without-bzip2 \
  --without-png \
  CFLAGS="-arch $ARCH -mmacosx-version-min=${MACOS_DEPLOYMENT_TARGET}" \
  LDFLAGS="-arch $ARCH -mmacosx-version-min=${MACOS_DEPLOYMENT_TARGET}"
make -j"$(sysctl -n hw.ncpu)"
make install
cd ..

#=============================================================================
# Build libass (Subtitle rendering, ISC)
#=============================================================================
echo ""
echo "=== Building libass ${LIBASS_VERSION} ==="
curl -fSL --retry 3 "${LIBASS_URL}" -o libass.tar.gz || {
  echo "ERROR: Failed to download libass"
  exit 1
}

echo "${LIBASS_SHA256}  libass.tar.gz" | shasum -a 256 -c - || {
  echo "ERROR: libass checksum verification failed!"
  exit 1
}
echo "✓ libass checksum verified"

tar xzf libass.tar.gz
cd "libass-${LIBASS_VERSION}"
./configure \
  --prefix="$TARGET" \
  --disable-shared \
  --enable-static \
  --disable-require-system-font-provider \
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
  --enable-libtheora \
  --enable-libxvid \
  --enable-libopus \
  --enable-libmp3lame \
  --enable-libfdk-aac \
  --enable-libspeex \
  --enable-libfreetype \
  --enable-libass \
  --enable-videotoolbox

make -j"$(sysctl -n hw.ncpu)"
make install
cd ..

#=============================================================================
# Clean up build artifacts not needed for distribution
#=============================================================================
echo ""
echo "=== Cleaning up build artifacts ==="

# Remove pkgconfig files (not needed for static builds)
if [[ -d "$TARGET/lib/pkgconfig" ]]; then
  echo "Removing pkgconfig files..."
  rm -rf "$TARGET/lib/pkgconfig"
fi

# Remove libtool .la files (can cause issues with relocation)
if find "$TARGET/lib" -name "*.la" -type f 2>/dev/null | grep -q .; then
  echo "Removing libtool .la files..."
  find "$TARGET/lib" -name "*.la" -type f -delete
fi

# Remove CMake files (not needed for distribution)
if [[ -d "$TARGET/lib/cmake" ]]; then
  echo "Removing CMake files..."
  rm -rf "$TARGET/lib/cmake"
fi

echo "✓ Build artifacts cleaned"

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
