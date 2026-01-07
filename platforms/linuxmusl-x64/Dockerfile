# =============================================================================
# FFmpeg Build Environment - linuxmusl-x64
# =============================================================================
# Alpine Linux 3.15 (musl libc, x86_64)
# Compatible with musl-based distributions
# =============================================================================

FROM alpine:3.15

# Install build dependencies
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
    nasm \
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
    yasm \
    zlib-dev

# Set environment for static builds
ENV PKG_CONFIG_PATH=/opt/ffmpeg/lib/pkgconfig
ENV PATH=/opt/ffmpeg/bin:$PATH
ENV MAKEFLAGS="-j$(nproc)"

WORKDIR /build

# Default command
CMD ["/bin/bash"]
