# FFmpeg Toolchain for Linux musl builds
# Alpine-based, fully static builds
# Rebuild only when toolchain changes (rare)
#
# Usage: docker build -t ffmpeg-toolchain:musl -f musl.Dockerfile .

FROM alpine:3.21

# Build tools only - no codec builds, no FFmpeg
RUN apk add --no-cache \
    autoconf automake bash build-base ca-certificates cmake curl \
    diffutils git libtool linux-headers meson nasm ninja patch \
    perl pkgconf wget yasm zlib-dev

# Build environment
ENV PREFIX=/build
ENV PKG_CONFIG_PATH=$PREFIX/lib/pkgconfig
ENV PATH=$PREFIX/bin:$PATH

# Create build directories
RUN mkdir -p $PREFIX /src

WORKDIR /src
