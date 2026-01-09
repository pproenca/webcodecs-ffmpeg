#!/usr/bin/env bash
# =============================================================================
# FFmpeg Build Entry Point for linux-x64
# =============================================================================
# This script is the entry point for Linux x64 builds.
# It runs inside the Docker container and invokes the Makefile.
#
# For Docker-based builds (recommended), use:
#   ./docker/build.sh linux-x64 [target]
#
# This script can also run directly on a Linux x64 system with build tools.
#
# Usage:
#   ./build.sh              # Build everything
#   ./build.sh codecs       # Build only codecs
#   ./build.sh clean        # Clean build directory
#   ./build.sh help         # Show help
# =============================================================================

set -euo pipefail

# Resolve script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
readonly SCRIPT_DIR PROJECT_ROOT

# Source shared libraries
source "${PROJECT_ROOT}/scripts/lib/logging.sh"
source "${PROJECT_ROOT}/scripts/lib/common.sh"

# =============================================================================
# Platform Configuration
# =============================================================================

readonly PLATFORM="linux-x64"
readonly EXPECTED_ARCH="x86-64"

# =============================================================================
# Platform Verification
# =============================================================================

verify_platform() {
  log_step "Verifying platform..."

  if [[ "$(uname -s)" != "Linux" ]]; then
    log_error "This script must run on Linux"
    log_error "Use ./docker/build.sh ${PLATFORM} for Docker-based builds"
    exit 1
  fi

  local arch
  arch="$(uname -m)"
  if [[ "$arch" != "x86_64" ]]; then
    log_error "This script must run on x86_64"
    log_error "Detected architecture: $arch"
    exit 1
  fi

  log_info "Platform verified: ${PLATFORM}"
}

# =============================================================================
# Dependency Check
# =============================================================================

check_dependencies() {
  log_step "Checking build dependencies..."

  local missing=()
  local tools=(gcc g++ make cmake meson ninja nasm pkg-config autoconf automake libtool)

  for tool in "${tools[@]}"; do
    if ! command -v "$tool" &>/dev/null; then
      missing+=("$tool")
    fi
  done

  if [[ ${#missing[@]} -gt 0 ]]; then
    log_error "Missing build tools: ${missing[*]}"
    log_error "Install them or use Docker: ./docker/build.sh ${PLATFORM}"
    exit 1
  fi

  log_info "All build tools available"

  # Show versions
  log_info "Tool versions:"
  echo "  gcc:     $(gcc --version | head -1)"
  echo "  cmake:   $(cmake --version | head -1)"
  echo "  meson:   $(meson --version)"
  echo "  nasm:    $(nasm --version)"
}

# =============================================================================
# Build Execution
# =============================================================================

run_build() {
  local target="${1:-all}"
  local debug="${DEBUG:-}"

  local license
  license="$(normalize_license "${LICENSE:-free}")" || exit 1

  log_step "Starting build..."
  log_info "Target: ${target}"
  log_info "License tier: ${license}"
  [[ -n "$debug" ]] && log_info "Debug mode: enabled"

  cd "${SCRIPT_DIR}"
  make -j LICENSE="${license}" DEBUG="${debug}" "${target}"
}

# =============================================================================
# Main
# =============================================================================

main() {
  local target="${1:-all}"
  local license="${LICENSE:-free}"

  echo ""
  echo "=========================================="
  echo " FFmpeg Build for ${PLATFORM}"
  echo " License tier: ${license}"
  echo "=========================================="
  echo ""

  if [[ "$target" == "help" ]] || [[ "$target" == "-h" ]] || [[ "$target" == "--help" ]]; then
    cd "${SCRIPT_DIR}"
    make LICENSE="${license}" help
    exit 0
  fi

  verify_platform
  check_dependencies
  run_build "$target"

  echo ""
  log_info "Build completed successfully!"

  if [[ "$target" == "all" ]] || [[ "$target" == "package" ]]; then
    # Normalize license for artifacts path
    local normalized_license
    normalized_license="$(normalize_license "${license}")" || exit 1
    local artifacts_dir="${PROJECT_ROOT}/artifacts/${PLATFORM}-${normalized_license}"

    echo ""
    log_info "Artifacts location: ${artifacts_dir}/"
    ls -la "${artifacts_dir}/bin/" 2>/dev/null || true

    # Verify binary architecture matches target
    if ! verify_binary_arch "${artifacts_dir}/bin/ffmpeg" "${EXPECTED_ARCH}"; then
      exit 1
    fi
  fi
}

main "$@"
