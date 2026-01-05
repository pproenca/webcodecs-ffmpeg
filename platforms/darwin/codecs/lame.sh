#!/usr/bin/env bash
# Build libmp3lame - MP3 encoder (LGPL)
#
# Required environment:
#   PREFIX          - Installation prefix
#   LAME_VERSION    - Version number (e.g., "3.100")
#   LAME_SHA256     - SHA256 checksum
#
# Optional:
#   DRY_RUN=1       - Echo commands instead of running
#   WORK_DIR        - Build directory (default: /tmp)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

build_lame() {
    require PREFIX
    require LAME_VERSION
    require LAME_SHA256

    log "Building libmp3lame ${LAME_VERSION}"

    local work_dir="${WORK_DIR:-/tmp}/lame-$$"
    local url="https://downloads.sourceforge.net/project/lame/lame/${LAME_VERSION}/lame-${LAME_VERSION}.tar.gz"
    run mkdir -p "$work_dir"
    enter "$work_dir"

    download_verify "$url" "lame-${LAME_VERSION}.tar.gz" "$LAME_SHA256"
    extract "lame-${LAME_VERSION}.tar.gz"

    enter "lame-${LAME_VERSION}"

    # Build configure args
    local configure_args=(
        --prefix="$PREFIX"
        --disable-shared
        --enable-static
        --with-pic
        --disable-frontend
    )

    # NASM is x86-only, skip on ARM
    local arch
    arch=$(uname -m)
    if [[ "$arch" == "x86_64" || "$arch" == "i386" || "$arch" == "i686" ]]; then
        configure_args+=(--enable-nasm)
    fi

    run ./configure "${configure_args[@]}" \
        CFLAGS="${EXTRA_CFLAGS:+$EXTRA_CFLAGS }-fPIC" \
        LDFLAGS="${EXTRA_LDFLAGS:-}"

    run make -j"$(nproc_safe)"
    run make install

    enter /
    run rm -rf "$work_dir"

    log "libmp3lame complete"
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && build_lame
