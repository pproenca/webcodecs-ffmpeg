#!/usr/bin/env bash
# Build libaom - AV1 reference codec (BSD)
#
# Required environment:
#   PREFIX          - Installation prefix
#   LIBAOM_VERSION  - Git branch/tag (e.g., "v3.12.1")
#
# Optional:
#   DRY_RUN=1       - Echo commands instead of running
#   WORK_DIR        - Build directory (default: /tmp)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

build_libaom() {
    require PREFIX
    require LIBAOM_VERSION

    log "Building libaom ${LIBAOM_VERSION}"

    local work_dir="${WORK_DIR:-/tmp}/libaom-$$"
    run mkdir -p "$work_dir"
    enter "$work_dir"

    local git_url="https://aomedia.googlesource.com/aom"
    if [[ "$DRY_RUN" == "1" ]]; then
        check_git_ref "$git_url" "$LIBAOM_VERSION" || true
    fi
    run git clone --depth 1 --branch "${LIBAOM_VERSION}" "$git_url" aom

    run mkdir aom_build
    enter aom_build

    # NASM is x86-only, disable on ARM
    local enable_nasm="ON"
    local arch
    arch=$(uname -m)
    if [[ "$arch" == "aarch64" || "$arch" == "arm64" || "$arch" == arm* ]]; then
        enable_nasm="OFF"
    fi

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
        -DENABLE_NASM="$enable_nasm" \
        -DENABLE_DOCS=OFF \
        -DENABLE_EXAMPLES=OFF \
        -DENABLE_TESTS=OFF \
        -DCONFIG_AV1_ENCODER=1 \
        -DCONFIG_AV1_DECODER=1 \
        ${extra_cmake_flags[@]+"${extra_cmake_flags[@]}"} \
        ../aom

    run make -j"$(nproc_safe)"
    run make install

    enter /
    run rm -rf "$work_dir"

    log "libaom complete"
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && build_libaom
