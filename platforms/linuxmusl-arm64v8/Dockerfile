# =============================================================================
# FFmpeg Build Environment - linuxmusl-arm64v8
# =============================================================================
# Alpine Linux 3.15 (musl libc, ARM64)
# Compatible with musl-based distributions on ARM64
# =============================================================================

FROM arm64v8/alpine:3.15

# Install build dependencies
# Note: NASM is x86-only, ARM64 uses built-in NEON intrinsics
# hadolint ignore=DL3018
RUN apk add --no-cache \
    autoconf \
    automake \
    bash \
    binutils \
    bzip2 \
    cmake \
    coreutils \
    curl \
    diffutils \
    file \
    g++ \
    gcc \
    git \
    libtool \
    linux-headers \
    make \
    meson \
    musl-dev \
    ninja \
    patch \
    perl \
    pkgconf \
    py3-pip \
    python3 \
    samurai \
    tar \
    texinfo \
    wget \
    xz \
    zlib-dev

# Set environment for static builds
ENV PKG_CONFIG_PATH=/opt/ffmpeg/lib/pkgconfig
ENV PATH=/opt/ffmpeg/bin:$PATH
ENV MAKEFLAGS="-j$(nproc)"

WORKDIR /build

# Default command
CMD ["/bin/bash"]
