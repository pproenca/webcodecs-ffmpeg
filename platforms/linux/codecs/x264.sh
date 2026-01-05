#!/usr/bin/env bash
# Build x264 - H.264/AVC video encoder (GPL)
#
# Required environment:
#   PREFIX         - Installation prefix
#   X264_VERSION   - Git branch/tag (e.g., "stable")
#
# Optional:
#   DRY_RUN=1      - Echo commands instead of running
#   WORK_DIR       - Build directory (default: /tmp)

set -euxo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

build_x264() {
    require PREFIX
    require X264_VERSION

    log "Building x264 ${X264_VERSION}"

    local work_dir="${WORK_DIR:-/tmp}/x264-$$"
    run mkdir -p "$work_dir"
    enter "$work_dir"

    local git_url="https://code.videolan.org/videolan/x264.git"
    if [[ "$DRY_RUN" == "1" ]]; then
        check_git_ref "$git_url" "$X264_VERSION" || true
    fi
    run git clone --depth 1 --branch "${X264_VERSION}" "$git_url"

    enter x264

    run ./configure \
        --prefix="$PREFIX" \
        --enable-static \
        --disable-shared \
        --enable-pic \
        --disable-cli \
        --disable-opencl \
        --extra-cflags="${EXTRA_CFLAGS:-}" \
        --extra-ldflags="${EXTRA_LDFLAGS:-}"

    run make -j"$(nproc_safe)"
    run make install

    enter /
    run rm -rf "$work_dir"

    log "x264 complete"
}

# Run if executed directly
[[ "${BASH_SOURCE[0]}" == "${0}" ]] && build_x264
