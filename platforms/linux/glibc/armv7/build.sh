#!/usr/bin/env bash
#
# Linux armv7 glibc FFmpeg Build
#
# Uses toolchain-only Docker image with mounted build scripts.
# Toolchain image is cached; rebuilds only when toolchain changes.
#
# Usage: ./platforms/linux/glibc/armv7/build.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
LINUX_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

PLATFORM="linux-armv7-glibc"
DOCKER_PLATFORM="linux/arm/v7"
DOCKER_IMAGE="ffmpeg-toolchain:glibc"
DOCKERFILE="$LINUX_DIR/toolchain/glibc.Dockerfile"

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
    -e OPENSSL_TARGET="linux-armv4" \
    -v "$LINUX_DIR:/src:ro" \
    -v "$PROJECT_ROOT/artifacts/$PLATFORM:/build" \
    "$DOCKER_IMAGE" \
    /src/build-inside-container.sh

echo ""
echo "=========================================="
echo "Build Complete: $PLATFORM"
echo "=========================================="
echo "Output: $PROJECT_ROOT/artifacts/$PLATFORM"
