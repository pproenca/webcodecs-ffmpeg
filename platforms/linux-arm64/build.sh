#!/usr/bin/env bash
# =============================================================================
# FFmpeg Build Entry Point for linux-arm64
# =============================================================================
# This script is the entry point for Linux ARM64 builds.
# Cross-compiles from x86_64 to aarch64.
#
# For Docker-based builds (recommended), use:
#   ./docker/build.sh linux-arm64 [target]
#
# This script runs inside the Docker container with cross-compilers installed.
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

readonly PLATFORM="linux-arm64"
readonly EXPECTED_ARCH="aarch64"

# =============================================================================
# Platform Verification
# =============================================================================

verify_platform() {
  log_step "Verifying build environment..."

  if [[ "$(uname -s)" != "Linux" ]]; then
    log_error "This script must run on Linux"
    log_error "Use ./docker/build.sh ${PLATFORM} for Docker-based builds"
    exit 1
  fi

  # Cross-compilation: we build ON x86_64 FOR aarch64
  local host_arch
  host_arch="$(uname -m)"
  if [[ "$host_arch" != "x86_64" ]]; then
    log_warn "Expected x86_64 host for cross-compilation"
    log_warn "Detected host architecture: $host_arch"
    # Don't exit - might be running on native ARM64 for testing
  fi

  log_info "Build environment verified"
}

# =============================================================================
# Dependency Check
# =============================================================================

check_dependencies() {
  log_step "Checking cross-compilation tools..."

  local missing=()
  local tools=(make cmake meson ninja nasm pkg-config autoconf automake libtool)

  for tool in "${tools[@]}"; do
    if ! command -v "$tool" &>/dev/null; then
      missing+=("$tool")
    fi
  done

  # Check for cross-compiler
  if ! command -v aarch64-linux-gnu-gcc &>/dev/null; then
    missing+=("aarch64-linux-gnu-gcc")
  fi

  if [[ ${#missing[@]} -gt 0 ]]; then
    log_error "Missing build tools: ${missing[*]}"
    log_error "Use Docker: ./docker/build.sh ${PLATFORM}"
    exit 1
  fi

  log_info "All cross-compilation tools available"

  # Show versions
  log_info "Tool versions:"
  echo "  cross-gcc: $(aarch64-linux-gnu-gcc --version | head -1)"
  echo "  cmake:     $(cmake --version | head -1)"
  echo "  meson:     $(meson --version)"
  echo "  nasm:      $(nasm --version)"
}

# =============================================================================
# Build Execution
# =============================================================================

run_build() {
  local target="${1:-all}"
  local debug="${DEBUG:-}"

  local license
  license="$(normalize_license "${LICENSE:-free}")" || exit 1

  log_step "Starting cross-compilation build..."
  log_info "Target: ${target}"
  log_info "License tier: ${license}"
  log_info "Host architecture: $(uname -m)"
  log_info "Target architecture: ${EXPECTED_ARCH}"
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
  echo " FFmpeg Cross-Build for ${PLATFORM}"
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
