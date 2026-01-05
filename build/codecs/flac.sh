#!/usr/bin/env bash
# Build FLAC - Free Lossless Audio Codec (BSD)
#
# Required environment:
#   PREFIX          - Installation prefix
#   FLAC_VERSION    - Version number (e.g., "1.4.3")
#   FLAC_SHA256     - SHA256 checksum
#
# Optional:
#   DRY_RUN=1       - Echo commands instead of running
#   WORK_DIR        - Build directory (default: /tmp)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

build_flac() {
    require PREFIX
    require FLAC_VERSION
    require FLAC_SHA256

    log "Building FLAC ${FLAC_VERSION}"

    local work_dir="${WORK_DIR:-/tmp}/flac-$$"
    local url="https://ftp.osuosl.org/pub/xiph/releases/flac/flac-${FLAC_VERSION}.tar.xz"
    run mkdir -p "$work_dir"
    enter "$work_dir"

    download_verify "$url" "flac-${FLAC_VERSION}.tar.xz" "$FLAC_SHA256"
    extract "flac-${FLAC_VERSION}.tar.xz"

    enter "flac-${FLAC_VERSION}"

    run ./configure \
        --prefix="$PREFIX" \
        --disable-shared \
        --enable-static \
        --with-pic \
        --disable-examples \
        --disable-cpplibs \
        CFLAGS="-fPIC" \
        CXXFLAGS="-fPIC"

    run make -j"$(nproc_safe)"
    run make install

    enter /
    run rm -rf "$work_dir"

    log "FLAC complete"
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && build_flac
