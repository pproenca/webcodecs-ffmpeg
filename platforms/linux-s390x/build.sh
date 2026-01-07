#!/usr/bin/env bash
# =============================================================================
# FFmpeg Build Script - linux-s390x
# =============================================================================
# Builds FFmpeg and dependencies for Debian (glibc, s390x - IBM Z)
# Uses QEMU emulation when running on non-s390x hosts
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Default values
LICENSE_TIER="${LICENSE_TIER:-gpl}"
BUILD_DIR="${BUILD_DIR:-${SCRIPT_DIR}/build}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS] [TARGET]

Options:
    -l, --license TIER    License tier: bsd, lgpl, gpl (default: gpl)
    -h, --help            Show this help message

Targets:
    all                   Build everything (default)
    codecs                Build codec libraries only
    ffmpeg                Build FFmpeg only
    package               Create distribution package
    clean                 Clean build artifacts

Environment:
    LICENSE_TIER          Same as --license option
    BUILD_DIR             Override build directory

Examples:
    ./build.sh                      # Full GPL build
    ./build.sh -l lgpl              # LGPL build
    ./build.sh codecs               # Build codecs only
    LICENSE_TIER=bsd ./build.sh     # BSD-only build
EOF
}

# Parse arguments
TARGET="all"
while [[ $# -gt 0 ]]; do
    case "$1" in
        -l|--license)
            LICENSE_TIER="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            TARGET="$1"
            shift
            ;;
    esac
done

# Validate license tier
case "${LICENSE_TIER}" in
    bsd|lgpl|gpl) ;;
    *)
        log_error "Invalid license tier: ${LICENSE_TIER}"
        log_error "Valid options: bsd, lgpl, gpl"
        exit 1
        ;;
esac

log_info "Platform: linux-s390x"
log_info "License tier: ${LICENSE_TIER}"
log_info "Build directory: ${BUILD_DIR}"

# Check if running inside Docker container
if [[ -f /.dockerenv ]] || grep -q docker /proc/1/cgroup 2>/dev/null; then
    log_info "Running inside Docker container"
    exec make -C "${SCRIPT_DIR}" \
        LICENSE_TIER="${LICENSE_TIER}" \
        BUILD_DIR="${BUILD_DIR}" \
        "${TARGET}"
fi

# Build Docker image with QEMU emulation support
IMAGE_NAME="ffmpeg-linux-s390x"
log_info "Building Docker image: ${IMAGE_NAME} (s390x with QEMU)"

# Ensure QEMU is available for s390x emulation
if ! docker buildx inspect --bootstrap >/dev/null 2>&1; then
    log_info "Setting up Docker buildx for multi-platform support..."
    docker run --rm --privileged multiarch/qemu-user-static --reset -p yes
fi

docker build --platform linux/s390x -t "${IMAGE_NAME}" "${SCRIPT_DIR}"

# Run build in Docker with QEMU emulation
log_info "Running build in Docker container (s390x via QEMU)..."
docker run --rm \
    --platform linux/s390x \
    -v "${REPO_ROOT}:/build/ffmpeg-prebuilds:rw" \
    -e LICENSE_TIER="${LICENSE_TIER}" \
    -e BUILD_DIR="/build/ffmpeg-prebuilds/platforms/linux-s390x/build" \
    -w "/build/ffmpeg-prebuilds/platforms/linux-s390x" \
    "${IMAGE_NAME}" \
    make LICENSE_TIER="${LICENSE_TIER}" "${TARGET}"

log_info "Build complete!"
