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

# =============================================================================
# Colors
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

log_info() { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
log_step() { echo -e "${BLUE}[STEP]${NC} $*"; }

# =============================================================================
# Platform Verification
# =============================================================================

verify_platform() {
  log_step "Verifying platform..."

  if [[ "$(uname -s)" != "Linux" ]]; then
    log_error "This script must run on Linux"
    log_error "Use ./docker/build.sh linux-x64 for Docker-based builds"
    exit 1
  fi

  local arch
  arch="$(uname -m)"
  if [[ "$arch" != "x86_64" ]]; then
    log_error "This script must run on x86_64"
    log_error "Detected architecture: $arch"
    exit 1
  fi

  log_info "Platform verified: linux-x64"
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
    log_error "Install them or use Docker: ./docker/build.sh linux-x64"
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
  local license="${LICENSE:-gpl}"
  local debug="${DEBUG:-}"

  if [[ ! "$license" =~ ^(bsd|lgpl|gpl)$ ]]; then
    log_error "Invalid LICENSE=$license. Must be: bsd, lgpl, gpl"
    exit 1
  fi

  log_step "Starting build..."
  log_info "Target: ${target}"
  log_info "License tier: ${license}"
  [[ -n "$debug" ]] && log_info "Debug mode: enabled"

  cd "${SCRIPT_DIR}"

  make -j LICENSE="${license}" DEBUG="${debug}" "${target}"
}

# =============================================================================
# Binary Architecture Verification
# =============================================================================

verify_binary_arch() {
  local binary="$1"
  local expected_arch="$2"

  if [[ ! -f "$binary" ]]; then
    log_error "Binary not found: $binary"
    exit 1
  fi

  log_step "Verifying binary architecture..."

  local file_output
  file_output="$(file "$binary")"

  if ! echo "$file_output" | grep -q "$expected_arch"; then
    log_error "Architecture mismatch!"
    log_error "Expected: $expected_arch"
    log_error "Got: $file_output"
    exit 1
  fi

  log_info "Architecture verified: $expected_arch"
}

# =============================================================================
# Main
# =============================================================================

main() {
  local target="${1:-all}"
  local license="${LICENSE:-gpl}"

  echo ""
  echo "=========================================="
  echo " FFmpeg Build for linux-x64"
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
    local artifacts_dir="${PROJECT_ROOT}/artifacts/linux-x64-${license}"
    echo ""
    log_info "Artifacts location: ${artifacts_dir}/"
    ls -la "${artifacts_dir}/bin/" 2>/dev/null || true

    verify_binary_arch "${artifacts_dir}/bin/ffmpeg" "x86-64"
  fi
}

main "$@"
