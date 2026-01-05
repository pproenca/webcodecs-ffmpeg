# FFmpeg Windows x64 Build (Cross-Compilation)
# Based on: https://trac.ffmpeg.org/wiki/CompilationGuide/CrossCompilingForWindows
# Platform: windows-x64
# Method: MinGW-w64 cross-compiler on Ubuntu 24.04

FROM ubuntu:24.04 AS builder

# hadolint ignore=DL4006
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ENV DEBIAN_FRONTEND=noninteractive

# Install MinGW-w64 toolchain and build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    autoconf \
    automake \
    binutils-mingw-w64-x86-64 \
    bzip2 \
    ca-certificates \
    ccache \
    cmake \
    curl \
    g++-mingw-w64-x86-64 \
    gcc-mingw-w64-x86-64 \
    git \
    gzip \
    libtool \
    make \
    mingw-w64 \
    mingw-w64-tools \
    nasm \
    patch \
    perl \
    pkg-config \
    tar \
    wget \
    xz-utils \
    yasm \
    && rm -rf /var/lib/apt/lists/*

# Versions - hardcoded for reproducibility
ENV FFMPEG_VERSION=n8.0.1
ENV FFMPEG_GIT_URL=https://git.ffmpeg.org/ffmpeg.git
ENV X264_VERSION=stable
ENV X265_VERSION=4.1
ENV LIBVPX_VERSION=v1.15.2
ENV LIBAOM_VERSION=v3.13.1
ENV SVTAV1_VERSION=v3.1.2
ENV THEORA_VERSION=1.2.0
ENV THEORA_SHA256=279327339903b544c28a92aeada7d0dcfd0397b59c2f368cc698ac56f515906e
ENV XVID_VERSION=1.3.7
ENV XVID_SHA256=abbdcbd39555691dd1c9b4d08f0a031376a3b211652c0d8b3b8aa9be1303ce2d
ENV OPUS_VERSION=1.6
ENV OPUS_SHA256=b7637334527201fdfd6dd6a02e67aceffb0e5e60155bbd89175647a80301c92c
ENV LAME_VERSION=3.100
ENV LAME_SHA256=ddfe36cab873794038ae2c1210557ad34857a4b6bdc515785d1da9e175b1da1e
ENV OGG_VERSION=1.3.6
ENV VORBIS_VERSION=1.3.7
ENV FDKAAC_VERSION=v2.0.3
ENV FLAC_VERSION=1.5.0
ENV FLAC_SHA256=f2c1c76592a82ffff8413ba3c4a1299b6c7ab06c734dee03fd88630485c2b920
ENV SPEEX_VERSION=1.2.1
ENV SPEEX_SHA256=4b44d4f2b38a370a2d98a78329fefc56a0cf93d1c1be70029217baae6628feea
ENV FREETYPE_VERSION=2.14.1
ENV FREETYPE_SHA256=32427e8c471ac095853212a37aef816c60b42052d4d9e48230bab3bdf2936ccc
ENV LIBASS_VERSION=0.17.4
ENV LIBASS_SHA256=a886b3b80867f437bc55cff3280a652bfa0d37b43d2aff39ddf3c4f288b8c5a8
ENV NASM_VERSION=2.16.03
ENV NASM_URL=https://github.com/netwide-assembler/nasm/archive/refs/tags/nasm-2.16.03.tar.gz
ENV NASM_SHA256=b7f75b9a0e7d7f58f42a99c0e0ab4ef46656c497b25be29ae84332d86c4eec7f

# Environment setup
ENV CROSS_PREFIX=x86_64-w64-mingw32-
ENV TARGET=/opt/ffmpeg
ENV SOURCES=/usr/src/ffmpeg_sources
ENV PATH="/usr/lib/ccache:${TARGET}/bin:${PATH}"
ENV PKG_CONFIG_PATH="${TARGET}/lib/pkgconfig"
ENV CCACHE_DIR=/cache

RUN mkdir -p ${TARGET} ${SOURCES}
WORKDIR ${SOURCES}

COPY patches/x265-cmake4-compat.patch /tmp/x265-cmake4-compat.patch

# Install NASM (assembler for x264/x265)
RUN cd ${SOURCES} && \
    wget -q -O nasm-${NASM_VERSION}.tar.gz "${NASM_URL}" && \
    echo "${NASM_SHA256}  nasm-${NASM_VERSION}.tar.gz" | sha256sum -c - && \
    tar xzf nasm-${NASM_VERSION}.tar.gz && \
    cd nasm-nasm-${NASM_VERSION} && \
    ./autogen.sh && \
    ./configure --prefix="${TARGET}" && \
    make -j"$(nproc)" && \
    mkdir -p "${TARGET}/bin" && \
    install -c nasm ndisasm "${TARGET}/bin/" && \
    cd ${SOURCES} && rm -rf nasm-*

# Build x264 (H.264 encoder)
RUN cd ${SOURCES} && \
    git clone --depth 1 --branch ${X264_VERSION} https://code.videolan.org/videolan/x264.git && \
    cd x264 && \
    ./configure \
        --host=x86_64-w64-mingw32 \
        --cross-prefix=${CROSS_PREFIX} \
        --prefix=${TARGET} \
        --enable-static \
        --disable-shared \
        --disable-cli && \
    make -j"$(nproc)" && \
    make install && \
    cd ${SOURCES} && rm -rf x264

# Build x265 (H.265/HEVC encoder)
RUN cd ${SOURCES} && \
    git clone --depth 1 --branch ${X265_VERSION} https://bitbucket.org/multicoreware/x265_git.git && \
    cd x265_git && \
    patch -p1 < /tmp/x265-cmake4-compat.patch && \
    cd build/linux && \
    cmake -G "Unix Makefiles" \
        -DCMAKE_SYSTEM_NAME=Windows \
        -DCMAKE_C_COMPILER=${CROSS_PREFIX}gcc \
        -DCMAKE_CXX_COMPILER=${CROSS_PREFIX}g++ \
        -DCMAKE_RC_COMPILER=${CROSS_PREFIX}windres \
        -DCMAKE_RANLIB=${CROSS_PREFIX}ranlib \
        -DCMAKE_INSTALL_PREFIX=${TARGET} \
        -DENABLE_SHARED=OFF \
        -DENABLE_CLI=OFF \
        ../../source && \
    make -j"$(nproc)" && \
    make install && \
    cd ${SOURCES} && rm -rf x265_git

# Build libvpx (VP8/VP9 codec)
RUN cd ${SOURCES} && \
    git clone --depth 1 --branch ${LIBVPX_VERSION} https://chromium.googlesource.com/webm/libvpx.git && \
    cd libvpx && \
    ./configure \
        --target=x86_64-win64-gcc \
        --prefix=${TARGET} \
        --enable-static \
        --disable-shared \
        --disable-examples \
        --disable-tools \
        --disable-docs \
        --disable-unit-tests \
        --enable-vp9-highbitdepth && \
    make -j"$(nproc)" && \
    make install && \
    cd ${SOURCES} && rm -rf libvpx

# Build libaom (AV1 codec)
RUN cd ${SOURCES} && \
    git clone --depth 1 --branch ${LIBAOM_VERSION} https://aomedia.googlesource.com/aom && \
    cd aom && \
    mkdir build && cd build && \
    cmake .. \
        -DCMAKE_SYSTEM_NAME=Windows \
        -DCMAKE_C_COMPILER=${CROSS_PREFIX}gcc \
        -DCMAKE_CXX_COMPILER=${CROSS_PREFIX}g++ \
        -DCMAKE_AR=${CROSS_PREFIX}ar \
        -DCMAKE_RANLIB=${CROSS_PREFIX}ranlib \
        -DCMAKE_INSTALL_PREFIX=${TARGET} \
        -DBUILD_SHARED_LIBS=OFF \
        -DENABLE_TESTS=OFF \
        -DENABLE_EXAMPLES=OFF \
        -DENABLE_DOCS=OFF && \
    make -j"$(nproc)" && \
    make install && \
    cd ${SOURCES} && rm -rf aom

# Build libogg (Ogg container - required for vorbis/opus)
RUN cd ${SOURCES} && \
    git clone --depth 1 --branch v${OGG_VERSION} https://github.com/xiph/ogg.git && \
    cd ogg && \
    ./autogen.sh && \
    ./configure \
        --host=x86_64-w64-mingw32 \
        --prefix=${TARGET} \
        --enable-static \
        --disable-shared && \
    make -j"$(nproc)" && \
    make install && \
    cd ${SOURCES} && rm -rf ogg

# Build libvorbis (Vorbis audio codec)
RUN cd ${SOURCES} && \
    git clone --depth 1 --branch v${VORBIS_VERSION} https://github.com/xiph/vorbis.git && \
    cd vorbis && \
    ./autogen.sh && \
    ./configure \
        --host=x86_64-w64-mingw32 \
        --prefix=${TARGET} \
        --enable-static \
        --disable-shared && \
    make -j"$(nproc)" && \
    make install && \
    cd ${SOURCES} && rm -rf vorbis

# Build Opus (Opus audio codec)
RUN cd ${SOURCES} && \
    wget -q https://downloads.xiph.org/releases/opus/opus-${OPUS_VERSION}.tar.gz && \
    echo "${OPUS_SHA256}  opus-${OPUS_VERSION}.tar.gz" | sha256sum -c - && \
    tar xzf opus-${OPUS_VERSION}.tar.gz && \
    cd opus-${OPUS_VERSION} && \
    ./configure \
        --host=x86_64-w64-mingw32 \
        --prefix=${TARGET} \
        --enable-static \
        --disable-shared && \
    make -j"$(nproc)" && \
    make install && \
    cd ${SOURCES} && rm -rf opus-${OPUS_VERSION}*

# Build LAME (MP3 encoder)
RUN cd ${SOURCES} && \
    wget -q https://downloads.sourceforge.net/project/lame/lame/${LAME_VERSION}/lame-${LAME_VERSION}.tar.gz && \
    echo "${LAME_SHA256}  lame-${LAME_VERSION}.tar.gz" | sha256sum -c - && \
    tar xzf lame-${LAME_VERSION}.tar.gz && \
    cd lame-${LAME_VERSION} && \
    ./configure \
        --host=x86_64-w64-mingw32 \
        --prefix=${TARGET} \
        --enable-static \
        --disable-shared \
        --enable-nasm && \
    make -j"$(nproc)" && \
    make install && \
    cd ${SOURCES} && rm -rf lame-${LAME_VERSION}*

# Build SVT-AV1 (Intel's AV1 encoder)
RUN cd ${SOURCES} && \
    git clone --depth 1 --branch ${SVTAV1_VERSION} https://gitlab.com/AOMediaCodec/SVT-AV1.git && \
    mkdir -p SVT-AV1/build && \
    cd SVT-AV1/build && \
    cmake -G "Unix Makefiles" \
        -DCMAKE_SYSTEM_NAME=Windows \
        -DCMAKE_C_COMPILER=${CROSS_PREFIX}gcc \
        -DCMAKE_CXX_COMPILER=${CROSS_PREFIX}g++ \
        -DCMAKE_RC_COMPILER=${CROSS_PREFIX}windres \
        -DCMAKE_INSTALL_PREFIX=${TARGET} \
        -DBUILD_SHARED_LIBS=OFF \
        -DBUILD_APPS=OFF \
        -DBUILD_DEC=OFF \
        -DBUILD_TESTING=OFF \
        .. && \
    make -j"$(nproc)" && \
    make install && \
    cd ${SOURCES} && rm -rf SVT-AV1

# Build Theora (Ogg video codec)
RUN cd ${SOURCES} && \
    wget -q https://ftp.osuosl.org/pub/xiph/releases/theora/libtheora-${THEORA_VERSION}.tar.gz && \
    echo "${THEORA_SHA256}  libtheora-${THEORA_VERSION}.tar.gz" | sha256sum -c - && \
    tar xzf libtheora-${THEORA_VERSION}.tar.gz && \
    cd libtheora-${THEORA_VERSION} && \
    ./configure \
        --host=x86_64-w64-mingw32 \
        --prefix=${TARGET} \
        --enable-static \
        --disable-shared \
        --disable-examples && \
    make -j"$(nproc)" && \
    make install && \
    cd ${SOURCES} && rm -rf libtheora-${THEORA_VERSION}*

# Build Xvid (MPEG-4 ASP codec)
RUN cd ${SOURCES} && \
    wget -q https://downloads.xvid.com/downloads/xvidcore-${XVID_VERSION}.tar.gz && \
    echo "${XVID_SHA256}  xvidcore-${XVID_VERSION}.tar.gz" | sha256sum -c - && \
    tar xzf xvidcore-${XVID_VERSION}.tar.gz && \
    cd xvidcore/build/generic && \
    ./configure \
        --host=x86_64-w64-mingw32 \
        --prefix=${TARGET} && \
    make -j"$(nproc)" && \
    make install && \
    cd ${SOURCES} && rm -rf xvidcore*

# Build fdk-aac (High-quality AAC encoder - Non-free)
RUN cd ${SOURCES} && \
    git clone --depth 1 --branch ${FDKAAC_VERSION} https://github.com/mstorsjo/fdk-aac.git && \
    cd fdk-aac && \
    ./autogen.sh && \
    ./configure \
        --host=x86_64-w64-mingw32 \
        --prefix=${TARGET} \
        --enable-static \
        --disable-shared && \
    make -j"$(nproc)" && \
    make install && \
    cd ${SOURCES} && rm -rf fdk-aac

# Build FLAC (Free Lossless Audio Codec)
RUN cd ${SOURCES} && \
    wget -q https://ftp.osuosl.org/pub/xiph/releases/flac/flac-${FLAC_VERSION}.tar.xz && \
    echo "${FLAC_SHA256}  flac-${FLAC_VERSION}.tar.xz" | sha256sum -c - && \
    tar xf flac-${FLAC_VERSION}.tar.xz && \
    cd flac-${FLAC_VERSION} && \
    ./configure \
        --host=x86_64-w64-mingw32 \
        --prefix=${TARGET} \
        --enable-static \
        --disable-shared \
        --disable-examples \
        --disable-cpplibs && \
    make -j"$(nproc)" && \
    make install && \
    cd ${SOURCES} && rm -rf flac-${FLAC_VERSION}*

# Build Speex (Speech codec)
RUN cd ${SOURCES} && \
    wget -q https://ftp.osuosl.org/pub/xiph/releases/speex/speex-${SPEEX_VERSION}.tar.gz && \
    echo "${SPEEX_SHA256}  speex-${SPEEX_VERSION}.tar.gz" | sha256sum -c - && \
    tar xzf speex-${SPEEX_VERSION}.tar.gz && \
    cd speex-${SPEEX_VERSION} && \
    ./configure \
        --host=x86_64-w64-mingw32 \
        --prefix=${TARGET} \
        --enable-static \
        --disable-shared && \
    make -j"$(nproc)" && \
    make install && \
    cd ${SOURCES} && rm -rf speex-${SPEEX_VERSION}*

# Build libfreetype (Font rendering)
RUN cd ${SOURCES} && \
    wget -q https://download.savannah.gnu.org/releases/freetype/freetype-${FREETYPE_VERSION}.tar.xz && \
    echo "${FREETYPE_SHA256}  freetype-${FREETYPE_VERSION}.tar.xz" | sha256sum -c - && \
    tar xf freetype-${FREETYPE_VERSION}.tar.xz && \
    cd freetype-${FREETYPE_VERSION} && \
    ./configure \
        --host=x86_64-w64-mingw32 \
        --prefix=${TARGET} \
        --enable-static \
        --disable-shared \
        --without-harfbuzz \
        --without-bzip2 \
        --without-png && \
    make -j"$(nproc)" && \
    make install && \
    cd ${SOURCES} && rm -rf freetype-${FREETYPE_VERSION}*

# Build libass (Subtitle rendering)
RUN cd ${SOURCES} && \
    wget -q https://github.com/libass/libass/releases/download/${LIBASS_VERSION}/libass-${LIBASS_VERSION}.tar.gz && \
    echo "${LIBASS_SHA256}  libass-${LIBASS_VERSION}.tar.gz" | sha256sum -c - && \
    tar xzf libass-${LIBASS_VERSION}.tar.gz && \
    cd libass-${LIBASS_VERSION} && \
    ./configure \
        --host=x86_64-w64-mingw32 \
        --prefix=${TARGET} \
        --enable-static \
        --disable-shared \
        --disable-require-system-font-provider && \
    make -j"$(nproc)" && \
    make install && \
    cd ${SOURCES} && rm -rf libass-${LIBASS_VERSION}*

# Build FFmpeg - no network, no hardware acceleration
RUN cd ${SOURCES} && \
    git clone --depth 1 --branch ${FFMPEG_VERSION} ${FFMPEG_GIT_URL} && \
    cd ffmpeg && \
    ./configure \
        --arch=x86_64 \
        --target-os=mingw32 \
        --cross-prefix=${CROSS_PREFIX} \
        --prefix=${TARGET} \
        --pkg-config=pkg-config \
        --pkg-config-flags="--static" \
        --extra-cflags="-I${TARGET}/include" \
        --extra-ldflags="-L${TARGET}/lib -static" \
        --extra-libs="-lpthread -lm" \
        --enable-static \
        --disable-shared \
        --enable-gpl \
        --enable-version3 \
        --enable-nonfree \
        --enable-runtime-cpudetect \
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
        --enable-libvorbis \
        --enable-libmp3lame \
        --enable-libfdk-aac \
        --enable-libspeex \
        --enable-libfreetype \
        --enable-libass && \
    make -j"$(nproc)" && \
    make install && \
    ${CROSS_PREFIX}strip ${TARGET}/bin/*.exe && \
    cd ${SOURCES} && rm -rf ffmpeg

RUN rm -rf ${TARGET}/lib/pkgconfig ${TARGET}/lib/*.la ${TARGET}/lib/cmake

RUN file ${TARGET}/bin/ffmpeg.exe && \
    file ${TARGET}/bin/ffprobe.exe && \
    ls -lh ${TARGET}/bin/*.exe

FROM scratch AS export
COPY --from=builder /opt/ffmpeg/bin/ffmpeg.exe /ffmpeg.exe
COPY --from=builder /opt/ffmpeg/bin/ffprobe.exe /ffprobe.exe

FROM ubuntu:24.04 AS runtime
COPY --from=builder /opt/ffmpeg/bin /build/bin
COPY --from=builder /opt/ffmpeg/lib /build/lib
COPY --from=builder /opt/ffmpeg/include /build/include
WORKDIR /build
CMD ["bash"]
