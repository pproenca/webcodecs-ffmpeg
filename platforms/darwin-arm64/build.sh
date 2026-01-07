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

# =============================================================================
# Colors (disabled when output is not a terminal)
# =============================================================================

if [[ -t 1 ]]; then
  readonly RED='\033[0;31m'
  readonly GREEN='\033[0;32m'
  readonly YELLOW='\033[1;33m'
  readonly BLUE='\033[0;34m'
  readonly NC='\033[0m'
else
  readonly RED=''
  readonly GREEN=''
  readonly YELLOW=''
  readonly BLUE=''
  readonly NC=''
fi

#######################################
# Logging functions
# Globals:
#   GREEN, YELLOW, RED, BLUE, NC
# Arguments:
#   $* - Message to log
# Outputs:
#   Writes message to stdout (or stderr for log_error)
#######################################
log_info() { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
log_step() { echo -e "${BLUE}[STEP]${NC} $*"; }

# =============================================================================
# Platform Verification
# =============================================================================

#######################################
# Verify the script is running on darwin-arm64.
# Globals:
#   None
# Arguments:
#   None
# Outputs:
#   Writes verification status to stdout
# Returns:
#   0 on success, exits with 1 on wrong platform
#######################################
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

  log_info "Platform verified: darwin-arm64"
}

# =============================================================================
# Dependency Installation
# =============================================================================

#######################################
# Check and install required build dependencies via Homebrew.
# Globals:
#   None
# Arguments:
#   None
# Outputs:
#   Writes dependency status to stdout
# Returns:
#   0 on success, exits with 1 if Homebrew missing
#######################################
install_dependencies() {
  log_step "Checking build dependencies..."

  if ! command -v brew &>/dev/null; then
    log_error "Homebrew is required but not installed"
    log_error "Install it from: https://brew.sh"
    exit 1
  fi

  # Homebrew tools (excludes cmake - installed via pip for version control)
  local tools=(
    ccache     # Compiler cache for faster rebuilds
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
  # Homebrew only provides CMake 4.x, so we use pip for version control
  install_cmake

  # Show tool versions
  log_info "Tool versions:"
  echo "  nasm:     $(nasm --version | head -1)"
  echo "  cmake:    $(cmake --version | head -1) ($(which cmake))"
  echo "  meson:    $(meson --version)"
  echo "  ninja:    $(ninja --version)"
}

#######################################
# Install CMake 3.x via pip.
# CMake 4.x is incompatible with upstream codec builds (x265, libaom, svt-av1).
# Globals:
#   None
# Arguments:
#   None
# Outputs:
#   Writes installation status to stdout
#######################################
install_cmake() {
  local cmake_version
  cmake_version="$(cmake --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "0.0.0")"
  local cmake_major="${cmake_version%%.*}"

  if [[ "$cmake_major" -ge 4 ]] || ! command -v cmake &>/dev/null; then
    log_info "Installing CMake 3.x via pip (CMake 4.x incompatible with codec builds)..."
    pip3 install --quiet --break-system-packages 'cmake>=3.20,<4'
  fi
}

# =============================================================================
# Build Execution
# =============================================================================

#######################################
# Execute the build via Make.
# Globals:
#   SCRIPT_DIR
#   LICENSE (env var, optional)
# Arguments:
#   $1 - Build target (default: all)
# Outputs:
#   Writes build progress to stdout
# Returns:
#   0 on success, exits with 1 on invalid license
#######################################
run_build() {
  local target="${1:-all}"
  local license="${LICENSE:-gpl}"
  local debug="${DEBUG:-}"

  if [[ ! "$license" =~ ^(bsd|lgpl|gpl)$ ]]; then
    log_error "Invalid LICENSE=$license. Must be: bsd, lgpl, gpl"
    exit 1
  fi

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

#######################################
# Main entry point.
# Globals:
#   SCRIPT_DIR, PROJECT_ROOT
#   LICENSE (env var, optional)
# Arguments:
#   $1 - Build target (default: all)
# Outputs:
#   Writes build progress and results to stdout
#######################################
main() {
  local target="${1:-all}"
  local license="${LICENSE:-gpl}"

  echo ""
  echo "=========================================="
  echo " FFmpeg Build for darwin-arm64"
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
    local artifacts_dir="${PROJECT_ROOT}/artifacts/darwin-arm64-${license}"
    echo ""
    log_info "Artifacts location: ${artifacts_dir}/"
    ls -la "${artifacts_dir}/bin/" 2>/dev/null || true

    # Verify binary architecture matches target
    verify_binary_arch "${artifacts_dir}/bin/ffmpeg" "arm64"
  fi
}

# =============================================================================
# Binary Architecture Verification
# =============================================================================

#######################################
# Verify a binary matches the expected architecture.
# Catches cross-compilation failures where host arch leaks into output.
# Globals:
#   None
# Arguments:
#   $1 - Path to binary file
#   $2 - Expected architecture (e.g., "arm64")
# Outputs:
#   Writes verification status to stdout
# Returns:
#   0 on success, exits with 1 on mismatch or missing binary
#######################################
verify_binary_arch() {
  local binary="$1"
  local expected_arch="$2"

  if [[ ! -f "$binary" ]]; then
    log_error "Binary not found for architecture verification: $binary"
    exit 1
  fi

  log_step "Verifying binary architecture..."

  local file_output
  file_output="$(file "$binary")"

  if ! echo "$file_output" | grep -q "$expected_arch"; then
    log_error "Architecture mismatch detected!"
    log_error "Expected: $expected_arch"
    log_error "Got: $file_output"
    exit 1
  fi

  log_info "Architecture verified: $expected_arch"
}

main "$@"
