#!/usr/bin/env bash
# Build libopus - Opus audio codec (BSD)
#
# Required environment:
#   PREFIX          - Installation prefix
#   OPUS_VERSION    - Version number (e.g., "1.5.2")
#   OPUS_SHA256     - SHA256 checksum
#
# Optional:
#   DRY_RUN=1       - Echo commands instead of running
#   WORK_DIR        - Build directory (default: /tmp)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

build_opus() {
    require PREFIX
    require OPUS_VERSION
    require OPUS_SHA256

    log "Building libopus ${OPUS_VERSION}"

    local work_dir="${WORK_DIR:-/tmp}/opus-$$"
    local url="https://downloads.xiph.org/releases/opus/opus-${OPUS_VERSION}.tar.gz"
    run mkdir -p "$work_dir"
    enter "$work_dir"

    download_verify "$url" "opus-${OPUS_VERSION}.tar.gz" "$OPUS_SHA256"
    extract "opus-${OPUS_VERSION}.tar.gz"

    enter "opus-${OPUS_VERSION}"

    run ./configure \
        --prefix="$PREFIX" \
        --disable-shared \
        --enable-static \
        --with-pic \
        --disable-doc \
        --disable-extra-programs \
        CFLAGS="${EXTRA_CFLAGS:+$EXTRA_CFLAGS }-fPIC" \
        LDFLAGS="${EXTRA_LDFLAGS:-}"

    run make -j"$(nproc_safe)"
    run make install

    enter /
    run rm -rf "$work_dir"

    log "libopus complete"
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && build_opus
