#!/usr/bin/env bash
# Build libass - Subtitle rendering library (ISC)
# Note: Requires libfreetype to be installed first
#
# Required environment:
#   PREFIX           - Installation prefix
#   LIBASS_VERSION   - Version number (e.g., "0.17.3")
#   LIBASS_SHA256    - SHA256 checksum
#
# Optional:
#   DRY_RUN=1        - Echo commands instead of running
#   WORK_DIR         - Build directory (default: /tmp)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

build_libass() {
    require PREFIX
    require LIBASS_VERSION
    require LIBASS_SHA256

    log "Building libass ${LIBASS_VERSION}"

    local work_dir="${WORK_DIR:-/tmp}/libass-$$"
    local url="https://github.com/libass/libass/releases/download/${LIBASS_VERSION}/libass-${LIBASS_VERSION}.tar.gz"
    run mkdir -p "$work_dir"
    enter "$work_dir"

    download_verify "$url" "libass-${LIBASS_VERSION}.tar.gz" "$LIBASS_SHA256"
    extract "libass-${LIBASS_VERSION}.tar.gz"

    enter "libass-${LIBASS_VERSION}"

    run ./configure \
        --prefix="$PREFIX" \
        --disable-shared \
        --enable-static \
        --with-pic \
        --disable-require-system-font-provider \
        CFLAGS="${EXTRA_CFLAGS:+$EXTRA_CFLAGS }-fPIC" \
        LDFLAGS="${EXTRA_LDFLAGS:-}"

    run make -j"$(nproc_safe)"
    run make install

    enter /
    run rm -rf "$work_dir"

    log "libass complete"
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && build_libass
