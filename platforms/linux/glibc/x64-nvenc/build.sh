#!/usr/bin/env bash
#
# Linux x64 glibc FFmpeg Build with NVENC support
#
# Uses toolchain-only Docker image with mounted build scripts.
# NVENC variant includes NVIDIA codec SDK headers.
#
# Usage: ./platforms/linux/glibc/x64-nvenc/build.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
LINUX_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

PLATFORM="linux-x64-glibc-nvenc"
DOCKER_PLATFORM="linux/amd64"
DOCKER_IMAGE="ffmpeg-toolchain:glibc-nvenc"
DOCKERFILE="$LINUX_DIR/toolchain/glibc-nvenc.Dockerfile"

echo "=========================================="
echo "Building: $PLATFORM"
echo "=========================================="

# Step 1: Build toolchain image (cached if unchanged)
echo ">>> Building toolchain image (cached if Dockerfile unchanged)..."
docker buildx build \
    --platform "$DOCKER_PLATFORM" \
    --tag "$DOCKER_IMAGE" \
    --file "$DOCKERFILE" \
    --load \
    "$LINUX_DIR/toolchain"

# Step 2: Run build with mounted source
echo ">>> Running build inside container..."
mkdir -p "$PROJECT_ROOT/artifacts/$PLATFORM"

docker run --rm \
    --platform "$DOCKER_PLATFORM" \
    -e PLATFORM="$PLATFORM" \
    -e OPENSSL_TARGET="linux-x86_64" \
    -e FFMPEG_FLAGS_FILE="/src/glibc/x64-nvenc/ffmpeg-flags.sh" \
    -v "$LINUX_DIR:/src:ro" \
    -v "$PROJECT_ROOT/artifacts/$PLATFORM:/build" \
    "$DOCKER_IMAGE" \
    /src/build-inside-container.sh

echo ""
echo "=========================================="
echo "Build Complete: $PLATFORM"
echo "=========================================="
echo "Output: $PROJECT_ROOT/artifacts/$PLATFORM"
