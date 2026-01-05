# FFmpeg Toolchain for Linux glibc builds with NVENC support
# Extends glibc toolchain with NVIDIA codec SDK headers
#
# Usage: docker build -t ffmpeg-toolchain:glibc-nvenc -f glibc-nvenc.Dockerfile .

FROM ubuntu:24.04

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ENV DEBIAN_FRONTEND=noninteractive

# Build tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    autoconf automake bash build-essential ca-certificates ccache cmake \
    coreutils curl diffutils git libtool linux-libc-dev meson nasm \
    ninja-build patch perl pkg-config wget yasm zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

# Install NVIDIA codec SDK headers (nv-codec-headers)
# These are header-only, no runtime dependency
RUN git clone --depth 1 https://github.com/FFmpeg/nv-codec-headers.git /tmp/nv-codec-headers && \
    cd /tmp/nv-codec-headers && \
    make PREFIX=/usr install && \
    rm -rf /tmp/nv-codec-headers

# Build environment
ENV PREFIX=/build
ENV PKG_CONFIG_PATH=$PREFIX/lib/pkgconfig
ENV PATH=/usr/lib/ccache:$PREFIX/bin:$PATH
ENV CCACHE_DIR=/ccache

# Create build directories
RUN mkdir -p $PREFIX /src /ccache

WORKDIR /src
