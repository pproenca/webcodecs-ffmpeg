#!/usr/bin/env bash
# Build libtheora - Ogg Theora video codec (BSD)
#
# Required environment:
#   PREFIX          - Installation prefix
#   THEORA_VERSION  - Version number (e.g., "1.1.1")
#   THEORA_SHA256   - SHA256 checksum
#
# Optional:
#   DRY_RUN=1       - Echo commands instead of running
#   WORK_DIR        - Build directory (default: /tmp)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

build_theora() {
    require PREFIX
    require THEORA_VERSION
    require THEORA_SHA256

    log "Building libtheora ${THEORA_VERSION}"

    local work_dir="${WORK_DIR:-/tmp}/theora-$$"
    local url="https://ftp.osuosl.org/pub/xiph/releases/theora/libtheora-${THEORA_VERSION}.tar.gz"
    run mkdir -p "$work_dir"
    enter "$work_dir"

    download_verify "$url" "libtheora-${THEORA_VERSION}.tar.gz" "$THEORA_SHA256"
    extract "libtheora-${THEORA_VERSION}.tar.gz"

    enter "libtheora-${THEORA_VERSION}"

    run ./configure \
        --prefix="$PREFIX" \
        --disable-shared \
        --enable-static \
        --with-pic \
        --disable-examples \
        CFLAGS="-fPIC"

    run make -j"$(nproc_safe)"
    run make install

    enter /
    run rm -rf "$work_dir"

    log "libtheora complete"
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && build_theora
