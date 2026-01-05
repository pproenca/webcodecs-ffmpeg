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

# SHA256 checksums for tarball verification
ARG THEORA_SHA256
ARG XVID_SHA256
ARG OPUS_SHA256
ARG LAME_SHA256
ARG FLAC_SHA256
ARG SPEEX_SHA256
ARG LIBASS_SHA256
ARG FREETYPE_SHA256

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
ENV MAKEFLAGS="-j"$(nproc)""
ENV CFLAGS="-fPIC"
ENV CXXFLAGS="-fPIC"

WORKDIR /src

# Copy patches for source compatibility
COPY build/patches/x265-cmake4-compat.patch /tmp/x265-cmake4-compat.patch

# ============================================================================
# Build x264 (GPL - required for H.264 encoding)
# Note: x264 has ARM64-specific optimizations (NEON intrinsics)
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
# Note: x265 has ARM64 NEON support
# ============================================================================
RUN git clone --depth 1 --branch ${X265_VERSION} https://bitbucket.org/multicoreware/x265_git.git && \
    cd x265_git && \
    patch -p1 < /tmp/x265-cmake4-compat.patch && \
    mkdir -p build/linux && \
    cd build/linux && \
    cmake -G "Unix Makefiles" \
        -DCMAKE_INSTALL_PREFIX=$PREFIX \
        -DLIB_INSTALL_DIR=$PREFIX/lib \
        -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
        -DCMAKE_C_FLAGS="-fPIC" \
        -DCMAKE_CXX_FLAGS="-fPIC" \
        -DENABLE_SHARED=OFF \
        -DENABLE_CLI=OFF \
        -DSTATIC_LINK_CRT=ON \
        -DHIGH_BIT_DEPTH=ON \
        ../../source && \
    make -j"$(nproc)" && \
    make install && \
    cd /src && rm -rf x265_git

# ============================================================================
# Build libvpx (BSD - VP8/VP9 codec)
# Note: libvpx auto-detects ARM64 and uses NEON intrinsics
# Note: --as=yasm omitted - YASM is an x86 assembler, not used on ARM
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
        --enable-pic && \
    make -j"$(nproc)" && \
    make install && \
    cd .. && rm -rf libvpx

# ============================================================================
# Build libaom (BSD - AV1 codec)
# Note: libaom has ARM64 optimizations
# NASM is an x86 assembler and must be disabled on ARM platforms
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
        -DENABLE_NASM=OFF \
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
    echo "${OPUS_SHA256}  opus-${OPUS_VERSION}.tar.gz" | sha256sum -c - && \
    tar xzf opus-${OPUS_VERSION}.tar.gz && \
    cd opus-${OPUS_VERSION} && \
    ./configure \
        --prefix=$PREFIX \
        --disable-shared \
        --enable-static \
        --with-pic \
        --disable-doc \
        --disable-extra-programs && \
    make -j"$(nproc)" && \
    make install && \
    cd .. && rm -rf opus-${OPUS_VERSION}*

# ============================================================================
# Build libmp3lame (LGPL - MP3 encoder)
# Note: --enable-nasm omitted - NASM is an x86 assembler, not used on ARM
# ============================================================================
RUN wget -q "https://downloads.sourceforge.net/project/lame/lame/${LAME_VERSION}/lame-${LAME_VERSION}.tar.gz" && \
    echo "${LAME_SHA256}  lame-${LAME_VERSION}.tar.gz" | sha256sum -c - && \
    tar xzf lame-${LAME_VERSION}.tar.gz && \
    cd lame-${LAME_VERSION} && \
    ./configure \
        --prefix=$PREFIX \
        --disable-shared \
        --enable-static \
        --with-pic \
        --disable-frontend && \
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
        --with-pic && \
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
        --with-ogg=$PREFIX && \
    make -j"$(nproc)" && \
    make install && \
    cd .. && rm -rf libvorbis-1.3.7*

# ============================================================================
# Build SVT-AV1 (BSD - Intel's AV1 encoder)
# Note: SVT-AV1 supports ARM64 with NEON optimizations
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
    echo "${THEORA_SHA256}  libtheora-${THEORA_VERSION}.tar.gz" | sha256sum -c - && \
    tar xzf libtheora-${THEORA_VERSION}.tar.gz && \
    cd libtheora-${THEORA_VERSION} && \
    ./configure \
        --prefix=$PREFIX \
        --disable-shared \
        --enable-static \
        --disable-examples && \
    make -j"$(nproc)" && \
    make install && \
    cd .. && rm -rf libtheora-${THEORA_VERSION}*

