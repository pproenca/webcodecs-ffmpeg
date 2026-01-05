#!/usr/bin/env bash
# Build dav1d - Fast AV1 decoder (BSD)
#
# Required environment:
#   PREFIX          - Installation prefix
#   DAV1D_VERSION   - Version number (e.g., "1.5.1")
#   DAV1D_URL       - Download URL for tarball
#   DAV1D_SHA256    - SHA256 checksum
#
# Optional:
#   DRY_RUN=1       - Echo commands instead of running
#   WORK_DIR        - Build directory (default: /tmp)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

build_dav1d() {
    require PREFIX
    require DAV1D_VERSION
    require DAV1D_URL
    require DAV1D_SHA256

    log "Building dav1d ${DAV1D_VERSION}"

    local work_dir="${WORK_DIR:-/tmp}/dav1d-$$"
    run mkdir -p "$work_dir"
    enter "$work_dir"

    download_verify "$DAV1D_URL" "dav1d-${DAV1D_VERSION}.tar.xz" "$DAV1D_SHA256"
    extract "dav1d-${DAV1D_VERSION}.tar.xz"

    enter "dav1d-${DAV1D_VERSION}"

    run meson setup build \
        --prefix="$PREFIX" \
        --libdir=lib \
        --default-library=static \
        --buildtype=release \
        -Denable_tools=false \
        -Denable_tests=false \
        -Denable_examples=false

    run ninja -C build
    run ninja -C build install

    enter /
    run rm -rf "$work_dir"

    log "dav1d complete"
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && build_dav1d
