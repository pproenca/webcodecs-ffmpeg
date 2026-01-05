# FFmpeg Toolchain for Linux glibc builds
# Contains only build tools - no codecs, no FFmpeg
# Rebuild only when toolchain changes (rare)
#
# Usage: docker build -t ffmpeg-toolchain:glibc -f glibc.Dockerfile .

FROM ubuntu:24.04

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ENV DEBIAN_FRONTEND=noninteractive

# Build tools only - no codec builds, no FFmpeg
RUN apt-get update && apt-get install -y --no-install-recommends \
    autoconf automake bash build-essential ca-certificates ccache cmake \
    coreutils curl diffutils git libtool linux-libc-dev meson nasm \
    ninja-build patch perl pkg-config wget yasm zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

# Build environment
ENV PREFIX=/build
ENV PKG_CONFIG_PATH=$PREFIX/lib/pkgconfig
ENV PATH=/usr/lib/ccache:$PREFIX/bin:$PATH
ENV CCACHE_DIR=/ccache

# Create build directories
RUN mkdir -p $PREFIX /src /ccache

WORKDIR /src
