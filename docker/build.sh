#!/usr/bin/env bash
# =============================================================================
# Docker Build Helper for Linux Platforms
# =============================================================================
# This script orchestrates Docker-based builds for Linux platforms.
#
# Usage:
#   ./docker/build.sh linux-x64 [target] [LICENSE=free]
#   ./docker/build.sh linux-arm64 [target] [LICENSE=free]
#
# Examples:
#   ./docker/build.sh linux-x64              # Full build with free license
#   ./docker/build.sh linux-x64 codecs       # Build only codecs
#   ./docker/build.sh linux-arm64 all non-free   # Build with non-free license (GPL)
#
# Environment:
#   LICENSE - License tier (free, non-free). Default: free
#   DEBUG   - Enable debug output
# =============================================================================

set -euo pipefail

# Resolve script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

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
# Configuration
# =============================================================================

PLATFORM="${1:-}"
TARGET="${2:-all}"
LICENSE="${LICENSE:-free}"

# Validate platform
if [[ -z "$PLATFORM" ]]; then
  log_error "Usage: $0 <platform> [target] [LICENSE=tier]"
  log_error "Platforms: linux-x64, linux-arm64"
  exit 1
fi

case "$PLATFORM" in
  linux-x64)
    DOCKER_TARGET="builder-x64"
    ;;
  linux-arm64)
    DOCKER_TARGET="builder-arm64"
    ;;
  *)
    log_error "Unknown platform: $PLATFORM"
    log_error "Supported platforms: linux-x64, linux-arm64"
    exit 1
    ;;
esac

# Backwards compatibility: map old values to new
case "$LICENSE" in
  bsd|lgpl)
    log_warn "DEPRECATION: LICENSE=$LICENSE is deprecated. Use LICENSE=free instead."
    LICENSE="free"
    ;;
  gpl)
    log_warn "DEPRECATION: LICENSE=gpl is deprecated. Use LICENSE=non-free instead."
    LICENSE="non-free"
    ;;
esac

# Validate license
if [[ ! "$LICENSE" =~ ^(free|non-free)$ ]]; then
  log_error "Invalid LICENSE=$LICENSE. Must be: free, non-free"
  exit 1
fi

# =============================================================================
# Docker Functions
# =============================================================================

#######################################
# Check if Docker is available and running.
#######################################
check_docker() {
  if ! command -v docker &>/dev/null; then
    log_error "Docker is not installed"
    log_error "Install Docker from: https://docs.docker.com/get-docker/"
    exit 1
  fi

  if ! docker info &>/dev/null; then
    log_error "Docker daemon is not running"
    exit 1
  fi
}

#######################################
# Build the Docker image for the platform.
#######################################
build_image() {
  local image_name="ffmpeg-build:${PLATFORM}"

  log_step "Building Docker image: ${image_name}"

  docker build \
    --file "${SCRIPT_DIR}/Dockerfile.linux" \
    --target "${DOCKER_TARGET}" \
    --tag "${image_name}" \
    "${PROJECT_ROOT}"
}

#######################################
# Run the build inside Docker container.
#######################################
run_build() {
  local image_name="ffmpeg-build:${PLATFORM}"

  log_step "Running build in container..."
  log_info "Platform: ${PLATFORM}"
  log_info "Target: ${TARGET}"
  log_info "License: ${LICENSE}"

  # Run build with project mounted
  # --rm: Remove container after exit
  # -v: Mount project directory
  # -e: Pass environment variables
  # -w: Set working directory
  docker run --rm \
    -v "${PROJECT_ROOT}:/build:rw" \
    -e "LICENSE=${LICENSE}" \
    -e "DEBUG=${DEBUG:-}" \
    -w "/build" \
    "${image_name}" \
    make -C "/build/platforms/${PLATFORM}" LICENSE="${LICENSE}" "${TARGET}"
}

#######################################
# Verify the build output.
#######################################
verify_build() {
  local artifacts_dir="${PROJECT_ROOT}/artifacts/${PLATFORM}-${LICENSE}"
  local ffmpeg_bin="${artifacts_dir}/bin/ffmpeg"

  if [[ ! -f "$ffmpeg_bin" ]]; then
    log_error "Build failed: ffmpeg binary not found"
    exit 1
  fi

  log_step "Verifying build..."

  # Verify architecture
  local expected_arch
  case "$PLATFORM" in
    linux-x64)
      expected_arch="x86-64"
      ;;
    linux-arm64)
      expected_arch="aarch64"
      ;;
  esac

  local file_output
  file_output="$(file "$ffmpeg_bin")"

  if ! echo "$file_output" | grep -qi "$expected_arch"; then
    log_error "Architecture mismatch!"
    log_error "Expected: $expected_arch"
    log_error "Got: $file_output"
    exit 1
  fi

  log_info "Architecture verified: $expected_arch"

  # Verify static linking (only libc, libm, libpthread should be dynamic)
  log_step "Checking dynamic dependencies..."
  if command -v ldd &>/dev/null && [[ "$PLATFORM" == "linux-x64" ]]; then
    ldd "$ffmpeg_bin" || true
  fi

  log_info "Build verified successfully"
}

# =============================================================================
# Main
# =============================================================================

main() {
  echo ""
  echo "=========================================="
  echo " FFmpeg Docker Build for ${PLATFORM}"
  echo " License tier: ${LICENSE}"
  echo "=========================================="
  echo ""

  check_docker
  build_image
  run_build

  if [[ "$TARGET" == "all" ]] || [[ "$TARGET" == "package" ]]; then
    verify_build

    local artifacts_dir="${PROJECT_ROOT}/artifacts/${PLATFORM}-${LICENSE}"
    echo ""
    log_info "Artifacts location: ${artifacts_dir}/"
    ls -la "${artifacts_dir}/bin/" 2>/dev/null || true
  fi

  echo ""
  log_info "Build completed successfully!"
}

main
