#!/usr/bin/env bash
# =============================================================================
# build.sh - Build FFmpeg for linux-arm64v8 using Docker with QEMU
# =============================================================================
#
# Usage:
#   ./build.sh [target]        - Run build (uses Docker if on host)
#   ./build.sh all             - Full build (codecs + FFmpeg + package)
#   LICENSE=bsd ./build.sh all - Build BSD tier only
#
# Environment:
#   LICENSE - License tier: bsd, lgpl, gpl (default: gpl)
#   DEBUG   - Enable debug output: 1 (default: empty)
#
# Note: This build uses QEMU for ARM64 emulation when run on x64 hosts.
# =============================================================================

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
readonly PLATFORM="linux-arm64v8"

# =============================================================================
# Logging
# =============================================================================

log_info() {
  printf "\033[0;32m[INFO]\033[0m %s\n" "$*"
}

log_warn() {
  printf "\033[1;33m[WARN]\033[0m %s\n" "$*"
}

log_error() {
  printf "\033[0;31m[ERROR]\033[0m %s\n" "$*" >&2
}

# =============================================================================
# Docker Detection
# =============================================================================

in_docker() {
  [[ -f /.dockerenv ]] || grep -q docker /proc/1/cgroup 2>/dev/null || [[ -f /run/.containerenv ]]
}

# =============================================================================
# Build Functions
# =============================================================================

build_in_docker() {
  local target="${1:-all}"
  local license="${LICENSE:-gpl}"
  local debug="${DEBUG:-}"

  log_info "Building ${PLATFORM} (${license} tier) in Docker with QEMU..."
  log_info "Project root: ${PROJECT_ROOT}"

  # Build Docker image (will use QEMU for ARM64 emulation)
  log_info "Building Docker image for ${PLATFORM}..."
  docker build \
    --platform linux/arm64 \
    -t "ffmpeg-builder:${PLATFORM}" \
    -f "${SCRIPT_DIR}/Dockerfile" \
    "${PROJECT_ROOT}"

  # Create output directories on host
  mkdir -p "${PROJECT_ROOT}/artifacts"
  mkdir -p "${PROJECT_ROOT}/build/${PLATFORM}"

  # Run build in container
  log_info "Running build in container (QEMU emulation)..."
  docker run --rm \
    --platform linux/arm64 \
    -v "${PROJECT_ROOT}:/build:rw" \
    -e "LICENSE=${license}" \
    -e "DEBUG=${debug}" \
    -w "/build/platforms/${PLATFORM}" \
    "ffmpeg-builder:${PLATFORM}" \
    bash -c "make -j\$(nproc) LICENSE=${license} DEBUG=${debug} ${target}"

  log_info "Build complete!"
  log_info "Artifacts: ${PROJECT_ROOT}/artifacts/${PLATFORM}-${license}/"
}

build_native() {
  local target="${1:-all}"
  local license="${LICENSE:-gpl}"
  local debug="${DEBUG:-}"

  log_info "Building ${PLATFORM} (${license} tier) natively..."

  cd "${SCRIPT_DIR}"
  make -j"$(nproc)" LICENSE="${license}" DEBUG="${debug}" "${target}"

  log_info "Build complete!"
  log_info "Artifacts: ${PROJECT_ROOT}/artifacts/${PLATFORM}-${license}/"
}

# =============================================================================
# Main
# =============================================================================

main() {
  local target="${1:-all}"

  log_info "FFmpeg Build for ${PLATFORM}"
  log_info "Target: ${target}"
  log_info "License: ${LICENSE:-gpl}"

  if in_docker; then
    log_info "Detected Docker environment, building natively..."
    build_native "${target}"
  else
    log_info "Running on host, using Docker for build..."
    build_in_docker "${target}"
  fi
}

main "$@"
