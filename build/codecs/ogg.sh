#!/usr/bin/env bash
# Build libogg - Ogg container format (BSD)
#
# Required environment:
#   PREFIX          - Installation prefix
#   OGG_VERSION     - Version number (e.g., "1.3.6")
#
# Optional:
#   OGG_URL         - Override download URL
#   OGG_SHA256      - SHA256 checksum (optional verification)
#   DRY_RUN=1       - Echo commands instead of running
#   WORK_DIR        - Build directory (default: /tmp)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

build_ogg() {
    require PREFIX
    require OGG_VERSION

    log "Building libogg ${OGG_VERSION}"

    local work_dir="${WORK_DIR:-/tmp}/ogg-$$"
    local url="${OGG_URL:-https://ftp.osuosl.org/pub/xiph/releases/ogg/libogg-${OGG_VERSION}.tar.gz}"
    run mkdir -p "$work_dir"
    enter "$work_dir"

    if [[ -n "${OGG_SHA256:-}" ]]; then
        download_verify "$url" "libogg-${OGG_VERSION}.tar.gz" "$OGG_SHA256"
    else
        if [[ "$DRY_RUN" == "1" ]]; then
            log_cmd "curl -fSL '$url' -o 'libogg-${OGG_VERSION}.tar.gz'"
        else
            curl -fSL --retry 3 "$url" -o "libogg-${OGG_VERSION}.tar.gz"
        fi
    fi
    extract "libogg-${OGG_VERSION}.tar.gz"

    enter "libogg-${OGG_VERSION}"

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

    log "libogg complete"
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && build_ogg
