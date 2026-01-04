#!/usr/bin/env bash
#
# Linux FFmpeg Build Script (Docker-based)
# Supports: linux-x64-glibc, linux-x64-musl, linux-arm64-glibc, linux-arm64-musl
#
# This script builds FFmpeg and all codec dependencies inside Docker containers
# for maximum reproducibility and isolation.

set -euo pipefail

PLATFORM="${1:-}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

if [[ -z "$PLATFORM" ]]; then
  echo "ERROR: Platform argument required"
  exit 1
fi

echo "=========================================="
echo "Linux Docker Build: $PLATFORM"
echo "=========================================="

# Validate platform and determine Docker architecture
case "$PLATFORM" in
  linux-x64-glibc|linux-x64-musl)
    DOCKER_PLATFORM="linux/amd64"
    ;;
  linux-arm64-glibc|linux-arm64-musl)
    DOCKER_PLATFORM="linux/arm64"
    ;;
  *)
    echo "ERROR: Invalid Linux platform '$PLATFORM'"
    echo "Supported: linux-x64-glibc, linux-x64-musl, linux-arm64-glibc, linux-arm64-musl"
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
echo "Building Docker image for $DOCKER_PLATFORM (this may take 20-40 minutes)..."
docker buildx build \
  --platform "$DOCKER_PLATFORM" \
  --build-arg FFMPEG_VERSION="$FFMPEG_VERSION" \
  --build-arg X264_VERSION="$X264_VERSION" \
  --build-arg X265_VERSION="$X265_VERSION" \
  --build-arg LIBVPX_VERSION="$LIBVPX_VERSION" \
  --build-arg LIBAOM_VERSION="$LIBAOM_VERSION" \
  --build-arg OPUS_VERSION="$OPUS_VERSION" \
  --build-arg LAME_VERSION="$LAME_VERSION" \
  --build-arg VORBIS_VERSION="$VORBIS_VERSION" \
  --build-arg OGG_VERSION="$OGG_VERSION" \
  --build-arg NASM_VERSION="$NASM_VERSION" \
  --build-arg NASM_SHA256="$NASM_SHA256" \
  --build-arg OPUS_SHA256="$OPUS_SHA256" \
  --build-arg LAME_SHA256="$LAME_SHA256" \
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
docker cp "$CONTAINER_ID:/build/bin/." "$ARTIFACT_DIR/bin/" || {
  echo "WARNING: Failed to extract bin/, may not exist in this build type"
}

# Extract libraries
echo "Extracting lib/..."
docker cp "$CONTAINER_ID:/build/lib/." "$ARTIFACT_DIR/lib/" || {
  echo "ERROR: Failed to extract lib/"
  docker rm "$CONTAINER_ID"
  exit 1
}

# Extract headers
echo "Extracting include/..."
docker cp "$CONTAINER_ID:/build/include/." "$ARTIFACT_DIR/include/" || {
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
ls -lh "$ARTIFACT_DIR"/bin/* 2>/dev/null || echo "No binaries"
echo ""
echo "Libraries:"
ls -lh "$ARTIFACT_DIR"/lib/*.a 2>/dev/null | head -5 || echo "No static libraries"
echo ""

# Run verification
echo "Running verification..."
"$SCRIPT_DIR/verify.sh" "$PLATFORM"

echo ""
echo "✓ Linux build succeeded: $PLATFORM"
