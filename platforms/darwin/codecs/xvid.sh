#!/usr/bin/env bash
# Build Xvid - MPEG-4 ASP video codec (GPL)
#
# Required environment:
#   PREFIX          - Installation prefix
#   XVID_VERSION    - Version number (e.g., "1.3.7")
#   XVID_SHA256     - SHA256 checksum
#
# Optional:
#   DRY_RUN=1       - Echo commands instead of running
#   WORK_DIR        - Build directory (default: /tmp)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

build_xvid() {
    require PREFIX
    require XVID_VERSION
    require XVID_SHA256

    log "Building Xvid ${XVID_VERSION}"

    local work_dir="${WORK_DIR:-/tmp}/xvid-$$"
    local url="https://downloads.xvid.com/downloads/xvidcore-${XVID_VERSION}.tar.gz"
    run mkdir -p "$work_dir"
    enter "$work_dir"

    download_verify "$url" "xvidcore-${XVID_VERSION}.tar.gz" "$XVID_SHA256"
    extract "xvidcore-${XVID_VERSION}.tar.gz"

    enter xvidcore/build/generic

    run ./configure \
        --prefix="$PREFIX" \
        CFLAGS="${EXTRA_CFLAGS:+$EXTRA_CFLAGS }-fPIC" \
        LDFLAGS="${EXTRA_LDFLAGS:-}"

    run make -j"$(nproc_safe)"
    run make install

    enter /
    run rm -rf "$work_dir"

    log "Xvid complete"
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && build_xvid
