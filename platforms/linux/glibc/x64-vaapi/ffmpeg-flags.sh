#!/usr/bin/env bash
# VA-API hardware acceleration flags for FFmpeg
#
# Enables Intel/AMD GPU hardware acceleration via VA-API.
# Requires libva-dev and libdrm-dev in the toolchain.

VARIANT_FLAGS=(
    --enable-vaapi
    --enable-libdrm
)
