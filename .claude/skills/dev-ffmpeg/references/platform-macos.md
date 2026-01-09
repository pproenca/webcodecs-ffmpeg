# macOS Platform Build Guide

## Table of Contents
- Prerequisites
- Homebrew-Based Build
- MacPorts-Based Build
- Building from Source
- Apple Silicon (M1/M2/M3)
- Universal Binaries

---

## Prerequisites

### Xcode Command Line Tools

```bash
xcode-select --install
```

### Package Manager

Choose one:
- **Homebrew** (recommended): https://brew.sh
- **MacPorts**: https://www.macports.org

---

## Homebrew-Based Build (Recommended)

### Install Dependencies

```bash
# Build tools
brew install nasm pkg-config

# Codec libraries
brew install x264 x265 libvpx opus libvorbis lame fdk-aac

# Optional: Additional codecs
brew install aom svt-av1 dav1d
brew install libass freetype fontconfig
brew install sdl2  # For ffplay
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
  --enable-pthreads \
  --enable-libx264 \
  --enable-libx265 \
  --enable-libvpx \
  --enable-libopus \
  --enable-libvorbis \
  --enable-libmp3lame \
  --enable-libfdk-aac \
  --enable-videotoolbox \
  --disable-debug \
  --disable-doc

make -j$(sysctl -n hw.ncpu)
sudo make install
```

### Or Just Install FFmpeg via Homebrew

```bash
# Pre-built, standard options
brew install ffmpeg

# With all options
brew install ffmpeg --with-fdk-aac --with-sdl2 --with-libass
```

---

## MacPorts-Based Build

### Install Dependencies

```bash
sudo port install nasm pkgconfig

sudo port install x264 x265 libvpx opus libvorbis lame

# Variant with fdk-aac (nonfree)
sudo port install ffmpeg +nonfree
```

### Build FFmpeg

```bash
export PKG_CONFIG_PATH=/opt/local/lib/pkgconfig

./configure \
  --prefix=/opt/local \
  --enable-gpl \
  --enable-libx264 \
  --enable-libx265 \
  --enable-libvpx \
  --enable-libopus \
  --extra-cflags="-I/opt/local/include" \
  --extra-ldflags="-L/opt/local/lib"

make -j$(sysctl -n hw.ncpu)
sudo make install
```

---

## Building from Source (No Package Manager)

### Build x264

```bash
git clone --depth 1 https://code.videolan.org/videolan/x264.git
cd x264

./configure \
  --prefix=/usr/local \
  --enable-shared \
  --enable-pic

make -j$(sysctl -n hw.ncpu)
sudo make install
```

### Build x265

```bash
git clone --depth 1 https://bitbucket.org/multicoreware/x265_git.git
cd x265_git/build/linux  # Yes, "linux" works on macOS

cmake -G "Unix Makefiles" \
  -DCMAKE_INSTALL_PREFIX=/usr/local \
  -DENABLE_SHARED=ON \
  ../../source

make -j$(sysctl -n hw.ncpu)
sudo make install
```

### Build libvpx

```bash
git clone --depth 1 https://chromium.googlesource.com/webm/libvpx.git
cd libvpx

./configure \
  --prefix=/usr/local \
  --enable-shared \
  --enable-pic \
  --disable-examples \
  --disable-unit-tests

make -j$(sysctl -n hw.ncpu)
sudo make install
```

---

## Apple Silicon (M1/M2/M3)

### Native ARM64 Build

```bash
# Ensure building for arm64
./configure \
  --arch=arm64 \
  --enable-neon \
  --enable-videotoolbox \
  ...
```

### Rosetta 2 (x86_64 on ARM)

```bash
# Force x86_64 build
arch -x86_64 ./configure --arch=x86_64 ...
arch -x86_64 make -j$(sysctl -n hw.ncpu)
```

### Check Architecture

