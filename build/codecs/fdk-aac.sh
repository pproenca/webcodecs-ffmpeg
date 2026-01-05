#!/usr/bin/env bash
# Build fdk-aac - Fraunhofer AAC encoder (Non-free)
#
# Required environment:
#   PREFIX           - Installation prefix
#   FDKAAC_VERSION   - Git branch/tag (e.g., "v2.0.3")
#
# Optional:
#   DRY_RUN=1        - Echo commands instead of running
#   WORK_DIR         - Build directory (default: /tmp)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

build_fdk_aac() {
    require PREFIX
    require FDKAAC_VERSION

    log "Building fdk-aac ${FDKAAC_VERSION}"

    local work_dir="${WORK_DIR:-/tmp}/fdk-aac-$$"
    run mkdir -p "$work_dir"
    enter "$work_dir"

    local git_url="https://github.com/mstorsjo/fdk-aac.git"
    if [[ "$DRY_RUN" == "1" ]]; then
        check_git_ref "$git_url" "$FDKAAC_VERSION" || true
    fi
    run git clone --depth 1 --branch "${FDKAAC_VERSION}" "$git_url"

    enter fdk-aac

    run ./autogen.sh

    run ./configure \
        --prefix="$PREFIX" \
        --disable-shared \
        --enable-static \
        --with-pic \
        CFLAGS="-fPIC" \
        CXXFLAGS="-fPIC"

    run make -j"$(nproc_safe)"
    run make install

    enter /
    run rm -rf "$work_dir"

    log "fdk-aac complete"
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && build_fdk_aac
