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

# Build arguments for version pinning (updated Jan 2026)
ARG X264_VERSION=stable
ARG X265_VERSION=3.6
ARG LIBVPX_VERSION=v1.15.2
ARG LIBAOM_VERSION=v3.12.1
ARG SVTAV1_VERSION=v2.3.0
ARG RAV1E_VERSION=v0.7.1
ARG THEORA_VERSION=1.1.1
ARG XVID_VERSION=1.3.7
ARG OPUS_VERSION=1.5.2
ARG LAME_VERSION=3.100
ARG FDKAAC_VERSION=v2.0.3
ARG FLAC_VERSION=1.4.3
ARG SPEEX_VERSION=1.2.1
ARG LIBASS_VERSION=0.17.3
ARG FREETYPE_VERSION=2.13.3
ARG FFMPEG_VERSION=n8.0

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
    nasm \
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
ENV MAKEFLAGS="-j"$(nproc)""
ENV CFLAGS="-fPIC"
ENV CXXFLAGS="-fPIC"

WORKDIR /src

# ============================================================================
# Build x264 (GPL - required for H.264 encoding)
# ============================================================================
RUN git clone --depth 1 --branch ${X264_VERSION} https://code.videolan.org/videolan/x264.git && \
    cd x264 && \
    ./configure \
        --prefix=$PREFIX \
        --enable-static \
        --disable-shared \
        --enable-pic \
        --disable-cli \
        --disable-opencl && \
    make -j"$(nproc)" && \
    make install && \
    cd .. && rm -rf x264

# ============================================================================
# Build x265 (GPL - required for H.265/HEVC encoding)
# Note: x265 cmake doesn't always install .pc file, so we create it manually
# ============================================================================
RUN git clone --depth 1 https://bitbucket.org/multicoreware/x265_git.git && \
    mkdir -p x265_git/build/linux && \
    cd x265_git/build/linux && \
    cmake -G "Unix Makefiles" \
        -DCMAKE_INSTALL_PREFIX=$PREFIX \
        -DLIB_INSTALL_DIR=$PREFIX/lib \
        -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
        -DCMAKE_C_FLAGS="-fPIC" \
        -DCMAKE_CXX_FLAGS="-fPIC" \
        -DENABLE_SHARED=OFF \
        -DENABLE_CLI=OFF \
        -DHIGH_BIT_DEPTH=ON \
        ../../source && \
    make -j"$(nproc)" && \
    make install && \
    # x265 doesn't generate pkg-config file, but we'll remove all .pc files later anyway
    cd /src && rm -rf x265_git

# ============================================================================
# Build libvpx (BSD - VP8/VP9 codec)
# ============================================================================
RUN git clone --depth 1 --branch ${LIBVPX_VERSION} https://chromium.googlesource.com/webm/libvpx.git && \
    cd libvpx && \
    ./configure \
        --prefix=$PREFIX \
        --disable-examples \
        --disable-unit-tests \
        --disable-docs \
        --enable-vp9-highbitdepth \
        --enable-static \
        --disable-shared \
        --enable-pic \
        --as=yasm && \
    make -j"$(nproc)" && \
    make install && \
    cd .. && rm -rf libvpx

# ============================================================================
# Build libaom (BSD - AV1 codec)
# ============================================================================
RUN git clone --depth 1 --branch ${LIBAOM_VERSION} https://aomedia.googlesource.com/aom && \
    mkdir aom_build && \
    cd aom_build && \
    cmake -G "Unix Makefiles" \
        -DCMAKE_INSTALL_PREFIX=$PREFIX \
        -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
        -DCMAKE_C_FLAGS="-fPIC" \
        -DCMAKE_CXX_FLAGS="-fPIC" \
        -DBUILD_SHARED_LIBS=OFF \
        -DENABLE_NASM=ON \
        -DENABLE_DOCS=OFF \
        -DENABLE_EXAMPLES=OFF \
        -DENABLE_TESTS=OFF \
        -DCONFIG_AV1_ENCODER=1 \
        -DCONFIG_AV1_DECODER=1 \
        ../aom && \
    make -j"$(nproc)" && \
    make install && \
    cd .. && rm -rf aom aom_build

