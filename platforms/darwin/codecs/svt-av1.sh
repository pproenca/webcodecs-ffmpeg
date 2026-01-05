#!/usr/bin/env bash
# Build SVT-AV1 - Intel's AV1 encoder (BSD)
#
# Required environment:
#   PREFIX          - Installation prefix
#   SVTAV1_VERSION  - Git branch/tag (e.g., "v2.3.0")
#
# Optional:
#   DRY_RUN=1       - Echo commands instead of running
#   WORK_DIR        - Build directory (default: /tmp)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

build_svt_av1() {
    require PREFIX
    require SVTAV1_VERSION

    log "Building SVT-AV1 ${SVTAV1_VERSION}"

    local work_dir="${WORK_DIR:-/tmp}/svt-av1-$$"
    run mkdir -p "$work_dir"
    enter "$work_dir"

    local git_url="https://gitlab.com/AOMediaCodec/SVT-AV1.git"
    if [[ "$DRY_RUN" == "1" ]]; then
        check_git_ref "$git_url" "$SVTAV1_VERSION" || true
    fi
    run git clone --depth 1 --branch "${SVTAV1_VERSION}" "$git_url"

    run mkdir -p SVT-AV1/build
    enter SVT-AV1/build

    # Parse EXTRA_CMAKE_FLAGS into array
    local extra_cmake_flags=()
    if [[ -n "${EXTRA_CMAKE_FLAGS:-}" ]]; then
        read -ra extra_cmake_flags <<< "$EXTRA_CMAKE_FLAGS"
    fi

    run cmake -G "Unix Makefiles" \
        -DCMAKE_INSTALL_PREFIX="$PREFIX" \
        -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
        -DCMAKE_C_FLAGS="-fPIC" \
        -DCMAKE_CXX_FLAGS="-fPIC" \
        -DBUILD_SHARED_LIBS=OFF \
        -DBUILD_APPS=OFF \
        -DBUILD_DEC=OFF \
        -DBUILD_TESTING=OFF \
        ${extra_cmake_flags[@]+"${extra_cmake_flags[@]}"} \
        ..

    run make -j"$(nproc_safe)"
    run make install

    enter /
    run rm -rf "$work_dir"

    log "SVT-AV1 complete"
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && build_svt_av1
