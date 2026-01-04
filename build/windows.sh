#!/usr/bin/env bash
#
# Windows FFmpeg Build Script (Docker-based Cross-Compilation)
# Supports: windows-x64
#
# This script builds FFmpeg for Windows using MinGW-w64 cross-compiler
# inside a Docker container for reproducibility.
# Based on: https://trac.ffmpeg.org/wiki/CompilationGuide/CrossCompilingForWindows

set -euo pipefail

PLATFORM="${1:-}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

if [[ -z "$PLATFORM" ]]; then
  echo "ERROR: Platform argument required"
  exit 1
fi

echo "=========================================="
echo "Windows Docker Build: $PLATFORM"
echo "=========================================="

# Validate platform
case "$PLATFORM" in
  windows-x64)
    # Valid platform
    ;;
  *)
    echo "ERROR: Invalid Windows platform '$PLATFORM'"
    echo "Supported: windows-x64"
    exit 1
    ;;
esac

DOCKERFILE="$PROJECT_ROOT/platforms/$PLATFORM/Dockerfile"
IMAGE_TAG="ffmpeg-builder:$PLATFORM"

if [[ ! -f "$DOCKERFILE" ]]; then
  echo "ERROR: Dockerfile not found: $DOCKERFILE"
  exit 1
fi

echo "Dockerfile: $DOCKERFILE"
echo "Image tag:  $IMAGE_TAG"
echo ""

# Build Docker image with all codec versions as build args
echo "Building Docker image (this may take 25-35 minutes)..."
docker buildx build \
  --platform linux/amd64 \
  --build-arg FFMPEG_VERSION="$FFMPEG_VERSION" \
  --build-arg X264_VERSION="$X264_VERSION" \
  --build-arg X265_VERSION="$X265_VERSION" \
  --build-arg LIBVPX_VERSION="$LIBVPX_VERSION" \
  --build-arg LIBAOM_VERSION="$LIBAOM_VERSION" \
  --build-arg SVTAV1_VERSION="$SVTAV1_VERSION" \
  --build-arg RAV1E_VERSION="$RAV1E_VERSION" \
  --build-arg THEORA_VERSION="$THEORA_VERSION" \
  --build-arg THEORA_SHA256="$THEORA_SHA256" \
  --build-arg XVID_VERSION="$XVID_VERSION" \
  --build-arg XVID_SHA256="$XVID_SHA256" \
  --build-arg OPUS_VERSION="$OPUS_VERSION" \
  --build-arg OPUS_SHA256="$OPUS_SHA256" \
  --build-arg LAME_VERSION="$LAME_VERSION" \
  --build-arg LAME_SHA256="$LAME_SHA256" \
  --build-arg FDKAAC_VERSION="$FDKAAC_VERSION" \
  --build-arg FLAC_VERSION="$FLAC_VERSION" \
  --build-arg FLAC_SHA256="$FLAC_SHA256" \
  --build-arg SPEEX_VERSION="$SPEEX_VERSION" \
  --build-arg SPEEX_SHA256="$SPEEX_SHA256" \
  --build-arg LIBASS_VERSION="$LIBASS_VERSION" \
  --build-arg LIBASS_SHA256="$LIBASS_SHA256" \
  --build-arg FREETYPE_VERSION="$FREETYPE_VERSION" \
  --build-arg FREETYPE_SHA256="$FREETYPE_SHA256" \
  --build-arg LIBVORBIS_VERSION="$VORBIS_VERSION" \
  --build-arg LIBOGG_VERSION="$OGG_VERSION" \
  --build-arg NASM_VERSION="$NASM_VERSION" \
  --build-arg NASM_SHA256="$NASM_SHA256" \
  --cache-from type=gha,scope="$PLATFORM" \
  --cache-to type=gha,mode=max,scope="$PLATFORM" \
  -f "$DOCKERFILE" \
  -t "$IMAGE_TAG" \
  --load \
  "$PROJECT_ROOT"

echo ""
echo "Docker build complete. Extracting artifacts..."

# Create temporary container to extract artifacts
CONTAINER_ID="ffmpeg-extract-$PLATFORM-$$"
docker create --name "$CONTAINER_ID" "$IMAGE_TAG"

# Prepare artifact directory
ARTIFACT_DIR="$PROJECT_ROOT/artifacts/$PLATFORM"
rm -rf "$ARTIFACT_DIR"
mkdir -p "$ARTIFACT_DIR"/{bin,lib,include}

# Extract binaries
echo "Extracting bin/..."
docker cp "$CONTAINER_ID:/opt/ffmpeg/bin/." "$ARTIFACT_DIR/bin/" || {
  echo "ERROR: Failed to extract bin/"
  docker rm "$CONTAINER_ID"
  exit 1
}

# Extract libraries
echo "Extracting lib/..."
docker cp "$CONTAINER_ID:/opt/ffmpeg/lib/." "$ARTIFACT_DIR/lib/" || {
  echo "ERROR: Failed to extract lib/"
  docker rm "$CONTAINER_ID"
  exit 1
}

# Extract headers
echo "Extracting include/..."
docker cp "$CONTAINER_ID:/opt/ffmpeg/include/." "$ARTIFACT_DIR/include/" || {
  echo "ERROR: Failed to extract include/"
  docker rm "$CONTAINER_ID"
  exit 1
}

# Cleanup
docker rm "$CONTAINER_ID"

echo ""
echo "=========================================="
echo "Build Complete: $PLATFORM"
echo "=========================================="
echo "Artifacts: $ARTIFACT_DIR"
echo ""
echo "Binaries:"
ls -lh "$ARTIFACT_DIR"/bin/*.exe 2>/dev/null || echo "No executables found"
echo ""
echo "Libraries:"
ls -lh "$ARTIFACT_DIR"/lib/*.a 2>/dev/null | head -5 || echo "No static libraries"
echo ""

# Run verification
echo "Running verification..."
"$SCRIPT_DIR/verify.sh" "$PLATFORM"

echo ""
echo "✓ Windows build succeeded: $PLATFORM"
