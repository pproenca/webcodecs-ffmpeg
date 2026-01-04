# FFmpeg Windows x64 Build (Cross-Compilation)
# Based on: https://trac.ffmpeg.org/wiki/CompilationGuide/CrossCompilingForWindows
# Platform: windows-x64
# Method: MinGW-w64 cross-compiler on Ubuntu 24.04

FROM ubuntu:24.04

# Avoid interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

# Install MinGW-w64 toolchain and build dependencies
RUN apt-get update && apt-get install -y \
    # MinGW cross-compiler
    mingw-w64 \
    mingw-w64-tools \
    gcc-mingw-w64-x86-64 \
    g++-mingw-w64-x86-64 \
    binutils-mingw-w64-x86-64 \
    # Build tools
    nasm \
    yasm \
    pkg-config \
    make \
    cmake \
    git \
    wget \
    curl \
    tar \
    gzip \
    bzip2 \
    xz-utils \
    autoconf \
    automake \
    libtool \
    patch \
    perl \
    # Utilities
    ca-certificates \
    ccache \
    && rm -rf /var/lib/apt/lists/*

# Build arguments (versions passed from CI)
ARG FFMPEG_VERSION
ARG X264_VERSION
ARG X265_VERSION
ARG LIBVPX_VERSION
ARG LIBAOM_VERSION
ARG SVTAV1_VERSION
ARG RAV1E_VERSION
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
ARG LIBVORBIS_VERSION
ARG LIBOGG_VERSION
ARG NASM_VERSION
ARG NASM_URL
ARG NASM_SHA256

# Environment setup
ENV CROSS_PREFIX=x86_64-w64-mingw32-
ENV TARGET=/opt/ffmpeg
ENV SOURCES=/usr/src/ffmpeg_sources
ENV PATH="/usr/lib/ccache:${TARGET}/bin:${PATH}"
ENV PKG_CONFIG_PATH="${TARGET}/lib/pkgconfig"
ENV CCACHE_DIR=/cache

# Create directories
RUN mkdir -p ${TARGET} ${SOURCES}
WORKDIR ${SOURCES}

# Install NASM (assembler for x264/x265)
RUN cd ${SOURCES} && \
    wget -q -O nasm-${NASM_VERSION}.tar.gz "${NASM_URL}" && \
    echo "${NASM_SHA256}  nasm-${NASM_VERSION}.tar.gz" | sha256sum -c - && \
    tar xzf nasm-${NASM_VERSION}.tar.gz && \
    cd nasm-nasm-${NASM_VERSION} && \
    ./autogen.sh && \
    ./configure --prefix="${TARGET}" && \
    make -j$(nproc) && \
    make install && \
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
    make -j$(nproc) && \
    make install && \
    cd ${SOURCES} && rm -rf x264

# Build x265 (H.265/HEVC encoder)
RUN cd ${SOURCES} && \
    git clone --depth 1 --branch ${X265_VERSION} https://bitbucket.org/multicoreware/x265_git.git && \
    cd x265_git/build/linux && \
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
    make -j$(nproc) && \
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
    make -j$(nproc) && \
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
    make -j$(nproc) && \
    make install && \
    cd ${SOURCES} && rm -rf aom

# Build libogg (Ogg container - required for vorbis/opus)
RUN cd ${SOURCES} && \
    git clone --depth 1 --branch v${LIBOGG_VERSION} https://github.com/xiph/ogg.git && \
    cd ogg && \
    ./autogen.sh && \
    ./configure \
        --host=x86_64-w64-mingw32 \
        --prefix=${TARGET} \
        --enable-static \
        --disable-shared && \
    make -j$(nproc) && \
    make install && \
    cd ${SOURCES} && rm -rf ogg

# Build libvorbis (Vorbis audio codec)
RUN cd ${SOURCES} && \
    git clone --depth 1 --branch v${LIBVORBIS_VERSION} https://github.com/xiph/vorbis.git && \
    cd vorbis && \
    ./autogen.sh && \
    ./configure \
        --host=x86_64-w64-mingw32 \
        --prefix=${TARGET} \
        --enable-static \
        --disable-shared && \
    make -j$(nproc) && \
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
    make -j$(nproc) && \
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
    make -j$(nproc) && \
    make install && \
    cd ${SOURCES} && rm -rf lame-${LAME_VERSION}*

# Build SVT-AV1 (Intel's AV1 encoder)
RUN cd ${SOURCES} && \
    git clone --depth 1 --branch ${SVTAV1_VERSION} https://gitlab.com/AOMediaCodec/SVT-AV1.git && \
    mkdir SVT-AV1/build && \
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
    make -j$(nproc) && \
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
    make -j$(nproc) && \
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
    make -j$(nproc) && \
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
    make -j$(nproc) && \
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
    make -j$(nproc) && \
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
    make -j$(nproc) && \
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
    make -j$(nproc) && \
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
    make -j$(nproc) && \
    make install && \
    cd ${SOURCES} && rm -rf libass-${LIBASS_VERSION}*

# Build FFmpeg
RUN cd ${SOURCES} && \
    git clone --depth 1 --branch ${FFMPEG_VERSION} https://git.ffmpeg.org/ffmpeg.git && \
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
    make -j$(nproc) && \
    make install && \
    # Strip binaries to reduce size
    ${CROSS_PREFIX}strip ${TARGET}/bin/*.exe && \
    cd ${SOURCES} && rm -rf ffmpeg

# Clean up pkg-config files (contains hardcoded paths)
RUN rm -rf ${TARGET}/lib/pkgconfig ${TARGET}/lib/*.la ${TARGET}/lib/cmake

# Verify binaries
RUN file ${TARGET}/bin/ffmpeg.exe && \
    file ${TARGET}/bin/ffprobe.exe && \
    ls -lh ${TARGET}/bin/*.exe

# Final output directory
WORKDIR ${TARGET}
CMD ["bash"]