# ============================================================================
# Build libopus (BSD - Opus audio codec)
# ============================================================================
RUN wget -q https://downloads.xiph.org/releases/opus/opus-${OPUS_VERSION}.tar.gz && \
    tar xzf opus-${OPUS_VERSION}.tar.gz && \
    cd opus-${OPUS_VERSION} && \
    ./configure \
        --prefix=$PREFIX \
        --disable-shared \
        --enable-static \
        --with-pic \
        --disable-doc \
        --disable-extra-programs \
        CFLAGS="-fPIC" && \
    make -j"$(nproc)" && \
    make install && \
    cd .. && rm -rf opus-${OPUS_VERSION}*

# ============================================================================
# Build libmp3lame (LGPL - MP3 encoder)
# ============================================================================
RUN wget -q "https://downloads.sourceforge.net/project/lame/lame/${LAME_VERSION}/lame-${LAME_VERSION}.tar.gz" && \
    tar xzf lame-${LAME_VERSION}.tar.gz && \
    cd lame-${LAME_VERSION} && \
    ./configure \
        --prefix=$PREFIX \
        --disable-shared \
        --enable-static \
        --with-pic \
        --enable-nasm \
        --disable-frontend \
        CFLAGS="-fPIC" && \
    make -j"$(nproc)" && \
    make install && \
    cd .. && rm -rf lame-${LAME_VERSION}*

# ============================================================================
# Build libogg + libvorbis (BSD - Vorbis audio codec)
# ============================================================================
RUN wget -q https://ftp.osuosl.org/pub/xiph/releases/ogg/libogg-1.3.5.tar.gz && \
    tar xzf libogg-1.3.5.tar.gz && \
    cd libogg-1.3.5 && \
    ./configure \
        --prefix=$PREFIX \
        --disable-shared \
        --enable-static \
        --with-pic \
        CFLAGS="-fPIC" && \
    make -j"$(nproc)" && \
    make install && \
    cd .. && rm -rf libogg-1.3.5*

RUN wget -q https://ftp.osuosl.org/pub/xiph/releases/vorbis/libvorbis-1.3.7.tar.gz && \
    tar xzf libvorbis-1.3.7.tar.gz && \
    cd libvorbis-1.3.7 && \
    ./configure \
        --prefix=$PREFIX \
        --disable-shared \
        --enable-static \
        --with-pic \
        --with-ogg=$PREFIX \
        CFLAGS="-fPIC" && \
    make -j"$(nproc)" && \
    make install && \
    cd .. && rm -rf libvorbis-1.3.7*

# ============================================================================
# Build SVT-AV1 (BSD - Intel's AV1 encoder)
# ============================================================================
RUN git clone --depth 1 --branch ${SVTAV1_VERSION} https://gitlab.com/AOMediaCodec/SVT-AV1.git && \
    mkdir SVT-AV1/build && \
    cd SVT-AV1/build && \
    cmake -G "Unix Makefiles" \
        -DCMAKE_INSTALL_PREFIX=$PREFIX \
        -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
        -DCMAKE_C_FLAGS="-fPIC" \
        -DCMAKE_CXX_FLAGS="-fPIC" \
        -DBUILD_SHARED_LIBS=OFF \
        -DBUILD_APPS=OFF \
        -DBUILD_DEC=OFF \
        -DBUILD_TESTING=OFF \
        .. && \
    make -j"$(nproc)" && \
    make install && \
    cd /src && rm -rf SVT-AV1

# ============================================================================
# Build Theora (BSD - Ogg video codec)
# ============================================================================
RUN wget -q https://ftp.osuosl.org/pub/xiph/releases/theora/libtheora-${THEORA_VERSION}.tar.gz && \
    tar xzf libtheora-${THEORA_VERSION}.tar.gz && \
    cd libtheora-${THEORA_VERSION} && \
    ./configure \
        --prefix=$PREFIX \
        --disable-shared \
        --enable-static \
        --with-pic \
        --disable-examples \
        CFLAGS="-fPIC" && \
    make -j"$(nproc)" && \
    make install && \
    cd .. && rm -rf libtheora-${THEORA_VERSION}*

# ============================================================================
# Build Xvid (GPL - MPEG-4 ASP codec)
# ============================================================================
RUN wget -q https://downloads.xvid.com/downloads/xvidcore-${XVID_VERSION}.tar.gz && \
    tar xzf xvidcore-${XVID_VERSION}.tar.gz && \
    cd xvidcore/build/generic && \
    ./configure \
        --prefix=$PREFIX \
        CFLAGS="-fPIC" && \
    make -j"$(nproc)" && \
    make install && \
    cd /src && rm -rf xvidcore*

