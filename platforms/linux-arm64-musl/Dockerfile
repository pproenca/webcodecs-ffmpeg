# FFmpeg Static Build Dockerfile for Linux ARM64 (musl)
# Uses Alpine Linux with musl libc for truly static binaries on ARM64
#
# Build: docker buildx build --platform linux/arm64 -f Dockerfile -t ffmpeg-builder:linux-arm64-musl .
# Extract: docker create --name tmp ffmpeg-builder:linux-arm64-musl && docker cp tmp:/build/bin .
#
# Library versions updated: January 2026

FROM --platform=linux/arm64 alpine:3.21 AS builder

# hadolint: DL4006 - Ensure pipe failures are caught
SHELL ["/bin/ash", "-o", "pipefail", "-c"]

# Build arguments - ALL values come from versions.properties (no defaults)
ARG X264_VERSION
ARG X265_VERSION
ARG LIBVPX_VERSION
ARG LIBAOM_VERSION
ARG SVTAV1_VERSION
ARG THEORA_VERSION
ARG THEORA_SHA256
ARG XVID_VERSION
ARG XVID_SHA256
ARG OPUS_VERSION
ARG OPUS_SHA256
ARG LAME_VERSION
ARG LAME_SHA256
ARG FDKAAC_VERSION
ARG FLAC_VERSION
ARG FLAC_SHA256
ARG SPEEX_VERSION
ARG SPEEX_SHA256
ARG LIBASS_VERSION
ARG LIBASS_SHA256
ARG FREETYPE_VERSION
ARG FREETYPE_SHA256
ARG DAV1D_VERSION
ARG DAV1D_URL
ARG DAV1D_SHA256
ARG OGG_VERSION
ARG OGG_URL
ARG OGG_SHA256
ARG VORBIS_VERSION
ARG VORBIS_URL
ARG VORBIS_SHA256
ARG FFMPEG_VERSION

# Install build dependencies (sorted alphabetically)
# Note: NASM/YASM omitted - these are x86 assemblers, not used on ARM
RUN apk add --no-cache \
    autoconf \
    automake \
    bash \
    build-base \
    ccache \
    cmake \
    coreutils \
    curl \
    diffutils \
    git \
    linux-headers \
    libtool \
    meson \
    ninja \
    perl \
    pkgconfig \
    wget \
    zlib-dev \
    zlib-static

# Set up build environment
# CRITICAL: -fPIC is required for all code that will be linked into shared objects
ENV PREFIX=/build
ENV PKG_CONFIG_PATH=$PREFIX/lib/pkgconfig
ENV PATH=/usr/lib/ccache:$PREFIX/bin:$PATH
ENV CCACHE_DIR=/cache
ENV MAKEFLAGS="-j$(nproc)"
ENV CFLAGS="-fPIC"
ENV CXXFLAGS="-fPIC"

WORKDIR /src

# Copy codec build scripts and patches
COPY build/codecs /codecs
COPY build/patches /patches

# ============================================================================
# Build codec libraries using scripts
# ============================================================================

# Video codecs
RUN export X264_VERSION="${X264_VERSION}" && /codecs/x264.sh
RUN export X265_VERSION="${X265_VERSION}" PATCH_DIR=/patches && /codecs/x265.sh
RUN export LIBVPX_VERSION="${LIBVPX_VERSION}" && /codecs/libvpx.sh
RUN export LIBAOM_VERSION="${LIBAOM_VERSION}" && /codecs/libaom.sh
RUN export DAV1D_VERSION="${DAV1D_VERSION}" DAV1D_URL="${DAV1D_URL}" DAV1D_SHA256="${DAV1D_SHA256}" && /codecs/dav1d.sh
RUN export SVTAV1_VERSION="${SVTAV1_VERSION}" && /codecs/svt-av1.sh
RUN export XVID_VERSION="${XVID_VERSION}" XVID_SHA256="${XVID_SHA256}" && /codecs/xvid.sh

# Audio codecs (ogg must be built before vorbis and theora)
RUN export OGG_VERSION="${OGG_VERSION}" OGG_URL="${OGG_URL}" OGG_SHA256="${OGG_SHA256}" && /codecs/ogg.sh
RUN export VORBIS_VERSION="${VORBIS_VERSION}" VORBIS_URL="${VORBIS_URL}" VORBIS_SHA256="${VORBIS_SHA256}" && /codecs/vorbis.sh
RUN export THEORA_VERSION="${THEORA_VERSION}" THEORA_SHA256="${THEORA_SHA256}" && /codecs/theora.sh
RUN export OPUS_VERSION="${OPUS_VERSION}" OPUS_SHA256="${OPUS_SHA256}" && /codecs/opus.sh
RUN export LAME_VERSION="${LAME_VERSION}" LAME_SHA256="${LAME_SHA256}" && /codecs/lame.sh
RUN export FDKAAC_VERSION="${FDKAAC_VERSION}" && /codecs/fdk-aac.sh
RUN export FLAC_VERSION="${FLAC_VERSION}" FLAC_SHA256="${FLAC_SHA256}" && /codecs/flac.sh
RUN export SPEEX_VERSION="${SPEEX_VERSION}" SPEEX_SHA256="${SPEEX_SHA256}" && /codecs/speex.sh

