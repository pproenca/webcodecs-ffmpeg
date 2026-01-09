#!/usr/bin/env bash
# =============================================================================
# FFmpeg Build Entry Point for darwin-arm64
# =============================================================================
# This script is the main entry point for CI/CD and local builds.
# It installs dependencies and invokes the Makefile.
#
# Usage:
#   ./build.sh              # Build everything
#   ./build.sh codecs       # Build only codecs
#   ./build.sh clean        # Clean build directory
#   ./build.sh help         # Show help
# =============================================================================

set -euo pipefail

# Resolve script directory with error handling
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" || {
  echo "ERROR: Failed to determine script directory" >&2
  exit 1
}
readonly SCRIPT_DIR

PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)" || {
  echo "ERROR: Failed to determine project root" >&2
  exit 1
}
readonly PROJECT_ROOT

# Source shared libraries
source "${PROJECT_ROOT}/scripts/lib/logging.sh"
source "${PROJECT_ROOT}/scripts/lib/common.sh"

# =============================================================================
# Platform Configuration
# =============================================================================

readonly PLATFORM="darwin-arm64"
readonly EXPECTED_ARCH="arm64"

# =============================================================================
# Platform Verification
# =============================================================================

verify_platform() {
  log_step "Verifying platform..."

  if [[ "$(uname -s)" != "Darwin" ]]; then
    log_error "This script must run on macOS"
    exit 1
  fi

  local arch
  arch="$(uname -m)"
  if [[ "$arch" != "arm64" ]]; then
    log_error "This script must run on ARM64 (Apple Silicon)"
    log_error "Detected architecture: $arch"
    exit 1
  fi

  log_info "Platform verified: ${PLATFORM}"
}

# =============================================================================
# Dependency Installation
# =============================================================================

install_dependencies() {
  log_step "Checking build dependencies..."

  if ! command -v brew &>/dev/null; then
    log_error "Homebrew is required but not installed"
    log_error "Install it from: https://brew.sh"
    exit 1
  fi

  local tools=(
    nasm       # Assembler for x264 and others
    meson      # Build system for dav1d
    ninja      # Build tool for meson
    pkg-config # Library configuration
    autoconf   # Build system for autotools projects
    automake   # Build system for autotools projects
    libtool    # Build system for autotools projects
  )

  local missing_tools=()
  local tool

  for tool in "${tools[@]}"; do
    if ! command -v "$tool" &>/dev/null; then
      missing_tools+=("$tool")
    fi
  done

  if [[ ${#missing_tools[@]} -gt 0 ]]; then
    log_info "Installing missing tools: ${missing_tools[*]}"
    brew install "${missing_tools[@]}"
  else
    log_info "All build tools are installed"
  fi

  # Install CMake 3.x via pip (CMake 4.x breaks x265, libaom, svt-av1 builds)
  install_cmake_3x

  # Show tool versions
  log_info "Tool versions:"
  echo "  nasm:     $(nasm --version | head -1)"
  echo "  cmake:    $(cmake --version | head -1) ($(which cmake))"
  echo "  meson:    $(meson --version)"
  echo "  ninja:    $(ninja --version)"
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
  [[ -n "$debug" ]] && log_info "Debug mode: enabled (showing all warnings)"

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
  install_dependencies
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
