#!/usr/bin/env bash
# =============================================================================
# Shared Build Functions
# =============================================================================
# Common functions used across platform build scripts.
#
# Prerequisites:
#   - Must source logging.sh first (provides log_* functions)
#   - PROJECT_ROOT must be set before sourcing
#
# Usage:
#   source "${PROJECT_ROOT}/scripts/lib/logging.sh"
#   source "${PROJECT_ROOT}/scripts/lib/common.sh"
# =============================================================================

# Prevent double-sourcing
if [[ -n "${__COMMON_SH_SOURCED:-}" ]]; then
  return 0
fi
readonly __COMMON_SH_SOURCED=1

# Verify prerequisites
if ! declare -f log_error &>/dev/null; then
  echo "ERROR: logging.sh must be sourced before common.sh" >&2
  exit 1
fi

# =============================================================================
# License Normalization
# =============================================================================

#######################################
# Normalize license value with backwards compatibility.
# Handles deprecated values: bsd->free, lgpl->free, gpl->non-free
# Globals:
#   None
# Arguments:
#   $1 - License value to normalize
# Outputs:
#   Normalized license value to stdout
#   Deprecation warnings to stderr
# Returns:
#   0 on success, 1 on invalid license
#######################################
normalize_license() {
  local license="${1:-free}"

  case "$license" in
    bsd|lgpl)
      log_warn "DEPRECATION: LICENSE=$license is deprecated. Use LICENSE=free instead."
      echo "free"
      ;;
    gpl)
      log_warn "DEPRECATION: LICENSE=gpl is deprecated. Use LICENSE=non-free instead."
      echo "non-free"
      ;;
    free|non-free)
      echo "$license"
      ;;
    *)
      log_error "Invalid LICENSE=$license. Must be: free, non-free"
      return 1
      ;;
  esac
}

# =============================================================================
# Binary Verification
# =============================================================================

#######################################
# Verify binary has expected architecture.
# Globals:
#   None
# Arguments:
#   $1 - Path to binary
#   $2 - Expected architecture pattern (e.g., "arm64", "x86_64", "aarch64")
# Outputs:
#   Writes verification status to stdout
# Returns:
#   0 on success, 1 on failure
#######################################
verify_binary_arch() {
  local binary="$1"
  local expected_arch="$2"

  if [[ ! -f "$binary" ]]; then
    log_error "Binary not found: $binary"
    return 1
  fi

  log_step "Verifying binary architecture..."

  local file_output
  file_output="$(file "$binary")"

  if ! echo "$file_output" | grep -q "$expected_arch"; then
    log_error "Architecture mismatch!"
    log_error "Expected: $expected_arch"
    log_error "Got: $file_output"
    return 1
  fi

  log_info "Architecture verified: $expected_arch"
}

# =============================================================================
# CMake Installation
# =============================================================================

#######################################
# Install CMake 3.x via pip if needed.
# CMake 4.x is incompatible with upstream codec builds (x265, libaom, svt-av1).
# Globals:
#   None
# Arguments:
#   None
# Outputs:
#   Writes installation status to stdout
#######################################
install_cmake_3x() {
  local cmake_version
  cmake_version="$(cmake --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "0.0.0")"
  local cmake_major="${cmake_version%%.*}"

  if [[ "$cmake_major" -ge 4 ]] || ! command -v cmake &>/dev/null; then
    log_info "Installing CMake 3.x via pip (CMake 4.x incompatible with codec builds)..."
    pip3 install --quiet --break-system-packages 'cmake>=3.20,<4'
  fi
}
