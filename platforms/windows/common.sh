#!/usr/bin/env bash
# Shared Windows cross-compilation configuration
# Sourced by x64/build.sh and x64-dxva2/build.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/versions.sh"

# Paths
export PATCH_DIR="$SCRIPT_DIR/patches"

# MinGW cross-compilation target
export CROSS_PREFIX="x86_64-w64-mingw32-"
export MINGW_HOST="x86_64-w64-mingw32"

# Docker build context is platforms/windows/ to include patches
export DOCKER_CONTEXT="$SCRIPT_DIR"