```bash
# Verify binary architecture
file $(which ffmpeg)
# Should show: Mach-O 64-bit executable arm64

# Or for universal
file ffmpeg
# Mach-O universal binary with 2 architectures: [x86_64:...] [arm64:...]
```

---

## Universal Binaries (x86_64 + arm64)

Build twice and combine with `lipo`:

### Build for arm64

```bash
mkdir build-arm64
cd ffmpeg
./configure \
  --prefix=$(pwd)/../build-arm64 \
  --arch=arm64 \
  --enable-shared \
  ...
make -j$(sysctl -n hw.ncpu)
make install
cd ..
```

### Build for x86_64

```bash
mkdir build-x86_64
cd ffmpeg
make clean
./configure \
  --prefix=$(pwd)/../build-x86_64 \
  --arch=x86_64 \
  --enable-shared \
  ...
make -j$(sysctl -n hw.ncpu)
make install
cd ..
```

### Combine with lipo

```bash
mkdir -p universal/bin universal/lib

# Combine binaries
lipo -create \
  build-arm64/bin/ffmpeg \
  build-x86_64/bin/ffmpeg \
  -output universal/bin/ffmpeg

lipo -create \
  build-arm64/bin/ffprobe \
  build-x86_64/bin/ffprobe \
  -output universal/bin/ffprobe

# Combine libraries
for lib in build-arm64/lib/*.dylib; do
  name=$(basename $lib)
  lipo -create \
    build-arm64/lib/$name \
    build-x86_64/lib/$name \
    -output universal/lib/$name
done
```

---

## VideoToolbox Hardware Acceleration

macOS provides hardware-accelerated encoding/decoding via VideoToolbox:

```bash
./configure \
  --enable-videotoolbox \
  --enable-hwaccel=h264_videotoolbox \
  --enable-hwaccel=hevc_videotoolbox
```

Usage:
```bash
# Encode with VideoToolbox
ffmpeg -i input.mp4 -c:v h264_videotoolbox -b:v 5M output.mp4

# HEVC encoding
ffmpeg -i input.mp4 -c:v hevc_videotoolbox -b:v 3M output.mp4

# Decode with hardware
ffmpeg -hwaccel videotoolbox -i input.mp4 -c:v libx264 output.mp4
```

---

## Common macOS Issues

### "library not found for -lSystem"

```bash
# Ensure Xcode CLI tools installed
xcode-select --install

# Set SDK path explicitly
export SDKROOT=$(xcrun --show-sdk-path)
./configure --sysroot=$(xcrun --show-sdk-path) ...
```

### pkg-config not finding libraries

```bash
# Homebrew
export PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:/opt/homebrew/lib/pkgconfig"

# MacPorts
export PKG_CONFIG_PATH="/opt/local/lib/pkgconfig"
```

### "dyld: Library not loaded"

```bash
# Update library paths
export DYLD_LIBRARY_PATH=/usr/local/lib:$DYLD_LIBRARY_PATH

# Or use install_name_tool to fix rpath
install_name_tool -add_rpath /usr/local/lib ffmpeg
```

### Homebrew on Apple Silicon path

Homebrew installs to `/opt/homebrew` on Apple Silicon:

```bash
# Add to PATH
export PATH="/opt/homebrew/bin:$PATH"
export PKG_CONFIG_PATH="/opt/homebrew/lib/pkgconfig"
export CFLAGS="-I/opt/homebrew/include"
export LDFLAGS="-L/opt/homebrew/lib"
```

---

## Verification

```bash
# Check version and config
ffmpeg -version
ffmpeg -buildconf

# Check for VideoToolbox
ffmpeg -encoders | grep videotoolbox
ffmpeg -decoders | grep videotoolbox

# Test encode
ffmpeg -f lavfi -i testsrc=duration=1:size=1280x720 -c:v libx264 test.mp4

# Test VideoToolbox
ffmpeg -f lavfi -i testsrc=duration=1:size=1280x720 -c:v h264_videotoolbox test-vt.mp4
```