# ============================================================================
# Build Xvid (GPL - MPEG-4 ASP codec)
# ============================================================================
RUN wget -q https://downloads.xvid.com/downloads/xvidcore-${XVID_VERSION}.tar.gz && \
    echo "${XVID_SHA256}  xvidcore-${XVID_VERSION}.tar.gz" | sha256sum -c - && \
    tar xzf xvidcore-${XVID_VERSION}.tar.gz && \
    cd xvidcore/build/generic && \
    ./configure --prefix=$PREFIX && \
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
        --enable-static && \
    make -j"$(nproc)" && \
    make install && \
    cd .. && rm -rf fdk-aac

# ============================================================================
# Build FLAC (BSD - Free Lossless Audio Codec)
# ============================================================================
RUN wget -q https://ftp.osuosl.org/pub/xiph/releases/flac/flac-${FLAC_VERSION}.tar.xz && \
    echo "${FLAC_SHA256}  flac-${FLAC_VERSION}.tar.xz" | sha256sum -c - && \
    tar xf flac-${FLAC_VERSION}.tar.xz && \
    cd flac-${FLAC_VERSION} && \
    ./configure \
        --prefix=$PREFIX \
        --disable-shared \
        --enable-static \
        --disable-examples \
        --disable-cpplibs && \
    make -j"$(nproc)" && \
    make install && \
    cd .. && rm -rf flac-${FLAC_VERSION}*

# ============================================================================
# Build Speex (BSD - Speech codec)
# ============================================================================
RUN wget -q https://ftp.osuosl.org/pub/xiph/releases/speex/speex-${SPEEX_VERSION}.tar.gz && \
    echo "${SPEEX_SHA256}  speex-${SPEEX_VERSION}.tar.gz" | sha256sum -c - && \
    tar xzf speex-${SPEEX_VERSION}.tar.gz && \
    cd speex-${SPEEX_VERSION} && \
    ./configure \
        --prefix=$PREFIX \
        --disable-shared \
        --enable-static && \
    make -j"$(nproc)" && \
    make install && \
    cd .. && rm -rf speex-${SPEEX_VERSION}*

# ============================================================================
# Build libfreetype (FreeType License - Font rendering)
# ============================================================================
RUN wget -q https://download.savannah.gnu.org/releases/freetype/freetype-${FREETYPE_VERSION}.tar.xz && \
    echo "${FREETYPE_SHA256}  freetype-${FREETYPE_VERSION}.tar.xz" | sha256sum -c - && \
    tar xf freetype-${FREETYPE_VERSION}.tar.xz && \
    cd freetype-${FREETYPE_VERSION} && \
    ./configure \
        --prefix=$PREFIX \
        --disable-shared \
        --enable-static \
        --without-harfbuzz \
        --without-bzip2 \
        --without-png && \
    make -j"$(nproc)" && \
    make install && \
    cd .. && rm -rf freetype-${FREETYPE_VERSION}*

# ============================================================================
# Build libass (ISC - Subtitle rendering)
# ============================================================================
RUN wget -q https://github.com/libass/libass/releases/download/${LIBASS_VERSION}/libass-${LIBASS_VERSION}.tar.gz && \
    echo "${LIBASS_SHA256}  libass-${LIBASS_VERSION}.tar.gz" | sha256sum -c - && \
    tar xzf libass-${LIBASS_VERSION}.tar.gz && \
    cd libass-${LIBASS_VERSION} && \
    ./configure \
        --prefix=$PREFIX \
        --disable-shared \
        --enable-static \
        --disable-require-system-font-provider && \
    make -j"$(nproc)" && \
    make install && \
    cd .. && rm -rf libass-${LIBASS_VERSION}*

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
    echo "✓ Build artifacts cleaned"

# ============================================================================
# Strip debug symbols and verify static linking
# ============================================================================
RUN strip $PREFIX/bin/ffmpeg $PREFIX/bin/ffprobe && \
    echo "=== Verifying static binary ===" && \
    file $PREFIX/bin/ffmpeg && \
    # musl ldd says "Not a valid dynamic program" for static binaries
    # glibc ldd says "not a dynamic executable"
    if ldd $PREFIX/bin/ffmpeg 2>&1 | grep -qE "(not a dynamic executable|Not a valid dynamic program)"; then \
        echo "✓ Binary is fully static"; \
    else \
        echo "✗ Binary has dynamic dependencies:" && ldd $PREFIX/bin/ffmpeg && exit 1; \
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
