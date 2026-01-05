# FFmpeg Build for Linux ARMv7 (glibc)
# Ubuntu 24.04 for Raspberry Pi 2/3

FROM --platform=linux/arm/v7 ubuntu:24.04 AS builder

SHELL ["/bin/bash", "-o", "pipefail", "-c"]
ENV DEBIAN_FRONTEND=noninteractive

# Note: NASM/YASM omitted - x86 assemblers not used on ARM
RUN apt-get update && apt-get install -y --no-install-recommends \
    autoconf automake bash build-essential ca-certificates ccache cmake \
    coreutils curl diffutils git libtool linux-libc-dev meson \
    ninja-build perl pkg-config wget zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

ENV PREFIX=/build
ENV PKG_CONFIG_PATH=$PREFIX/lib/pkgconfig
ENV PATH=/usr/lib/ccache:$PREFIX/bin:$PATH
ENV CCACHE_DIR=/cache
ENV MAKEFLAGS="-j$(nproc)"
ENV CFLAGS="-fPIC -march=armv7-a -mfpu=neon -mfloat-abi=hard"
ENV CXXFLAGS="-fPIC -march=armv7-a -mfpu=neon -mfloat-abi=hard"

WORKDIR /src

COPY codecs /codecs
COPY patches /patches

# Versions
ENV FFMPEG_VERSION=n8.0.1
ENV FFMPEG_GIT_URL=https://git.ffmpeg.org/ffmpeg.git
ENV X264_VERSION=stable
ENV X265_VERSION=4.1
ENV LIBVPX_VERSION=v1.15.2
ENV LIBAOM_VERSION=v3.13.1
ENV SVTAV1_VERSION=v3.1.2
ENV DAV1D_VERSION=1.5.3
ENV DAV1D_URL=https://downloads.videolan.org/pub/videolan/dav1d/1.5.3/dav1d-1.5.3.tar.xz
ENV DAV1D_SHA256=732010aa5ef461fa93355ed2c6c5fedb48ddc4b74e697eaabe8907eaeb943011
ENV THEORA_VERSION=1.2.0
ENV THEORA_URL=https://ftp.osuosl.org/pub/xiph/releases/theora/libtheora-1.2.0.tar.gz
ENV THEORA_SHA256=279327339903b544c28a92aeada7d0dcfd0397b59c2f368cc698ac56f515906e
ENV XVID_VERSION=1.3.7
ENV XVID_URL=https://downloads.xvid.com/downloads/xvidcore-1.3.7.tar.gz
ENV XVID_SHA256=abbdcbd39555691dd1c9b4d08f0a031376a3b211652c0d8b3b8aa9be1303ce2d
ENV OPUS_VERSION=1.6
ENV OPUS_URL=https://downloads.xiph.org/releases/opus/opus-1.6.tar.gz
ENV OPUS_SHA256=b7637334527201fdfd6dd6a02e67aceffb0e5e60155bbd89175647a80301c92c
ENV LAME_VERSION=3.100
ENV LAME_URL=https://downloads.sourceforge.net/project/lame/lame/3.100/lame-3.100.tar.gz
ENV LAME_SHA256=ddfe36cab873794038ae2c1210557ad34857a4b6bdc515785d1da9e175b1da1e
ENV VORBIS_VERSION=1.3.7
ENV VORBIS_URL=https://ftp.osuosl.org/pub/xiph/releases/vorbis/libvorbis-1.3.7.tar.gz
ENV VORBIS_SHA256=b33cc4934322bcbf6efcbacf49e3ca01aadbea4114ec9589d1b1e9d20f72954b
ENV OGG_VERSION=1.3.6
ENV OGG_URL=https://ftp.osuosl.org/pub/xiph/releases/ogg/libogg-1.3.6.tar.gz
ENV OGG_SHA256=83e6704730683d004d20e21b8f7f55dcb3383cdf84c0daedf30bde175f774638
ENV FDKAAC_VERSION=v2.0.3
ENV FLAC_VERSION=1.5.0
ENV FLAC_URL=https://ftp.osuosl.org/pub/xiph/releases/flac/flac-1.5.0.tar.xz
ENV FLAC_SHA256=f2c1c76592a82ffff8413ba3c4a1299b6c7ab06c734dee03fd88630485c2b920
ENV SPEEX_VERSION=1.2.1
ENV SPEEX_URL=https://ftp.osuosl.org/pub/xiph/releases/speex/speex-1.2.1.tar.gz
ENV SPEEX_SHA256=4b44d4f2b38a370a2d98a78329fefc56a0cf93d1c1be70029217baae6628feea
ENV LIBASS_VERSION=0.17.4
ENV LIBASS_URL=https://github.com/libass/libass/releases/download/0.17.4/libass-0.17.4.tar.gz
ENV LIBASS_SHA256=a886b3b80867f437bc55cff3280a652bfa0d37b43d2aff39ddf3c4f288b8c5a8
ENV FREETYPE_VERSION=2.14.1
ENV FREETYPE_URL=https://download.savannah.gnu.org/releases/freetype/freetype-2.14.1.tar.xz
ENV FREETYPE_SHA256=32427e8c471ac095853212a37aef816c60b42052d4d9e48230bab3bdf2936ccc
ENV OPENSSL_VERSION=3.6.0
ENV OPENSSL_URL=https://www.openssl.org/source/openssl-3.6.0.tar.gz
ENV OPENSSL_SHA256=b6a5f44b7eb69e3fa35dbf15524405b44837a481d43d81daddde3ff21fcbb8e9
ENV PATCH_DIR=/patches

