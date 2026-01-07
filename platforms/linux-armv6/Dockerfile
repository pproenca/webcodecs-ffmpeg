# =============================================================================
# FFmpeg Build Environment - linux-armv6
# =============================================================================
# Debian Bullseye (glibc, ARMv6 - Raspberry Pi Zero/1)
# Amazon Linux 2 doesn't support armv6, so we use Debian
# =============================================================================

FROM arm32v6/debian:bullseye

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install build dependencies
# Note: NASM is x86-only, ARM uses built-in VFP/NEON intrinsics
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

# Create build user (non-root)
RUN useradd -m -d /build builder
USER builder
WORKDIR /build

# Default command
CMD ["/bin/bash"]
