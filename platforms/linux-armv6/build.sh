#!/usr/bin/env bash
#
# FFmpeg Build Script - linux-armv6
#
# Builds FFmpeg and dependencies for Debian (glibc, ARMv6 - Raspberry Pi)
# Uses QEMU emulation when running on non-ARM hosts
#
# Usage:
#   ./build.sh [OPTIONS] [TARGET]
#
# Options:
#   -l, --license TIER    License tier: bsd, lgpl, gpl (default: gpl)
#   -h, --help            Show this help message
#
# Targets:
#   all                   Build everything (default)
#   codecs                Build codec libraries only
#   ffmpeg                Build FFmpeg only
#   package               Create distribution package
#   clean                 Clean build artifacts
#
# Environment:
#   LICENSE_TIER          Same as --license option
#   BUILD_DIR             Override build directory
#
# Examples:
#   ./build.sh                      # Full GPL build
#   ./build.sh -l lgpl              # LGPL build
#   ./build.sh codecs               # Build codecs only
#   LICENSE_TIER=bsd ./build.sh     # BSD-only build

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
readonly SCRIPT_DIR PROJECT_ROOT
readonly PLATFORM="linux-armv6"

# Default values
LICENSE_TIER="${LICENSE_TIER:-gpl}"
BUILD_DIR="${BUILD_DIR:-${SCRIPT_DIR}/build}"

#######################################
# Colors (disabled when output is not a terminal)
#######################################
if [[ -t 1 ]]; then
  readonly GREEN='\033[0;32m'
  readonly YELLOW='\033[1;33m'
  readonly RED='\033[0;31m'
  readonly NC='\033[0m'
else
  readonly GREEN=''
  readonly YELLOW=''
  readonly RED=''
  readonly NC=''
fi

#######################################
# Logging functions
# Globals:
#   GREEN, YELLOW, RED, NC
# Arguments:
#   $* - Message to log
# Outputs:
#   Writes message to stdout (or stderr for log_error)
#######################################
log_info() { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

#######################################
# Print usage information.
# Globals:
#   None
# Arguments:
#   None
# Outputs:
#   Writes usage to stdout
#######################################
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

log_info "Platform: ${PLATFORM}"
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
IMAGE_NAME="ffmpeg-${PLATFORM}"
log_info "Building Docker image: ${IMAGE_NAME} (ARMv6 with QEMU)"

# Ensure QEMU is available for ARM emulation
if ! docker buildx inspect --bootstrap >/dev/null 2>&1; then
  log_info "Setting up Docker buildx for multi-platform support..."
  docker run --rm --privileged multiarch/qemu-user-static --reset -p yes
fi

docker build --platform linux/arm/v6 -t "${IMAGE_NAME}" "${SCRIPT_DIR}"

# Run build in Docker with QEMU emulation
log_info "Running build in Docker container (ARMv6 via QEMU)..."
docker run --rm \
  --platform linux/arm/v6 \
  -v "${PROJECT_ROOT}:/build/ffmpeg-prebuilds:rw" \
  -e LICENSE_TIER="${LICENSE_TIER}" \
  -e BUILD_DIR="/build/ffmpeg-prebuilds/platforms/${PLATFORM}/build" \
  -w "/build/ffmpeg-prebuilds/platforms/${PLATFORM}" \
  "${IMAGE_NAME}" \
  make LICENSE_TIER="${LICENSE_TIER}" "${TARGET}"

log_info "Build complete!"
