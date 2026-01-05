#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
WINDOWS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

PLATFORM="windows-x64"
DOCKER_PLATFORM="linux/amd64"
DOCKER_IMAGE="ffmpeg-builder:$PLATFORM"

echo "=========================================="
echo "Docker Build: $PLATFORM"
echo "=========================================="

docker buildx build \
    --platform "$DOCKER_PLATFORM" \
    --tag "$DOCKER_IMAGE" \
    --file "$SCRIPT_DIR/Dockerfile" \
    --load \
    "$WINDOWS_DIR"

CONTAINER_ID=$(docker create "$DOCKER_IMAGE")
mkdir -p "$PROJECT_ROOT/artifacts/$PLATFORM"
docker cp "$CONTAINER_ID:/build/bin" "$PROJECT_ROOT/artifacts/$PLATFORM/"
docker cp "$CONTAINER_ID:/build/lib" "$PROJECT_ROOT/artifacts/$PLATFORM/"
docker cp "$CONTAINER_ID:/build/include" "$PROJECT_ROOT/artifacts/$PLATFORM/"
docker rm "$CONTAINER_ID"

echo "Build Complete: $PROJECT_ROOT/artifacts/$PLATFORM"
