#!/usr/bin/env bash
# =============================================================================
# FFmpeg Build Entry Point for darwin-x64
# =============================================================================
# This script is the main entry point for CI/CD and local builds.
# It installs dependencies and invokes the Makefile.
# Cross-compiles from ARM64 runners using -arch x86_64.
#
# Usage:
#   ./build.sh              # Build everything
#   ./build.sh codecs       # Build only codecs
#   ./build.sh clean        # Clean build directory
#   ./build.sh help         # Show help
#
# Environment:
#   LICENSE: Build license tier (free, non-free). Default: free
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
readonly SCRIPT_DIR PROJECT_ROOT

# Source shared libraries
source "${PROJECT_ROOT}/scripts/lib/logging.sh"
source "${PROJECT_ROOT}/scripts/lib/common.sh"

# =============================================================================
# Platform Configuration
# =============================================================================

readonly PLATFORM="darwin-x64"
readonly EXPECTED_ARCH="x86_64"

# =============================================================================
# Platform Verification
# =============================================================================

verify_platform() {
  log_step "Verifying platform..."

  if [[ "$(uname -s)" != "Darwin" ]]; then
    log_error "This script must run on macOS"
    exit 1
  fi

  # Note: We don't check for x86_64 architecture because we cross-compile
  # from ARM64 runners using -arch x86_64 flags
  log_info "Platform verified: macOS (cross-compiling to x86_64)"
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

  local -a tools=(
    meson      # Build system for dav1d
    ninja      # Build tool for meson
    pkg-config # Library configuration
    autoconf   # Build system for autotools projects
    automake   # Build system for autotools projects
    libtool    # Build system for autotools projects
  )

  local -a missing_tools=()
  local tool

  for tool in "${tools[@]}"; do
    if ! command -v "${tool}" &>/dev/null; then
      missing_tools+=("${tool}")
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

  # Install NASM 2.x from source (NASM 3.x breaks libaom multipass optimization)
  install_nasm

  # Show tool versions
  log_info "Tool versions:"
  echo "  nasm:     $(nasm --version | head -1)"
  echo "  cmake:    $(cmake --version | head -1) ($(command -v cmake))"
  echo "  meson:    $(meson --version)"
  echo "  ninja:    $(ninja --version)"
}

# Install NASM 2.x from source (NASM 3.x breaks libaom multipass optimization check)
# See: https://www.linuxfromscratch.org/blfs/view/svn/multimedia/libaom.html
install_nasm() {
  local nasm_version
  nasm_version="$(nasm --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+' | head -1 || echo "0.0")"
  local nasm_major="${nasm_version%%.*}"

  if [[ "${nasm_major}" -ge 3 ]] || ! command -v nasm &>/dev/null; then
    log_info "Building NASM 2.16.03 from source (NASM 3.x incompatible with libaom)..."
    local nasm_src="${PROJECT_ROOT}/build/${PLATFORM}/nasm-2.16.03"
    local nasm_bin="${nasm_src}/nasm"

    if [[ ! -f "${nasm_bin}" ]]; then
      mkdir -p "${PROJECT_ROOT}/build/${PLATFORM}"
      cd "${PROJECT_ROOT}/build/${PLATFORM}"
      curl -sL "https://www.nasm.us/pub/nasm/releasebuilds/2.16.03/nasm-2.16.03.tar.gz" | tar xz
      cd nasm-2.16.03
      ./configure
      make -j"$(sysctl -n hw.ncpu)"
    fi

    # Add to PATH for this build
    export PATH="${nasm_src}:${PATH}"
    cd "${SCRIPT_DIR}"
  fi
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
  log_info "Cross-compiling to x86_64"
  [[ -n "${debug}" ]] && log_info "Debug mode: enabled (showing all warnings)"

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
  echo " (cross-compiled from ARM64)"
  echo "=========================================="
  echo ""

  if [[ "${target}" == "help" ]] || [[ "${target}" == "-h" ]] || [[ "${target}" == "--help" ]]; then
    cd "${SCRIPT_DIR}"
    make LICENSE="${license}" help
    exit 0
  fi

  verify_platform
  install_dependencies
  run_build "${target}"

  echo ""
  log_info "Build completed successfully!"

  if [[ "${target}" == "all" ]] || [[ "${target}" == "package" ]]; then
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
