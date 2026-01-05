#!/usr/bin/env bash
# Build libvpx - VP8/VP9 video codec (BSD)
#
# Required environment:
#   PREFIX          - Installation prefix
#   LIBVPX_VERSION  - Git branch/tag (e.g., "v1.15.2")
#
# Optional:
#   DRY_RUN=1       - Echo commands instead of running
#   WORK_DIR        - Build directory (default: /tmp)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

build_libvpx() {
    require PREFIX
    require LIBVPX_VERSION

    log "Building libvpx ${LIBVPX_VERSION}"

    local work_dir="${WORK_DIR:-/tmp}/libvpx-$$"
    run mkdir -p "$work_dir"
    enter "$work_dir"

    local git_url="https://chromium.googlesource.com/webm/libvpx.git"
    if [[ "$DRY_RUN" == "1" ]]; then
        check_git_ref "$git_url" "$LIBVPX_VERSION" || true
    fi
    run git clone --depth 1 --branch "${LIBVPX_VERSION}" "$git_url"

    enter libvpx

    # Build configure args
    local configure_args=(
        --prefix="$PREFIX"
        --disable-examples
        --disable-unit-tests
        --disable-docs
        --enable-vp9-highbitdepth
        --enable-static
        --disable-shared
        --enable-pic
    )

    # Determine architecture
    local arch="${MACOS_ARCH:-$(uname -m)}"

    # macOS needs explicit target
    if is_macos; then
        local darwin_version
        darwin_version="$(uname -r | cut -d. -f1)"
        configure_args+=("--target=${arch}-darwin${darwin_version}-gcc")
        # Pass deployment target via LDFLAGS
        if [[ -n "${EXTRA_LDFLAGS:-}" ]]; then
            configure_args+=("--extra-cflags=${EXTRA_CFLAGS:-}")
            configure_args+=("--extra-ldflags=${EXTRA_LDFLAGS:-}")
        fi
    fi

    # YASM is x86-only, skip on ARM
    if [[ "$arch" == "x86_64" || "$arch" == "i386" || "$arch" == "i686" ]]; then
        configure_args+=(--as=yasm)
    fi

    run ./configure "${configure_args[@]}"

    run make -j"$(nproc_safe)"
    run make install

    enter /
    run rm -rf "$work_dir"

    log "libvpx complete"
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && build_libvpx