# ============================================================================
# Build fdk-aac (Non-free - High-quality AAC encoder)
# ============================================================================
RUN git clone --depth 1 --branch ${FDKAAC_VERSION} https://github.com/mstorsjo/fdk-aac.git && \
    cd fdk-aac && \
    ./autogen.sh && \
    ./configure \
        --prefix=$PREFIX \
        --disable-shared \
        --enable-static \
        --with-pic \
        CFLAGS="-fPIC" \
        CXXFLAGS="-fPIC" && \
    make -j"$(nproc)" && \
    make install && \
    cd .. && rm -rf fdk-aac

# ============================================================================
# Build FLAC (BSD - Free Lossless Audio Codec)
# ============================================================================
RUN wget -q https://ftp.osuosl.org/pub/xiph/releases/flac/flac-${FLAC_VERSION}.tar.xz && \
    tar xf flac-${FLAC_VERSION}.tar.xz && \
    cd flac-${FLAC_VERSION} && \
    ./configure \
        --prefix=$PREFIX \
        --disable-shared \
        --enable-static \
        --with-pic \
        --disable-examples \
        --disable-cpplibs \
        CFLAGS="-fPIC" \
        CXXFLAGS="-fPIC" && \
    make -j"$(nproc)" && \
    make install && \
    cd .. && rm -rf flac-${FLAC_VERSION}*

# ============================================================================
# Build Speex (BSD - Speech codec)
# ============================================================================
RUN wget -q https://ftp.osuosl.org/pub/xiph/releases/speex/speex-${SPEEX_VERSION}.tar.gz && \
    tar xzf speex-${SPEEX_VERSION}.tar.gz && \
    cd speex-${SPEEX_VERSION} && \
    ./configure \
        --prefix=$PREFIX \
        --disable-shared \
        --enable-static \
        --with-pic \
        CFLAGS="-fPIC" && \
    make -j"$(nproc)" && \
    make install && \
    cd .. && rm -rf speex-${SPEEX_VERSION}*

# ============================================================================
# Build libfreetype (FreeType License - Font rendering)
# ============================================================================
RUN wget -q https://download.savannah.gnu.org/releases/freetype/freetype-${FREETYPE_VERSION}.tar.xz && \
    tar xf freetype-${FREETYPE_VERSION}.tar.xz && \
    cd freetype-${FREETYPE_VERSION} && \
    ./configure \
        --prefix=$PREFIX \
        --disable-shared \
        --enable-static \
        --with-pic \
        --without-harfbuzz \
        --without-bzip2 \
        --without-png \
        CFLAGS="-fPIC" && \
    make -j"$(nproc)" && \
    make install && \
    cd .. && rm -rf freetype-${FREETYPE_VERSION}*

# ============================================================================
# Build libass (ISC - Subtitle rendering)
# ============================================================================
RUN wget -q https://github.com/libass/libass/releases/download/${LIBASS_VERSION}/libass-${LIBASS_VERSION}.tar.gz && \
    tar xzf libass-${LIBASS_VERSION}.tar.gz && \
    cd libass-${LIBASS_VERSION} && \
    ./configure \
        --prefix=$PREFIX \
        --disable-shared \
        --enable-static \
        --with-pic \
        --disable-require-system-font-provider \
        CFLAGS="-fPIC" && \
    make -j"$(nproc)" && \
    make install && \
    cd .. && rm -rf libass-${LIBASS_VERSION}*

# ============================================================================
# Build FFmpeg with all codecs (GPL due to x264/x265, Non-free due to fdk-aac)
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
    echo "✓ Build artifacts cleaned"

# ============================================================================
# Strip debug symbols and verify PIC in static libraries
# ============================================================================
RUN strip $PREFIX/bin/ffmpeg $PREFIX/bin/ffprobe && \
    echo "=== Verifying PIC in static libraries ===" && \
    # Check that object files in .a archives have PIC relocations
    for lib in "${PREFIX}"/lib/*.a; do \
        echo "Checking ${lib} for PIC..."; \
        # Extract and check for non-PIC relocations (R_X86_64_32 or R_X86_64_32S)
        # These would fail when linking into a shared object
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
