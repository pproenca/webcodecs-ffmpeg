# =============================================================================
# FFmpeg Build Environment for linux-arm64v8 (glibc)
# =============================================================================
# Base: Amazon Linux 2 ARM64 (glibc 2.26)
# Architecture: aarch64 (ARM64)
# Build via QEMU on x64 runners
# =============================================================================

FROM arm64v8/amazonlinux:2

LABEL maintainer="Pedro Proenca"
LABEL description="FFmpeg build environment for linux-arm64v8 (glibc)"

# Install build dependencies from Amazon Linux 2 repos
# hadolint ignore=DL3033
RUN yum update -y && \
    yum install -y \
        gcc \
        gcc-c++ \
        make \
        autoconf \
        automake \
        libtool \
        pkgconfig \
        git \
        curl \
        tar \
        xz \
        bzip2 \
        diffutils \
        perl \
        which \
        perl-IPC-Cmd \
        perl-FindBin \
    && yum clean all

# Note: NASM is not available for ARM64 - x264/x265 will use C fallbacks
# ARM64 has NEON optimizations built-in for most codecs

# Install CMake 3.x (CMake 4.x breaks x265/aom/svt-av1)
# Use ARM64 binary
ARG CMAKE_VERSION=3.30.5
RUN curl -fSL "https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/cmake-${CMAKE_VERSION}-linux-aarch64.tar.gz" -o cmake.tar.gz && \
    tar xzf cmake.tar.gz -C /usr/local --strip-components=1 && \
    rm cmake.tar.gz && \
    cmake --version

# Install Python pip and then Meson/Ninja (required for dav1d)
# hadolint ignore=DL3013
RUN curl -fSL "https://bootstrap.pypa.io/pip/3.7/get-pip.py" -o get-pip.py && \
    python3 get-pip.py && \
    rm get-pip.py && \
    pip3 install --no-cache-dir meson ninja && \
    meson --version && \
    ninja --version

WORKDIR /build

CMD ["bash"]
