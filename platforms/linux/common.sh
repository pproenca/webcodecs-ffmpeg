#!/usr/bin/env bash
# Shared Linux configuration
# Sourced by glibc/*/build.sh and musl/*/build.sh

set -euo pipefail

LINUX_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly LINUX_DIR

# Load versions
source "$LINUX_DIR/versions.sh"

# Export all version variables
export FFMPEG_VERSION FFMPEG_GIT_URL
export X264_VERSION X264_GIT_URL
export X265_VERSION X265_GIT_URL
export LIBVPX_VERSION LIBVPX_GIT_URL
export LIBAOM_VERSION LIBAOM_GIT_URL
export SVTAV1_VERSION SVTAV1_GIT_URL
export DAV1D_VERSION DAV1D_URL DAV1D_SHA256
export THEORA_VERSION THEORA_URL THEORA_SHA256
export XVID_VERSION XVID_URL XVID_SHA256
export OPUS_VERSION OPUS_URL OPUS_SHA256
export LAME_VERSION LAME_URL LAME_SHA256
export VORBIS_VERSION VORBIS_URL VORBIS_SHA256
export OGG_VERSION OGG_URL OGG_SHA256
export FDKAAC_VERSION FDKAAC_GIT_URL
export FLAC_VERSION FLAC_URL FLAC_SHA256
export SPEEX_VERSION SPEEX_URL SPEEX_SHA256
export LIBASS_VERSION LIBASS_URL LIBASS_SHA256
export FREETYPE_VERSION FREETYPE_URL FREETYPE_SHA256
export NASM_VERSION NASM_URL NASM_SHA256
export OPENSSL_VERSION OPENSSL_URL OPENSSL_SHA256
export GLIBC_MIN_VERSION ALPINE_VERSION UBUNTU_VERSION

# Paths
export CODECS_DIR="$LINUX_DIR/codecs"
export PATCH_DIR="$LINUX_DIR/patches"

#######################################
# Build Docker image and extract artifacts
#######################################
docker_build_and_extract() {
    local platform="$1"
    local docker_platform="$2"
    local dockerfile="$3"
    local project_root="$4"

    local docker_image="ffmpeg-builder:$platform"

    echo "=========================================="
    echo "Docker Build: $platform"
    echo "=========================================="
    echo "Platform: $docker_platform"
    echo ""

    # Build Docker image
    docker buildx build \
        --platform "$docker_platform" \
        --tag "$docker_image" \
        --file "$dockerfile" \
        --load \
        "$LINUX_DIR"

    # Extract artifacts
    local container_id
    container_id=$(docker create "$docker_image")

    mkdir -p "$project_root/artifacts/$platform"
    docker cp "$container_id:/build/bin" "$project_root/artifacts/$platform/"
    docker cp "$container_id:/build/lib" "$project_root/artifacts/$platform/"
    docker cp "$container_id:/build/include" "$project_root/artifacts/$platform/"
    docker rm "$container_id"

    echo ""
    echo "=========================================="
    echo "Build Complete: $platform"
    echo "=========================================="
    echo "Output: $project_root/artifacts/$platform"
}
