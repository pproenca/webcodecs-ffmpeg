#!/usr/bin/env bash
# Build libfreetype - Font rendering library (FreeType License)
#
# Required environment:
#   PREFIX            - Installation prefix
#   FREETYPE_VERSION  - Version number (e.g., "2.13.3")
#   FREETYPE_SHA256   - SHA256 checksum
#
# Optional:
#   DRY_RUN=1         - Echo commands instead of running
#   WORK_DIR          - Build directory (default: /tmp)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

build_freetype() {
    require PREFIX
    require FREETYPE_VERSION
    require FREETYPE_SHA256

    log "Building libfreetype ${FREETYPE_VERSION}"

    local work_dir="${WORK_DIR:-/tmp}/freetype-$$"
    local url="https://download.savannah.gnu.org/releases/freetype/freetype-${FREETYPE_VERSION}.tar.xz"
    run mkdir -p "$work_dir"
    enter "$work_dir"

    download_verify "$url" "freetype-${FREETYPE_VERSION}.tar.xz" "$FREETYPE_SHA256"
    extract "freetype-${FREETYPE_VERSION}.tar.xz"

    enter "freetype-${FREETYPE_VERSION}"

    run ./configure \
        --prefix="$PREFIX" \
        --disable-shared \
        --enable-static \
        --with-pic \
        --without-harfbuzz \
        --without-bzip2 \
        --without-png \
        CFLAGS="-fPIC"

    run make -j"$(nproc_safe)"
    run make install

    enter /
    run rm -rf "$work_dir"

    log "libfreetype complete"
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && build_freetype
