#!/usr/bin/env bash
# Build OpenSSL - TLS/network support
#
# Required environment:
#   PREFIX            - Installation prefix
#   OPENSSL_VERSION   - Version number (e.g., "3.4.0")
#   OPENSSL_URL       - Download URL for tarball
#   OPENSSL_SHA256    - SHA256 checksum
#
# Optional:
#   OPENSSL_TARGET    - OpenSSL target (default: linux-x86_64)
#   DRY_RUN=1         - Echo commands instead of running
#   WORK_DIR          - Build directory (default: /tmp)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

build_openssl() {
    require PREFIX
    require OPENSSL_VERSION
    require OPENSSL_URL
    require OPENSSL_SHA256

    log "Building OpenSSL ${OPENSSL_VERSION}"

    local work_dir="${WORK_DIR:-/tmp}/openssl-$$"

    # Auto-detect OpenSSL target if not set
    local target="${OPENSSL_TARGET:-}"
    if [[ -z "$target" ]]; then
        if is_macos; then
            local arch="${MACOS_ARCH:-$(uname -m)}"
            target="darwin64-${arch}-cc"
            log "Auto-detected macOS OpenSSL target: $target"
        else
            target="linux-x86_64"
        fi
    fi

    run mkdir -p "$work_dir"
    enter "$work_dir"

    download_verify "$OPENSSL_URL" "openssl-${OPENSSL_VERSION}.tar.gz" "$OPENSSL_SHA256"
    extract "openssl-${OPENSSL_VERSION}.tar.gz"

    enter "openssl-${OPENSSL_VERSION}"

    # OpenSSL uses ./Configure (perl), not ./configure
    run ./Configure \
        "$target" \
        --prefix="$PREFIX" \
        --openssldir="$PREFIX/ssl" \
        no-shared \
        no-tests \
        enable-static \
        -fPIC

    run make -j"$(nproc_safe)"
    run make install_sw install_ssldirs

    enter /
    run rm -rf "$work_dir"

    log "OpenSSL complete"
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && build_openssl
