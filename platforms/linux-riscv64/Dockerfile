# =============================================================================
# FFmpeg Build Environment - linux-riscv64
# =============================================================================
# Debian Sid (glibc, RISC-V 64-bit)
# Note: Using Sid as stable Debian has limited riscv64 support
# =============================================================================

FROM riscv64/debian:sid

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install build dependencies
# Note: NASM is x86-only, RISC-V uses RVV (Vector) intrinsics where available
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
