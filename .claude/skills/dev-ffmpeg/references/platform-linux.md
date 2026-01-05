# Linux Platform Build Guide

## Table of Contents
- Ubuntu/Debian
- Alpine Linux
- RHEL/CentOS/Fedora
- Arch Linux

---

## Ubuntu/Debian

### Install Build Dependencies

```bash
# Build essentials
sudo apt update
sudo apt install -y \
  build-essential \
  pkg-config \
  git \
  nasm \
  yasm

# Common codec libraries (from repos)
sudo apt install -y \
  libx264-dev \
  libx265-dev \
  libvpx-dev \
  libopus-dev \
  libvorbis-dev \
  libogg-dev \
  libmp3lame-dev \
  libfdk-aac-dev \
  libass-dev \
  libfreetype6-dev \
  libsdl2-dev
```

### Build FFmpeg

```bash
git clone --depth 1 https://git.ffmpeg.org/ffmpeg.git
cd ffmpeg

./configure \
  --prefix=/usr/local \
  --enable-gpl \
  --enable-nonfree \
  --enable-shared \
  --enable-pic \
  --enable-libx264 \
  --enable-libx265 \
  --enable-libvpx \
  --enable-libopus \
  --enable-libvorbis \
  --enable-libmp3lame \
  --enable-libfdk-aac \
  --enable-libass \
  --enable-libfreetype \
  --disable-debug \
  --disable-doc

make -j$(nproc)
sudo make install
sudo ldconfig
```

### Verify

```bash
ffmpeg -version
ffmpeg -buildconf
```

---

## Alpine Linux

### Install Dependencies

```bash
apk add --no-cache \
  build-base \
  pkgconfig \
  git \
  nasm \
  yasm \
  x264-dev \
  x265-dev \
  libvpx-dev \
  opus-dev \
  libvorbis-dev \
  lame-dev \
  fdk-aac-dev
```

### Build FFmpeg

```bash
git clone --depth 1 https://git.ffmpeg.org/ffmpeg.git
cd ffmpeg

./configure \
  --prefix=/usr/local \
  --enable-gpl \
  --enable-nonfree \
  --enable-shared \
  --enable-pic \
  --enable-libx264 \
  --enable-libx265 \
  --enable-libvpx \
  --enable-libopus \
  --enable-libvorbis \
  --enable-libmp3lame \
  --enable-libfdk-aac \
  --disable-debug \
  --disable-doc

make -j$(nproc)
make install
```

---

## RHEL/CentOS/Fedora

### Enable Required Repos (RHEL/CentOS)

```bash
# Enable EPEL
sudo dnf install epel-release

# Enable RPM Fusion (for x264, x265, etc.)
sudo dnf install \
  https://download1.rpmfusion.org/free/el/rpmfusion-free-release-$(rpm -E %rhel).noarch.rpm \
  https://download1.rpmfusion.org/nonfree/el/rpmfusion-nonfree-release-$(rpm -E %rhel).noarch.rpm

# Enable PowerTools/CRB
sudo dnf config-manager --enable crb  # RHEL 9 / Rocky 9
# OR
sudo dnf config-manager --enable powertools  # RHEL 8
```

### Install Dependencies

```bash
sudo dnf install -y \
  gcc \
  gcc-c++ \
  make \
  pkgconfig \
  git \
  nasm \
  yasm \
  x264-devel \
  x265-devel \
  libvpx-devel \
  opus-devel \
  libvorbis-devel \
  lame-devel \
  fdk-aac-devel
```

### Build FFmpeg

Same configure/make as Ubuntu.

---

## Arch Linux

### Install Dependencies

```bash
sudo pacman -S --needed \
  base-devel \
  git \
  nasm \
  yasm \
  x264 \
  x265 \
  libvpx \
  opus \
  libvorbis \
  lame \
  fdk-aac
```

Arch includes dev files in main packages, no separate -dev.

---

## Building Codec Libraries from Source

When distro packages are outdated, build from source:

### x264

```bash
git clone --depth 1 https://code.videolan.org/videolan/x264.git
cd x264
./configure --prefix=/usr/local --enable-shared --enable-pic
make -j$(nproc)
sudo make install
```

### x265

```bash
git clone --depth 1 https://bitbucket.org/multicoreware/x265_git.git
cd x265_git/build/linux
cmake -G "Unix Makefiles" \
  -DCMAKE_INSTALL_PREFIX=/usr/local \
  -DENABLE_SHARED=ON \
  -DENABLE_PIC=ON \
  ../../source
make -j$(nproc)
sudo make install
```

### libvpx

```bash
git clone --depth 1 https://chromium.googlesource.com/webm/libvpx.git
cd libvpx
./configure --prefix=/usr/local --enable-shared --enable-pic --disable-examples --disable-unit-tests
make -j$(nproc)
sudo make install
```

### AV1 (libaom)

```bash
git clone --depth 1 https://aomedia.googlesource.com/aom
mkdir aom_build && cd aom_build
cmake ../aom \
  -DCMAKE_INSTALL_PREFIX=/usr/local \
  -DBUILD_SHARED_LIBS=ON \
  -DENABLE_TESTS=OFF \
  -DENABLE_DOCS=OFF
make -j$(nproc)
sudo make install
```

### SVT-AV1 (faster AV1 encoder)

```bash
git clone --depth 1 https://gitlab.com/AOMediaCodec/SVT-AV1.git
cd SVT-AV1/Build
cmake .. -DCMAKE_INSTALL_PREFIX=/usr/local -DBUILD_SHARED_LIBS=ON
make -j$(nproc)
sudo make install
```

---

## Post-Build: Update Library Cache

```bash
sudo ldconfig

# Verify libs are found
ldconfig -p | grep libav
```

## Static Builds (Single Binary)

For a fully static binary with no runtime dependencies:

```bash
./configure \
  --prefix=/usr/local \
  --enable-gpl \
  --enable-static \
  --disable-shared \
  --pkg-config-flags="--static" \
  --extra-cflags="-static" \
  --extra-ldflags="-static" \
  --enable-libx264 \
  --enable-libx265 \
  ...
```

Note: Requires static versions of all dependencies (`.a` files).
