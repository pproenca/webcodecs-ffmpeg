#!/usr/bin/env bash
#
# Linux x64 glibc FFmpeg Build (Docker)
#
# Usage: ./platforms/linux/glibc/x64/build.sh
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
LINUX_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

PLATFORM="linux-x64-glibc"
DOCKER_PLATFORM="linux/amd64"
DOCKER_IMAGE="ffmpeg-builder:$PLATFORM"

echo "=========================================="
echo "Docker Build: $PLATFORM"
echo "=========================================="

# Build Docker image
docker buildx build \
    --platform "$DOCKER_PLATFORM" \
    --tag "$DOCKER_IMAGE" \
    --file "$SCRIPT_DIR/Dockerfile" \
    --load \
    "$LINUX_DIR"

# Extract artifacts
CONTAINER_ID=$(docker create "$DOCKER_IMAGE")
mkdir -p "$PROJECT_ROOT/artifacts/$PLATFORM"
docker cp "$CONTAINER_ID:/build/bin" "$PROJECT_ROOT/artifacts/$PLATFORM/"
docker cp "$CONTAINER_ID:/build/lib" "$PROJECT_ROOT/artifacts/$PLATFORM/"
docker cp "$CONTAINER_ID:/build/include" "$PROJECT_ROOT/artifacts/$PLATFORM/"
docker rm "$CONTAINER_ID"

echo ""
echo "=========================================="
echo "Build Complete: $PLATFORM"
echo "=========================================="
echo "Output: $PROJECT_ROOT/artifacts/$PLATFORM"
