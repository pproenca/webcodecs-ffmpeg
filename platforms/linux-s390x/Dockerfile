# =============================================================================
# FFmpeg Build Environment - linux-s390x
# =============================================================================
# Debian Bullseye (glibc, s390x - IBM Z mainframe)
# =============================================================================

FROM s390x/debian:bullseye

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install build dependencies
# Note: NASM is x86-only, s390x uses z/Architecture vector instructions
RUN apt-get update && apt-get install -y --no-install-recommends \
    autoconf \
    automake \
    build-essential \
    ca-certificates \
    cmake \
    curl \
    diffutils \
    file \
    g++ \
    gcc \
    git \
    libtool \
    make \
    meson \
    ninja-build \
    patch \
    perl \
    pkg-config \
    python3 \
    python3-pip \
    tar \
    texinfo \
    wget \
    xz-utils \
    zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

# Set environment for static builds
ENV PKG_CONFIG_PATH=/opt/ffmpeg/lib/pkgconfig
ENV PATH=/opt/ffmpeg/bin:$PATH
ENV MAKEFLAGS="-j$(nproc)"

WORKDIR /build

# Default command
CMD ["/bin/bash"]