# Video codecs
RUN /codecs/x264.sh
RUN /codecs/x265.sh
RUN /codecs/libvpx.sh
RUN /codecs/libaom.sh
RUN /codecs/dav1d.sh
RUN /codecs/svt-av1.sh
RUN /codecs/xvid.sh

# Audio codecs
RUN /codecs/ogg.sh
RUN /codecs/vorbis.sh
RUN /codecs/theora.sh
RUN /codecs/opus.sh
RUN /codecs/lame.sh
RUN /codecs/fdk-aac.sh
RUN /codecs/flac.sh
RUN /codecs/speex.sh

# Support libraries
RUN /codecs/freetype.sh
RUN /codecs/libass.sh
RUN OPENSSL_TARGET=linux-armv4 /codecs/openssl.sh

# FFmpeg
RUN git clone --depth 1 --branch ${FFMPEG_VERSION} ${FFMPEG_GIT_URL} && \
    cd ffmpeg && \
    ./configure \
        --prefix=$PREFIX \
        --pkg-config-flags="--static" \
        --extra-cflags="-I$PREFIX/include -fPIC" \
        --extra-ldflags="-L$PREFIX/lib" \
        --extra-libs="-lpthread -lm -lstdc++" \
        --enable-gpl --enable-version3 --enable-nonfree \
        --enable-static --disable-shared --enable-pic \
        --disable-ffplay --disable-doc --disable-debug \
        --enable-openssl --enable-protocol=file,http,https,tcp,tls \
        --enable-libx264 --enable-libx265 --enable-libvpx \
        --enable-libaom --enable-libdav1d --enable-libsvtav1 \
        --enable-libtheora --enable-libxvid --enable-libopus \
        --enable-libmp3lame --enable-libfdk-aac --enable-libspeex \
        --enable-libvorbis --enable-libfreetype --enable-libass && \
    make -j"$(nproc)" && make install

RUN rm -rf $PREFIX/lib/pkgconfig && find $PREFIX/lib -name "*.la" -delete && rm -rf $PREFIX/lib/cmake
RUN strip $PREFIX/bin/ffmpeg $PREFIX/bin/ffprobe && $PREFIX/bin/ffmpeg -version

FROM --platform=linux/arm/v7 ubuntu:24.04 AS runtime
COPY --from=builder /build/bin/ffmpeg /build/bin/ffmpeg
COPY --from=builder /build/bin/ffprobe /build/bin/ffprobe
COPY --from=builder /build/lib /build/lib
COPY --from=builder /build/include /build/include
RUN /build/bin/ffmpeg -version
CMD ["/build/bin/ffmpeg", "-version"]
