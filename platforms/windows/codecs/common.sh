#!/usr/bin/env bash
# Minimal shared utilities for codec build scripts
#
# Usage:
#   source common.sh
#   DRY_RUN=1 ./x264.sh  # dry-run mode
#
# Provides: log, die, run, require, download_verify, is_macos, nproc_safe
#
# macOS-specific environment variables (set by macos.sh):
#   EXTRA_CFLAGS      - Additional C compiler flags (e.g., "-arch arm64 -mmacosx-version-min=11.0")
#   EXTRA_LDFLAGS     - Additional linker flags
#   EXTRA_CMAKE_FLAGS - Additional CMake flags (e.g., "-DCMAKE_OSX_ARCHITECTURES=arm64")
#   MACOS_ARCH        - Target architecture (x86_64 or arm64)
#   MACOS_DEPLOYMENT_TARGET - Minimum macOS version (e.g., "11.0")

DRY_RUN="${DRY_RUN:-0}"

log()     { echo "==> $*"; }
log_cmd() { echo "    $*"; }
die()     { echo "ERROR: $*" >&2; exit 1; }

# Detect if running on macOS
is_macos() { [[ "$(uname -s)" == "Darwin" ]]; }

# Run command or echo in dry-run mode
run() {
    if [[ "$DRY_RUN" == "1" ]]; then
        log_cmd "$*"
    else
        "$@"
    fi
}

# Validate required environment variable
require() {
    local var="$1"
    if [[ -z "${!var:-}" ]]; then
        die "Required variable not set: $var"
    fi
    if [[ "$DRY_RUN" == "1" ]]; then
        log_cmd "$var=${!var}"
    fi
    return 0
}

# Check if URL is reachable (used in dry-run mode)
check_url() {
    local url="$1"
    if curl -fsSL --head --max-time 10 "$url" &>/dev/null; then
        log_cmd "URL OK: $url"
        return 0
    else
        echo "WARNING: URL may be unreachable: $url" >&2
        return 1
    fi
}

# Check if git remote/branch exists
check_git_ref() {
    local url="$1" ref="$2"
    if git ls-remote --exit-code --heads --tags "$url" "$ref" &>/dev/null; then
        log_cmd "Git ref OK: $url @ $ref"
        return 0
    else
        echo "WARNING: Git ref may not exist: $url @ $ref" >&2
        return 1
    fi
}

# Download with checksum verification
# Usage: download_verify URL OUTPUT SHA256
download_verify() {
    local url="$1" output="$2" sha256="$3"
    if [[ "$DRY_RUN" == "1" ]]; then
        log_cmd "curl -fSL '$url' -o '$output'"
        log_cmd "echo '$sha256  $output' | sha256sum -c -"
        check_url "$url" || true
        return 0
    fi
    curl -fSL --retry 3 "$url" -o "$output"
    echo "$sha256  $output" | sha256sum -c -
}

# Extract archive (auto-detects compression)
# Usage: extract ARCHIVE
extract() {
    local archive="$1"
    if [[ "$DRY_RUN" == "1" ]]; then
        log_cmd "tar xf '$archive'"
        return 0
    fi
    case "$archive" in
        *.tar.gz|*.tgz)  tar xzf "$archive" ;;
        *.tar.xz)        tar xJf "$archive" ;;
        *.tar.bz2)       tar xjf "$archive" ;;
        *)               tar xf "$archive" ;;
    esac
}

# Change directory (logs in dry-run mode, skips actual cd)
enter() {
    local dir="$1"
    if [[ "$DRY_RUN" == "1" ]]; then
        log_cmd "cd $dir"
    else
        cd "$dir"
    fi
}

# Number of parallel jobs
nproc_safe() {
    if command -v nproc &>/dev/null; then
        nproc
    elif command -v sysctl &>/dev/null; then
        sysctl -n hw.ncpu
    else
        echo 4
    fi
}
