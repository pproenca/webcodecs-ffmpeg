#!/usr/bin/env bash
#
# Linux FFmpeg Build Script (Docker-based)
#
# Builds FFmpeg and all codec dependencies inside Docker containers for
# maximum reproducibility and isolation. Uses docker buildx for multi-arch
# support (x64, arm64, armv7).
#
# Supported platforms:
#   linux-x64-glibc    - Linux x64 with glibc
#   linux-x64-musl     - Linux x64 with musl (fully static)
#   linux-arm64-glibc  - Linux ARM64 with glibc
#   linux-arm64-musl   - Linux ARM64 with musl
#   linux-armv7-glibc  - Linux ARMv7 with glibc
#
# Usage: Called from orchestrator.sh, not directly

set -euo pipefail


#######################################
# Constants
#######################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
readonly PROJECT_ROOT
PLATFORM="${1:-}"

#######################################
# Validate platform argument
#######################################

if [[ -z "$PLATFORM" ]]; then
  echo "ERROR: Platform argument required"
  exit 1
fi

echo "=========================================="
echo "Linux Docker Build: $PLATFORM"
echo "=========================================="


#######################################
# Determine Docker architecture
#######################################
case "$PLATFORM" in
  linux-x64-glibc|linux-x64-musl)
    DOCKER_PLATFORM="linux/amd64"
    ;;
  linux-arm64-glibc|linux-arm64-musl)
    DOCKER_PLATFORM="linux/arm64"
    ;;
  linux-armv7-glibc)
    DOCKER_PLATFORM="linux/arm/v7"
    ;;
  *)
    echo "ERROR: Invalid Linux platform '$PLATFORM'"
    echo "Supported: linux-x64-glibc, linux-x64-musl," \
         "linux-arm64-glibc, linux-arm64-musl, linux-armv7-glibc"
    exit 1
    ;;
esac

DOCKERFILE="$PROJECT_ROOT/platforms/$PLATFORM/Dockerfile"
readonly DOCKERFILE
IMAGE_TAG="ffmpeg-builder:$PLATFORM"
readonly IMAGE_TAG

if [[ ! -f "$DOCKERFILE" ]]; then
  echo "ERROR: Dockerfile not found: $DOCKERFILE"
  exit 1
fi

echo "Dockerfile: $DOCKERFILE"
echo "Image tag:  $IMAGE_TAG"
echo ""


#######################################
# Build Docker image
#######################################

# Pass all codec versions as build args to the Dockerfile.
echo "Building Docker image for $DOCKER_PLATFORM (may take 20-40 min)..."
docker buildx build \
  --platform "$DOCKER_PLATFORM" \
  --build-arg FFMPEG_VERSION="$FFMPEG_VERSION" \
  --build-arg X264_VERSION="$X264_VERSION" \
  --build-arg X265_VERSION="$X265_VERSION" \
  --build-arg LIBVPX_VERSION="$LIBVPX_VERSION" \
  --build-arg LIBAOM_VERSION="$LIBAOM_VERSION" \
  --build-arg OPUS_VERSION="$OPUS_VERSION" \
  --build-arg OPUS_SHA256="$OPUS_SHA256" \
  --build-arg LAME_VERSION="$LAME_VERSION" \
  --build-arg LAME_SHA256="$LAME_SHA256" \
  --build-arg THEORA_VERSION="$THEORA_VERSION" \
  --build-arg THEORA_SHA256="$THEORA_SHA256" \
  --build-arg XVID_VERSION="$XVID_VERSION" \
  --build-arg XVID_SHA256="$XVID_SHA256" \
  --build-arg FLAC_VERSION="$FLAC_VERSION" \
  --build-arg FLAC_SHA256="$FLAC_SHA256" \
  --build-arg SPEEX_VERSION="$SPEEX_VERSION" \
  --build-arg SPEEX_SHA256="$SPEEX_SHA256" \
  --build-arg LIBASS_VERSION="$LIBASS_VERSION" \
  --build-arg LIBASS_SHA256="$LIBASS_SHA256" \
  --build-arg FREETYPE_VERSION="$FREETYPE_VERSION" \
  --build-arg FREETYPE_SHA256="$FREETYPE_SHA256" \
  --build-arg VORBIS_VERSION="$VORBIS_VERSION" \
  --build-arg OGG_VERSION="$OGG_VERSION" \
  --build-arg NASM_VERSION="$NASM_VERSION" \
  --build-arg NASM_SHA256="$NASM_SHA256" \
  --build-arg DAV1D_VERSION="$DAV1D_VERSION" \
  --build-arg DAV1D_URL="$DAV1D_URL" \
  --build-arg DAV1D_SHA256="$DAV1D_SHA256" \
  --build-arg OPENSSL_VERSION="$OPENSSL_VERSION" \
  --build-arg OPENSSL_URL="$OPENSSL_URL" \
  --build-arg OPENSSL_SHA256="$OPENSSL_SHA256" \
  --build-arg FDKAAC_VERSION="$FDKAAC_VERSION" \
  --build-arg RAV1E_VERSION="$RAV1E_VERSION" \
  --build-arg SVTAV1_VERSION="$SVTAV1_VERSION" \
  --cache-from type=gha,scope="$PLATFORM" \
  --cache-to type=gha,mode=max,scope="$PLATFORM" \
  -f "$DOCKERFILE" \
  -t "$IMAGE_TAG" \
  --load \
  "$PROJECT_ROOT"

#######################################
# Extract artifacts from container
#######################################

echo ""
echo "Docker build complete. Extracting artifacts..."

# Create a temporary container to copy files from the built image.
CONTAINER_ID="ffmpeg-extract-$PLATFORM-$$"
docker create --name "$CONTAINER_ID" "$IMAGE_TAG"

ARTIFACT_DIR="$PROJECT_ROOT/artifacts/$PLATFORM"
rm -rf "$ARTIFACT_DIR"
mkdir -p "$ARTIFACT_DIR"/{bin,lib,include}

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

docker rm "$CONTAINER_ID"


#######################################
# Display results and verify
#######################################

echo ""
echo "=========================================="
echo "Build Complete: $PLATFORM"
echo "=========================================="
echo "Artifacts: $ARTIFACT_DIR"
echo ""
ls -lh "$ARTIFACT_DIR"/bin/* 2>/dev/null || echo "No binaries"
echo ""
echo "Libraries:"
find "$ARTIFACT_DIR/lib" -name "*.a" -type f -exec ls -lh {} + 2>/dev/null \
  | head -5 || echo "No static libraries"
echo ""
echo "Running verification..."
"$SCRIPT_DIR/verify.sh" "$PLATFORM"

echo ""
echo "✓ Linux build succeeded: $PLATFORM"
