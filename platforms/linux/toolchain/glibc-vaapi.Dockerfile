# FFmpeg Toolchain for Linux glibc builds with VA-API support
# Extends glibc toolchain with VA-API development libraries
#
# Usage: docker build -t ffmpeg-toolchain:glibc-vaapi -f glibc-vaapi.Dockerfile .

FROM ubuntu:24.04

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ENV DEBIAN_FRONTEND=noninteractive

# Build tools + VA-API development libraries
RUN apt-get update && apt-get install -y --no-install-recommends \
    autoconf automake bash build-essential ca-certificates ccache cmake \
    coreutils curl diffutils git libtool linux-libc-dev meson nasm \
    ninja-build patch perl pkg-config wget yasm zlib1g-dev \
    libva-dev libdrm-dev \
    && rm -rf /var/lib/apt/lists/*

# Build environment
ENV PREFIX=/build
ENV PKG_CONFIG_PATH=$PREFIX/lib/pkgconfig
ENV PATH=/usr/lib/ccache:$PREFIX/bin:$PATH
ENV CCACHE_DIR=/ccache

# Create build directories
RUN mkdir -p $PREFIX /src /ccache

WORKDIR /src
