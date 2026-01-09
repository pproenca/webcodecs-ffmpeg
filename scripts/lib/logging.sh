#!/usr/bin/env bash
# =============================================================================
# Shared Logging Functions
# =============================================================================
# Centralized logging functions for all build scripts.
# Colors are automatically disabled when output is not a terminal.
#
# Usage:
#   source "${PROJECT_ROOT}/scripts/lib/logging.sh"
#
# Functions:
#   log_info "message"   - Green [INFO] prefix
#   log_warn "message"   - Yellow [WARN] prefix
#   log_error "message"  - Red [ERROR] prefix (writes to stderr)
#   log_step "message"   - Blue [STEP] prefix
# =============================================================================

# Prevent double-sourcing
if [[ -n "${__LOGGING_SH_SOURCED:-}" ]]; then
  return 0
fi
readonly __LOGGING_SH_SOURCED=1

# =============================================================================
# Color Definitions
# =============================================================================
# Colors are disabled when output is not a terminal (e.g., CI logs, pipes)

if [[ -t 1 ]]; then
  readonly LOG_RED='\033[0;31m'
  readonly LOG_GREEN='\033[0;32m'
  readonly LOG_YELLOW='\033[1;33m'
  readonly LOG_BLUE='\033[0;34m'
  readonly LOG_NC='\033[0m'
else
  readonly LOG_RED=''
  readonly LOG_GREEN=''
  readonly LOG_YELLOW=''
  readonly LOG_BLUE=''
  readonly LOG_NC=''
fi

# =============================================================================
# Logging Functions
# =============================================================================

#######################################
# Log an info message (green prefix).
# Arguments:
#   $* - Message to log
# Outputs:
#   Writes message to stdout
#######################################
log_info() {
  echo -e "${LOG_GREEN}[INFO]${LOG_NC} $*"
}

#######################################
# Log a warning message (yellow prefix).
# Arguments:
#   $* - Message to log
# Outputs:
#   Writes message to stdout
#######################################
log_warn() {
  echo -e "${LOG_YELLOW}[WARN]${LOG_NC} $*"
}

#######################################
# Log an error message (red prefix).
# Arguments:
#   $* - Message to log
# Outputs:
#   Writes message to stderr
#######################################
log_error() {
  echo -e "${LOG_RED}[ERROR]${LOG_NC} $*" >&2
}

#######################################
# Log a step message (blue prefix).
# Arguments:
#   $* - Message to log
# Outputs:
#   Writes message to stdout
#######################################
log_step() {
  echo -e "${LOG_BLUE}[STEP]${LOG_NC} $*"
}
