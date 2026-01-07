#!/usr/bin/env bash
#
# Build FFmpeg for linux-s390x using Docker
#
# Usage:
#   ./build.sh [target]        - Run build (uses Docker if on host)
#   ./build.sh all             - Full build (codecs + FFmpeg + package)
#   LICENSE=bsd ./build.sh all - Build BSD tier only
#
# Environment:
#   LICENSE - License tier: bsd, lgpl, gpl (default: gpl)
#   DEBUG   - Enable debug output: 1 (default: empty)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
readonly SCRIPT_DIR PROJECT_ROOT
readonly PLATFORM="linux-s390x"

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
log_info() { printf "${GREEN}[INFO]${NC} %s\n" "$*"; }
log_warn() { printf "${YELLOW}[WARN]${NC} %s\n" "$*"; }
log_error() { printf "${RED}[ERROR]${NC} %s\n" "$*" >&2; }

#######################################
# Check if running inside a Docker container.
# Globals:
#   None
# Arguments:
#   None
# Returns:
#   0 if inside Docker, 1 otherwise
#######################################
in_docker() {
  [[ -f /.dockerenv ]] \
    || grep -q docker /proc/1/cgroup 2>/dev/null \
    || [[ -f /run/.containerenv ]]
}

#######################################
# Build FFmpeg using Docker container.
# Globals:
#   SCRIPT_DIR, PROJECT_ROOT, PLATFORM
#   LICENSE (env var, optional)
#   DEBUG (env var, optional)
# Arguments:
#   $1 - Build target (default: all)
# Outputs:
#   Writes build progress to stdout
#######################################
build_in_docker() {
  local target="${1:-all}"
  local license="${LICENSE:-gpl}"
  local debug="${DEBUG:-}"

  log_info "Building ${PLATFORM} (${license} tier) in Docker..."
  log_info "Project root: ${PROJECT_ROOT}"

  # Ensure QEMU is available for s390x emulation
  if ! docker buildx inspect --bootstrap >/dev/null 2>&1; then
    log_info "Setting up Docker buildx for multi-platform support..."
    docker run --rm --privileged multiarch/qemu-user-static --reset -p yes
  fi

  # Build Docker image
  log_info "Building Docker image for ${PLATFORM}..."
  docker build \
    --platform linux/s390x \
    -t "ffmpeg-builder:${PLATFORM}" \
    -f "${SCRIPT_DIR}/Dockerfile" \
    "${PROJECT_ROOT}"

  # Create output directories on host
  mkdir -p "${PROJECT_ROOT}/artifacts"
  mkdir -p "${PROJECT_ROOT}/build/${PLATFORM}"

  # Run build in container
  log_info "Running build in container (s390x via QEMU)..."
  docker run --rm \
    --platform linux/s390x \
    -v "${PROJECT_ROOT}:/build:rw" \
    -e "LICENSE=${license}" \
    -e "DEBUG=${debug}" \
    -w "/build/platforms/${PLATFORM}" \
    "ffmpeg-builder:${PLATFORM}" \
    bash -c "make -j\$(nproc) LICENSE=${license} DEBUG=${debug} ${target}"

  log_info "Build complete!"
  log_info "Artifacts: ${PROJECT_ROOT}/artifacts/${PLATFORM}-${license}/"
}

#######################################
# Build FFmpeg natively (inside Docker).
# Globals:
#   SCRIPT_DIR, PROJECT_ROOT, PLATFORM
#   LICENSE (env var, optional)
#   DEBUG (env var, optional)
# Arguments:
#   $1 - Build target (default: all)
# Outputs:
#   Writes build progress to stdout
#######################################
build_native() {
  local target="${1:-all}"
  local license="${LICENSE:-gpl}"
  local debug="${DEBUG:-}"

  log_info "Building ${PLATFORM} (${license} tier) natively..."

  cd "${SCRIPT_DIR}"
  make -j"$(nproc)" LICENSE="${license}" DEBUG="${debug}" "${target}"

  log_info "Build complete!"
  log_info "Artifacts: ${PROJECT_ROOT}/artifacts/${PLATFORM}-${license}/"
}

#######################################
# Main entry point.
# Globals:
#   PLATFORM
#   LICENSE (env var, optional)
# Arguments:
#   $1 - Build target (default: all)
# Outputs:
#   Writes build progress to stdout
#######################################
main() {
  local target="${1:-all}"

  log_info "FFmpeg Build for ${PLATFORM}"
  log_info "Target: ${target}"
  log_info "License: ${LICENSE:-gpl}"

  if in_docker; then
    # Running inside Docker container - build directly with Make
    log_info "Detected Docker environment, building natively..."
    build_native "${target}"
  else
    # Running on host - use Docker
    log_info "Running on host, using Docker for build..."
    build_in_docker "${target}"
  fi
}

main "$@"
