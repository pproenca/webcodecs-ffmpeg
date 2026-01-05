#!/usr/bin/env bash
# Build NASM - Netwide Assembler (required for x264/x265)
#
# Required environment:
#   PREFIX          - Installation prefix
#   NASM_VERSION    - Version number (e.g., "2.16.03")
#
# Optional:
#   NASM_SHA256     - SHA256 checksum
#   DRY_RUN=1       - Echo commands instead of running
#   WORK_DIR        - Build directory (default: /tmp)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

build_nasm() {
    require PREFIX
    require NASM_VERSION

    log "Building NASM ${NASM_VERSION}"

    local work_dir="${WORK_DIR:-/tmp}/nasm-$$"
    local url="https://github.com/netwide-assembler/nasm/archive/refs/tags/nasm-${NASM_VERSION}.tar.gz"
    run mkdir -p "$work_dir"
    enter "$work_dir"

    if [[ -n "${NASM_SHA256:-}" ]]; then
        download_verify "$url" "nasm-${NASM_VERSION}.tar.gz" "$NASM_SHA256"
    else
        if [[ "$DRY_RUN" == "1" ]]; then
            log_cmd "curl -fSL '$url' -o 'nasm-${NASM_VERSION}.tar.gz'"
        else
            curl -fSL --retry 3 "$url" -o "nasm-${NASM_VERSION}.tar.gz"
        fi
    fi
    extract "nasm-${NASM_VERSION}.tar.gz"

    enter "nasm-nasm-${NASM_VERSION}"

    run ./autogen.sh
    run ./configure --prefix="$PREFIX"
    run make -j"$(nproc_safe)"

    # Install binaries manually (make install fails on man pages from tarball)
    run mkdir -p "$PREFIX/bin"
    run install -c nasm ndisasm "$PREFIX/bin/"

    enter /
    run rm -rf "$work_dir"

    log "NASM complete"
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && build_nasm
