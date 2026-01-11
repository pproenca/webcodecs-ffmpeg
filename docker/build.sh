#!/usr/bin/env bash
# =============================================================================
# Docker Build Helper for Linux Platforms
# =============================================================================
# This script orchestrates Docker-based builds for Linux platforms.
#
# Usage:
#   ./docker/build.sh linux-x64 [target] [LICENSE=free]
#   ./docker/build.sh linux-arm64 [target] [LICENSE=free]
#
# Examples:
#   ./docker/build.sh linux-x64              # Full build with free license
#   ./docker/build.sh linux-x64 codecs       # Build only codecs
#   ./docker/build.sh linux-arm64 all non-free   # Build with non-free license (GPL)
#
# Environment:
#   LICENSE - License tier (free, non-free). Default: free
#   DEBUG   - Enable debug output
# =============================================================================

set -euo pipefail

# Resolve script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
readonly SCRIPT_DIR PROJECT_ROOT

# Source shared libraries
source "${PROJECT_ROOT}/scripts/lib/logging.sh"
source "${PROJECT_ROOT}/scripts/lib/common.sh"

# =============================================================================
# Configuration
# =============================================================================

PLATFORM="${1:-}"
TARGET="${2:-all}"
LICENSE="${LICENSE:-free}"

# Validate platform
if [[ -z "$PLATFORM" ]]; then
  log_error "Usage: $0 <platform> [target] [LICENSE=tier]"
  log_error "Platforms: linux-x64, linux-arm64, linuxmusl-x64"
  exit 1
fi

case "$PLATFORM" in
  linux-x64)
    DOCKER_FILE="Dockerfile.linux"
    DOCKER_TARGET="builder-x64"
    EXPECTED_ARCH="x86-64"
    ;;
  linux-arm64)
    DOCKER_FILE="Dockerfile.linux"
    DOCKER_TARGET="builder-arm64"
    EXPECTED_ARCH="aarch64"
    ;;
  linuxmusl-x64)
    DOCKER_FILE="Dockerfile.linux-musl"
    DOCKER_TARGET="builder-x64"
    EXPECTED_ARCH="x86-64"
    ;;
  *)
    log_error "Unknown platform: $PLATFORM"
    log_error "Supported platforms: linux-x64, linux-arm64, linuxmusl-x64"
    exit 1
    ;;
esac

# Normalize license
LICENSE="$(normalize_license "$LICENSE")" || exit 1

# =============================================================================
# Docker Functions
# =============================================================================

check_docker() {
  if ! command -v docker &>/dev/null; then
    log_error "Docker is not installed"
    log_error "Install Docker from: https://docs.docker.com/get-docker/"
    exit 1
  fi

  if ! docker info &>/dev/null; then
    log_error "Docker daemon is not running"
    exit 1
  fi
}

build_image() {
  local image_name="ffmpeg-build:${PLATFORM}"

  log_step "Building Docker image: ${image_name}"

  docker build \
    --file "${SCRIPT_DIR}/${DOCKER_FILE}" \
    --target "${DOCKER_TARGET}" \
    --tag "${image_name}" \
    "${PROJECT_ROOT}"
}

run_docker_build() {
  local image_name="ffmpeg-build:${PLATFORM}"

  log_step "Running build in container..."
  log_info "Platform: ${PLATFORM}"
  log_info "Target: ${TARGET}"
  log_info "License: ${LICENSE}"

  docker run --rm \
    -v "${PROJECT_ROOT}:/build:rw" \
    -e "LICENSE=${LICENSE}" \
    -e "DEBUG=${DEBUG:-}" \
    -w "/build" \
    "${image_name}" \
    make -C "/build/platforms/${PLATFORM}" LICENSE="${LICENSE}" "${TARGET}"
}

verify_docker_build() {
  local artifacts_dir="${PROJECT_ROOT}/artifacts/${PLATFORM}-${LICENSE}"
  local ffmpeg_bin="${artifacts_dir}/bin/ffmpeg"

  if [[ ! -f "$ffmpeg_bin" ]]; then
    log_error "Build failed: ffmpeg binary not found"
    exit 1
  fi

  log_step "Verifying build..."

  if ! verify_binary_arch "$ffmpeg_bin" "$EXPECTED_ARCH"; then
    exit 1
  fi

  # Verify static linking (only libc, libm, libpthread should be dynamic)
  log_step "Checking dynamic dependencies..."
  if command -v ldd &>/dev/null && [[ "$PLATFORM" == "linux-x64" ]]; then
    ldd "$ffmpeg_bin" || true
  fi

  log_info "Build verified successfully"
}

# =============================================================================
# Main
# =============================================================================

main() {
  echo ""
  echo "=========================================="
  echo " FFmpeg Docker Build for ${PLATFORM}"
  echo " License tier: ${LICENSE}"
  echo "=========================================="
  echo ""

  check_docker
  build_image
  run_docker_build

  if [[ "$TARGET" == "all" ]] || [[ "$TARGET" == "package" ]]; then
    verify_docker_build

    local artifacts_dir="${PROJECT_ROOT}/artifacts/${PLATFORM}-${LICENSE}"
    echo ""
    log_info "Artifacts location: ${artifacts_dir}/"
    ls -la "${artifacts_dir}/bin/" 2>/dev/null || true
  fi

  echo ""
  log_info "Build completed successfully!"
}

main
