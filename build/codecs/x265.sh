#!/usr/bin/env bash
# Build x265 - H.265/HEVC video encoder (GPL)
#
# Required environment:
#   PREFIX         - Installation prefix
#   X265_VERSION   - Git branch/tag (e.g., "3.6")
#
# Optional:
#   PATCH_DIR      - Directory containing patches (default: ../patches)
#   DRY_RUN=1      - Echo commands instead of running
#   WORK_DIR       - Build directory (default: /tmp)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

build_x265() {
    require PREFIX
    require X265_VERSION

    log "Building x265 ${X265_VERSION}"

    local work_dir="${WORK_DIR:-/tmp}/x265-$$"
    local patch_dir="${PATCH_DIR:-$SCRIPT_DIR/../patches}"
    run mkdir -p "$work_dir"
    enter "$work_dir"

    local git_url="https://bitbucket.org/multicoreware/x265_git.git"
    if [[ "$DRY_RUN" == "1" ]]; then
        check_git_ref "$git_url" "$X265_VERSION" || true
    fi
    run git clone --depth 1 --branch "${X265_VERSION}" "$git_url"

    enter x265_git

    # Apply CMake 4.x compatibility patch
    if [[ -f "$patch_dir/x265-cmake4-compat.patch" ]]; then
        run patch -p1 < "$patch_dir/x265-cmake4-compat.patch"
    fi

    run mkdir -p build/linux
    enter build/linux

    run cmake -G "Unix Makefiles" \
        -DCMAKE_INSTALL_PREFIX="$PREFIX" \
        -DLIB_INSTALL_DIR="$PREFIX/lib" \
        -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
        -DCMAKE_C_FLAGS="-fPIC" \
        -DCMAKE_CXX_FLAGS="-fPIC" \
        -DENABLE_SHARED=OFF \
        -DENABLE_CLI=OFF \
        -DHIGH_BIT_DEPTH=ON \
        ../../source

    run make -j"$(nproc_safe)"
    run make install

    enter /
    run rm -rf "$work_dir"

    log "x265 complete"
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && build_x265
