#!/usr/bin/env bash
# NVENC hardware acceleration flags for FFmpeg
#
# Enables NVIDIA GPU hardware encoding/decoding.
# Requires nv-codec-headers in the toolchain.

VARIANT_FLAGS=(
    --enable-nvenc
    --enable-nvdec
    --enable-cuda-llvm
    --enable-cuvid
    --enable-ffnvcodec
)
