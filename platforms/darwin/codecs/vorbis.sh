#!/usr/bin/env bash
# Build libvorbis - Vorbis audio codec (BSD)
# Note: Requires libogg to be installed first
#
# Required environment:
#   PREFIX             - Installation prefix
#   VORBIS_VERSION  - Version number (e.g., "1.3.7")
#
# Optional:
#   VORBIS_URL      - Override download URL
#   VORBIS_SHA256   - SHA256 checksum (optional verification)
#   DRY_RUN=1          - Echo commands instead of running
#   WORK_DIR           - Build directory (default: /tmp)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

build_vorbis() {
    require PREFIX
    require VORBIS_VERSION

    log "Building libvorbis ${VORBIS_VERSION}"

    local work_dir="${WORK_DIR:-/tmp}/vorbis-$$"
    local url="${VORBIS_URL:-https://ftp.osuosl.org/pub/xiph/releases/vorbis/libvorbis-${VORBIS_VERSION}.tar.gz}"
    run mkdir -p "$work_dir"
    enter "$work_dir"

    if [[ -n "${VORBIS_SHA256:-}" ]]; then
        download_verify "$url" "libvorbis-${VORBIS_VERSION}.tar.gz" "$VORBIS_SHA256"
    else
        if [[ "$DRY_RUN" == "1" ]]; then
            log_cmd "curl -fSL '$url' -o 'libvorbis-${VORBIS_VERSION}.tar.gz'"
        else
            curl -fSL --retry 3 "$url" -o "libvorbis-${VORBIS_VERSION}.tar.gz"
        fi
    fi
    extract "libvorbis-${VORBIS_VERSION}.tar.gz"

    enter "libvorbis-${VORBIS_VERSION}"

    run ./configure \
        --prefix="$PREFIX" \
        --disable-shared \
        --enable-static \
        --with-pic \
        --with-ogg="$PREFIX" \
        CFLAGS="${EXTRA_CFLAGS:+$EXTRA_CFLAGS }-fPIC" \
        LDFLAGS="${EXTRA_LDFLAGS:-}"

    run make -j"$(nproc_safe)"
    run make install

    enter /
    run rm -rf "$work_dir"

    log "libvorbis complete"
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && build_vorbis
