#!/usr/bin/env bash
#
# Linux arm64 musl FFmpeg Build (fully static)
#
# Uses toolchain-only Docker image with mounted build scripts.
# Produces fully static binaries with no network support.
#
# Usage: ./platforms/linux/musl/arm64/build.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
LINUX_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

PLATFORM="linux-arm64-musl"
DOCKER_PLATFORM="linux/arm64"
DOCKER_IMAGE="ffmpeg-toolchain:musl"
DOCKERFILE="$LINUX_DIR/toolchain/musl.Dockerfile"

echo "=========================================="
echo "Building: $PLATFORM (fully static)"
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
    -e SKIP_OPENSSL=1 \
    -e STATIC_BUILD=1 \
    -v "$LINUX_DIR:/src:ro" \
    -v "$PROJECT_ROOT/artifacts/$PLATFORM:/build" \
    "$DOCKER_IMAGE" \
    /src/build-inside-container.sh

echo ""
echo "=========================================="
echo "Build Complete: $PLATFORM"
echo "=========================================="
echo "Output: $PROJECT_ROOT/artifacts/$PLATFORM"
