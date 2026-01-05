#!/usr/bin/env bash
# Build Speex - Speech audio codec (BSD)
#
# Required environment:
#   PREFIX          - Installation prefix
#   SPEEX_VERSION   - Version number (e.g., "1.2.1")
#   SPEEX_SHA256    - SHA256 checksum
#
# Optional:
#   DRY_RUN=1       - Echo commands instead of running
#   WORK_DIR        - Build directory (default: /tmp)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

build_speex() {
    require PREFIX
    require SPEEX_VERSION
    require SPEEX_SHA256

    log "Building Speex ${SPEEX_VERSION}"

    local work_dir="${WORK_DIR:-/tmp}/speex-$$"
    local url="https://ftp.osuosl.org/pub/xiph/releases/speex/speex-${SPEEX_VERSION}.tar.gz"
    run mkdir -p "$work_dir"
    enter "$work_dir"

    download_verify "$url" "speex-${SPEEX_VERSION}.tar.gz" "$SPEEX_SHA256"
    extract "speex-${SPEEX_VERSION}.tar.gz"

    enter "speex-${SPEEX_VERSION}"

    run ./configure \
        --prefix="$PREFIX" \
        --disable-shared \
        --enable-static \
        --with-pic \
        CFLAGS="${EXTRA_CFLAGS:+$EXTRA_CFLAGS }-fPIC" \
        LDFLAGS="${EXTRA_LDFLAGS:-}"

    run make -j"$(nproc_safe)"
    run make install

    enter /
    run rm -rf "$work_dir"

    log "Speex complete"
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && build_speex
