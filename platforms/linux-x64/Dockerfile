# =============================================================================
# FFmpeg Build Environment for linux-x64 (glibc)
# =============================================================================
# Base: Amazon Linux 2 (glibc 2.26)
# Architecture: x86_64
# =============================================================================

FROM amazonlinux:2

LABEL maintainer="Pedro Proenca"
LABEL description="FFmpeg build environment for linux-x64 (glibc)"

# Install build dependencies from Amazon Linux 2 repos
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

# Install NASM (required for x264/x265 assembly optimizations)
# Amazon Linux 2 has outdated NASM, install from source
ARG NASM_VERSION=2.16.03
RUN curl -fSL "https://www.nasm.us/pub/nasm/releasebuilds/${NASM_VERSION}/nasm-${NASM_VERSION}.tar.gz" -o nasm.tar.gz && \
    tar xzf nasm.tar.gz && \
    cd nasm-${NASM_VERSION} && \
    ./configure --prefix=/usr/local && \
    make -j"$(nproc)" && \
    make install && \
    cd .. && rm -rf nasm* && \
    nasm --version

# Install CMake 3.x (CMake 4.x breaks x265/aom/svt-av1)
# Amazon Linux 2 has cmake 2.x, need modern version
ARG CMAKE_VERSION=3.30.5
RUN curl -fSL "https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/cmake-${CMAKE_VERSION}-linux-x86_64.tar.gz" -o cmake.tar.gz && \
    tar xzf cmake.tar.gz -C /usr/local --strip-components=1 && \
    rm cmake.tar.gz && \
    cmake --version

# Install Python pip and then Meson/Ninja (required for dav1d)
# Amazon Linux 2 has Python 3.7, need to use compatible pip
RUN curl -fSL "https://bootstrap.pypa.io/pip/3.7/get-pip.py" -o get-pip.py && \
    python3 get-pip.py && \
    rm get-pip.py && \
    pip3 install --no-cache-dir meson ninja && \
    meson --version && \
    ninja --version

WORKDIR /build

# Default command (overridden by build.sh)
CMD ["bash"]
