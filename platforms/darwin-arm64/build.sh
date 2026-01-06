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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# =============================================================================
# Colors
# =============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
log_step()  { echo -e "${BLUE}[STEP]${NC} $*"; }

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

    log_info "Platform verified: darwin-arm64"
}

# =============================================================================
# Dependency Installation
# =============================================================================

install_dependencies() {
    log_step "Checking build dependencies..."

    # Check for Homebrew
    if ! command -v brew &> /dev/null; then
        log_error "Homebrew is required but not installed"
        log_error "Install it from: https://brew.sh"
        exit 1
    fi

    # Required build tools
    local tools=(
        nasm          # Assembler for x264 and others
        cmake         # Build system for x265, aom, svt-av1
        meson         # Build system for dav1d
        ninja         # Build tool for meson
        pkg-config    # Library configuration
        autoconf      # Build system for autotools projects
        automake      # Build system for autotools projects
        libtool       # Build system for autotools projects
    )

    local missing_tools=()

    for tool in "${tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            missing_tools+=("$tool")
        fi
    done

    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        log_info "Installing missing tools: ${missing_tools[*]}"
        brew install "${missing_tools[@]}"
    else
        log_info "All build tools are installed"
    fi

    # Show tool versions
    log_info "Tool versions:"
    echo "  nasm:     $(nasm --version | head -1)"
    echo "  cmake:    $(cmake --version | head -1)"
    echo "  meson:    $(meson --version)"
    echo "  ninja:    $(ninja --version)"
}

# =============================================================================
# Build Execution
# =============================================================================

run_build() {
    local target="${1:-all}"
    local jobs="${JOBS:-$(sysctl -n hw.ncpu)}"
    local license="${LICENSE:-gpl}"

    # Validate LICENSE
    if [[ ! "$license" =~ ^(bsd|lgpl|gpl)$ ]]; then
        log_error "Invalid LICENSE=$license. Must be: bsd, lgpl, gpl"
        exit 1
    fi

    log_step "Starting build..."
    log_info "Target: ${target}"
    log_info "License tier: ${license}"
    log_info "Parallel jobs: ${jobs}"

    cd "${SCRIPT_DIR}"

    # Run make with the specified target and license
    make -j"${jobs}" LICENSE="${license}" "${target}"
}

# =============================================================================
# Main
# =============================================================================

main() {
    local target="${1:-all}"
    local license="${LICENSE:-gpl}"

    echo ""
    echo "=========================================="
    echo " FFmpeg Build for darwin-arm64"
    echo " License tier: ${license}"
    echo "=========================================="
    echo ""

    # Handle help specially
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

    # Show artifacts location if we built everything
    if [[ "$target" == "all" ]] || [[ "$target" == "package" ]]; then
        local artifacts_dir="${PROJECT_ROOT}/artifacts/darwin-arm64-${license}"
        echo ""
        log_info "Artifacts location: ${artifacts_dir}/"
        ls -la "${artifacts_dir}/bin/" 2>/dev/null || true
    fi
}

main "$@"
