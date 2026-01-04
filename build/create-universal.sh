#!/usr/bin/env bash
#
# Create macOS Universal Binaries
#
# This script merges darwin-x64 and darwin-arm64 builds into universal binaries
# using Apple's lipo tool, following Apple's recommended distribution approach.
#
# Usage: ./build/create-universal.sh
#
# Prerequisites:
#   - darwin-x64 build must exist in artifacts/darwin-x64/
#   - darwin-arm64 build must exist in artifacts/darwin-arm64/
#   - lipo tool must be available (requires macOS)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

DARWIN_X64="$PROJECT_ROOT/artifacts/darwin-x64"
DARWIN_ARM64="$PROJECT_ROOT/artifacts/darwin-arm64"
DARWIN="$PROJECT_ROOT/artifacts/darwin"

echo "=========================================="
echo "Creating macOS Universal Binaries"
echo "=========================================="
echo ""

# Verify prerequisites
if [[ ! -d "$DARWIN_X64" ]]; then
  echo "ERROR: darwin-x64 build not found at $DARWIN_X64"
  echo "Please run: ./build/orchestrator.sh darwin-x64"
  exit 1
fi

if [[ ! -d "$DARWIN_ARM64" ]]; then
  echo "ERROR: darwin-arm64 build not found at $DARWIN_ARM64"
  echo "Please run: ./build/orchestrator.sh darwin-arm64"
  exit 1
fi

if ! command -v lipo &> /dev/null; then
  echo "ERROR: lipo command not found"
  echo "This script must be run on macOS"
  exit 1
fi

echo "Source builds:"
echo "  x64:   $DARWIN_X64"
echo "  arm64: $DARWIN_ARM64"
echo "Target:"
echo "  darwin: $DARWIN"
echo ""

# Create universal directory structure
echo "Creating directory structure..."
rm -rf "$DARWIN"
mkdir -p "$DARWIN"/{bin,lib,include}

# Merge binaries
echo ""
echo "Merging binaries..."
for binary in ffmpeg ffprobe; do
  if [[ -f "$DARWIN_X64/bin/$binary" && -f "$DARWIN_ARM64/bin/$binary" ]]; then
    echo "  $binary..."
    lipo -create \
      "$DARWIN_X64/bin/$binary" \
      "$DARWIN_ARM64/bin/$binary" \
      -output "$DARWIN/bin/$binary"

    # Verify universal binary
    if ! file "$DARWIN/bin/$binary" | grep -q "universal binary"; then
      echo "ERROR: Failed to create universal binary for $binary"
      exit 1
    fi

    # Make executable
    chmod +x "$DARWIN/bin/$binary"

    echo "    ✓ $(file "$DARWIN/bin/$binary" | sed 's/.*: //')"
  else
    echo "  WARNING: $binary not found in both builds, skipping"
  fi
done

# Merge static libraries
echo ""
echo "Merging static libraries..."

# List of libraries to merge
LIBRARIES=(
  "libavcodec.a"
  "libavformat.a"
  "libavutil.a"
  "libswscale.a"
  "libswresample.a"
  "libavfilter.a"
  "libavdevice.a"
  "libx264.a"
  "libx265.a"
  "libvpx.a"
  "libaom.a"
  "libSvtAv1Enc.a"
  "libtheora.a"
  "libtheoraenc.a"
  "libtheoradec.a"
  "libxvidcore.a"
  "libopus.a"
  "libmp3lame.a"
  "libfdk-aac.a"
  "libFLAC.a"
  "libspeex.a"
  "libfreetype.a"
  "libass.a"
  "libvorbis.a"
  "libvorbisenc.a"
  "libvorbisfile.a"
  "libogg.a"
)

for lib in "${LIBRARIES[@]}"; do
  if [[ -f "$DARWIN_X64/lib/$lib" && -f "$DARWIN_ARM64/lib/$lib" ]]; then
    echo "  $lib..."
    lipo -create \
      "$DARWIN_X64/lib/$lib" \
      "$DARWIN_ARM64/lib/$lib" \
      -output "$DARWIN/lib/$lib"
    echo "    ✓ merged"
  else
    echo "  WARNING: $lib not found in both builds, skipping"
  fi
done

# Copy headers (identical across architectures)
echo ""
echo "Copying headers..."
if [[ -d "$DARWIN_X64/include" ]]; then
  cp -R "$DARWIN_X64/include"/* "$DARWIN/include/"
  echo "  ✓ Headers copied from x64 build"
else
  echo "  ERROR: Headers not found in x64 build"
  exit 1
fi

# Verify the universal build
echo ""
echo "Verifying universal binaries..."

# Check binaries
for binary in ffmpeg ffprobe; do
  if [[ -f "$DARWIN/bin/$binary" ]]; then
    echo "  $binary:"
    lipo -info "$DARWIN/bin/$binary" | sed 's/^/    /'

    # Verify both architectures present
    if ! lipo -info "$DARWIN/bin/$binary" | grep -q "x86_64"; then
      echo "    ERROR: x86_64 architecture missing"
      exit 1
    fi
    if ! lipo -info "$DARWIN/bin/$binary" | grep -q "arm64"; then
      echo "    ERROR: arm64 architecture missing"
      exit 1
    fi
    echo "    ✓ Both architectures present"
  fi
done

# Check libraries (sample check on libavcodec)
if [[ -f "$DARWIN/lib/libavcodec.a" ]]; then
  echo "  libavcodec.a:"
  lipo -info "$DARWIN/lib/libavcodec.a" | sed 's/^/    /'
fi

echo ""
echo "=========================================="
echo "Universal Build Complete"
echo "=========================================="
echo ""
echo "Location: $DARWIN"
echo ""
echo "Binaries:"
ls -lh "$DARWIN/bin"/* 2>/dev/null || echo "No binaries"
echo ""
echo "Library count:"
find "$DARWIN/lib" -name "*.a" -type f 2>/dev/null | wc -l | xargs echo "  Static libraries:"
echo ""
echo "Include count:"
find "$DARWIN/include" -name "*.h" 2>/dev/null | wc -l | xargs echo "  Header files:"
echo ""
echo "✓ macOS universal binaries created successfully"
echo ""
echo "Test with:"
echo "  $DARWIN/bin/ffmpeg -version"
echo "  file $DARWIN/bin/ffmpeg"
