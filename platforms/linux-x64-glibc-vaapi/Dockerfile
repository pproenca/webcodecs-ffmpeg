# FFmpeg Hardware-Accelerated Build for Linux x64 (glibc + VA-API)
# Uses Ubuntu 24.04 with Intel/AMD GPU acceleration via VA-API
#
# Hardware Acceleration: VA-API (Video Acceleration API)
# - Intel integrated GPUs (HD Graphics, Iris, Arc)
# - AMD GPUs (Radeon with open-source drivers)
# - Requires: /dev/dri/renderD128 device at runtime
#
# This variant includes all software codecs PLUS hardware encoding/decoding.
# Use this for video processing on Intel/AMD GPU systems.
#
# Build: docker build -f Dockerfile -t ffmpeg-builder:linux-x64-glibc-vaapi .
# Extract: docker create --name tmp ffmpeg-builder:linux-x64-glibc-vaapi && docker cp tmp:/build .
#
# Library versions updated: January 2026

FROM ubuntu:24.04 AS builder

# hadolint: DL4006 - Ensure pipe failures are caught
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

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

# Prevent interactive prompts during apt-get
ENV DEBIAN_FRONTEND=noninteractive

# Install build dependencies + VA-API hardware acceleration libraries (sorted alphabetically)
RUN apt-get update && apt-get install -y --no-install-recommends \
    autoconf \
    automake \
    bash \
    build-essential \
    ca-certificates \
    ccache \
    cmake \
    coreutils \
    curl \
    diffutils \
    git \
    libdrm-dev \
    libtool \
    libva-dev \
    linux-libc-dev \
    meson \
    nasm \
    ninja-build \
    patch \
    perl \
    pkg-config \
    wget \
    yasm \
    zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

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
RUN X264_VERSION="${X264_VERSION}" /codecs/x264.sh
RUN X265_VERSION="${X265_VERSION}" PATCH_DIR=/patches /codecs/x265.sh
RUN LIBVPX_VERSION="${LIBVPX_VERSION}" /codecs/libvpx.sh
RUN LIBAOM_VERSION="${LIBAOM_VERSION}" /codecs/libaom.sh
RUN DAV1D_VERSION="${DAV1D_VERSION}" DAV1D_URL="${DAV1D_URL}" DAV1D_SHA256="${DAV1D_SHA256}" /codecs/dav1d.sh
RUN SVTAV1_VERSION="${SVTAV1_VERSION}" /codecs/svt-av1.sh
RUN THEORA_VERSION="${THEORA_VERSION}" THEORA_SHA256="${THEORA_SHA256}" /codecs/theora.sh
RUN XVID_VERSION="${XVID_VERSION}" XVID_SHA256="${XVID_SHA256}" /codecs/xvid.sh

# Audio codecs
RUN OPUS_VERSION="${OPUS_VERSION}" OPUS_SHA256="${OPUS_SHA256}" /codecs/opus.sh
RUN LAME_VERSION="${LAME_VERSION}" LAME_SHA256="${LAME_SHA256}" /codecs/lame.sh
RUN FDKAAC_VERSION="${FDKAAC_VERSION}" /codecs/fdk-aac.sh
RUN FLAC_VERSION="${FLAC_VERSION}" FLAC_SHA256="${FLAC_SHA256}" /codecs/flac.sh
RUN SPEEX_VERSION="${SPEEX_VERSION}" SPEEX_SHA256="${SPEEX_SHA256}" /codecs/speex.sh
RUN OGG_VERSION="${OGG_VERSION}" OGG_URL="${OGG_URL}" OGG_SHA256="${OGG_SHA256}" /codecs/ogg.sh
RUN VORBIS_VERSION="${VORBIS_VERSION}" VORBIS_URL="${VORBIS_URL}" VORBIS_SHA256="${VORBIS_SHA256}" /codecs/vorbis.sh

# Support libraries
RUN FREETYPE_VERSION="${FREETYPE_VERSION}" FREETYPE_SHA256="${FREETYPE_SHA256}" /codecs/freetype.sh
RUN LIBASS_VERSION="${LIBASS_VERSION}" LIBASS_SHA256="${LIBASS_SHA256}" /codecs/libass.sh

# ============================================================================
# Build FFmpeg with all codecs + VA-API (GPL due to x264/x265, Non-free due to fdk-aac)
# Note: We don't use -static here because we want libs that can link into .so
# ============================================================================
RUN git clone --depth 1 --branch ${FFMPEG_VERSION} https://git.ffmpeg.org/ffmpeg.git && \
    cd ffmpeg && \
    ./configure \
        --prefix=$PREFIX \
        --pkg-config-flags="--static" \
        --extra-cflags="-I$PREFIX/include -fPIC" \
        --extra-ldflags="-L$PREFIX/lib" \
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
        --enable-libass \
        --enable-vaapi && \
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
# Strip debug symbols and verify PIC in static libraries
# ============================================================================
RUN strip $PREFIX/bin/ffmpeg $PREFIX/bin/ffprobe && \
    echo "=== Verifying PIC in static libraries ===" && \
    for lib in "${PREFIX}"/lib/*.a; do \
        echo "Checking ${lib} for PIC..."; \
        if ar -t "${lib}" 2>/dev/null | head -1 | xargs -I{} sh -c "ar -p '${lib}' {} 2>/dev/null | readelf -r - 2>/dev/null | grep -q 'R_X86_64_32'"; then \
            echo "WARNING: ${lib} may have non-PIC code"; \
        else \
            echo "OK: ${lib}"; \
        fi; \
    done && \
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
FROM ubuntu:24.04 AS runtime

# Copy binaries
COPY --from=builder /build/bin/ffmpeg /build/bin/ffmpeg
COPY --from=builder /build/bin/ffprobe /build/bin/ffprobe

# Copy development files needed for native addon compilation
# These are required by build-prebuilds.yml to link against FFmpeg
COPY --from=builder /build/lib /build/lib
COPY --from=builder /build/include /build/include

# Verify binaries work (will link against system glibc)
RUN /build/bin/ffmpeg -version

CMD ["/build/bin/ffmpeg", "-version"]