# Support libraries (no OpenSSL for musl - network disabled)
RUN export FREETYPE_VERSION="${FREETYPE_VERSION}" FREETYPE_SHA256="${FREETYPE_SHA256}" && /codecs/freetype.sh
RUN export LIBASS_VERSION="${LIBASS_VERSION}" LIBASS_SHA256="${LIBASS_SHA256}" && /codecs/libass.sh

# ============================================================================
# Build FFmpeg with all codecs (GPL due to x264/x265, Non-free due to fdk-aac)
# Note: FFmpeg has ARM64-specific optimizations (NEON)
# Using ARMv8-A architecture for optimal NEON SIMD performance
# ============================================================================
RUN git clone --depth 1 --branch ${FFMPEG_VERSION} https://git.ffmpeg.org/ffmpeg.git && \
    cd ffmpeg && \
    ./configure \
        --prefix=$PREFIX \
        --pkg-config-flags="--static" \
        --extra-cflags="-I$PREFIX/include -static -march=armv8-a" \
        --extra-ldflags="-L$PREFIX/lib -static" \
        --extra-libs="-lpthread -lm -lstdc++" \
        --enable-gpl \
        --enable-version3 \
        --enable-nonfree \
        --enable-static \
        --disable-shared \
        --enable-pic \
        --disable-ffplay \
        --disable-doc \
        --disable-debug \
        --disable-network \
        --enable-libx264 \
        --enable-libx265 \
        --enable-libvpx \
        --enable-libaom \
        --enable-libdav1d \
        --enable-libsvtav1 \
        --enable-libtheora \
        --enable-libxvid \
        --enable-libopus \
        --enable-libmp3lame \
        --enable-libfdk-aac \
        --enable-libspeex \
        --enable-libvorbis \
        --enable-libfreetype \
        --enable-libass && \
    make -j"$(nproc)" && \
    make install

# ============================================================================
# Clean up build artifacts not needed for distribution
# ============================================================================
RUN echo "=== Cleaning build artifacts ===" && \
    rm -rf $PREFIX/lib/pkgconfig && \
    find $PREFIX/lib -name "*.la" -type f -delete && \
    rm -rf $PREFIX/lib/cmake && \
    echo "Build artifacts cleaned"

# ============================================================================
# Strip debug symbols and verify static linking
# ============================================================================
RUN strip $PREFIX/bin/ffmpeg $PREFIX/bin/ffprobe && \
    echo "=== Verifying static binary ===" && \
    file $PREFIX/bin/ffmpeg && \
    # musl ldd says "Not a valid dynamic program" for static binaries
    # glibc ldd says "not a dynamic executable"
    if ldd $PREFIX/bin/ffmpeg 2>&1 | grep -qE "(not a dynamic executable|Not a valid dynamic program)"; then \
        echo "Binary is fully static"; \
    else \
        echo "Binary has dynamic dependencies:" && ldd $PREFIX/bin/ffmpeg && exit 1; \
    fi && \
    echo "=== Binary sizes ===" && \
    ls -lh $PREFIX/bin/ffmpeg $PREFIX/bin/ffprobe && \
    echo "=== FFmpeg version ===" && \
    $PREFIX/bin/ffmpeg -version

# ============================================================================
# Final stage - includes binaries AND dev files for native addon compilation
# ============================================================================
FROM scratch AS export

COPY --from=builder /build/bin/ffmpeg /build/bin/ffmpeg
COPY --from=builder /build/bin/ffprobe /build/bin/ffprobe

# For extraction via docker cp, we need a runnable container
FROM --platform=linux/arm64 alpine:3.21 AS runtime

# Copy binaries
COPY --from=builder /build/bin/ffmpeg /build/bin/ffmpeg
COPY --from=builder /build/bin/ffprobe /build/bin/ffprobe

# Copy development files needed for native addon compilation
# These are required by build-prebuilds.yml to link against FFmpeg
COPY --from=builder /build/lib /build/lib
COPY --from=builder /build/include /build/include

# Verify binaries work in clean Alpine environment
RUN /build/bin/ffmpeg -version

CMD ["/build/bin/ffmpeg", "-version"]
