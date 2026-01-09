# Cross-Compilation Guide

## Table of Contents
- Overview and Toolchains
- Linux → Windows (MinGW-w64)
- x86_64 → ARM64 (Linux)
- macOS Cross-Compilation
- Docker-Based Cross-Compilation

---

## Overview

Cross-compilation requires:
1. **Cross-compiler toolchain** - Compiles for target, runs on host
2. **Target libraries** - Compiled for target architecture
3. **FFmpeg configure flags** - `--enable-cross-compile`, `--arch`, `--target-os`, `--cross-prefix`

Key configure options:
```
--enable-cross-compile   Enable cross-compilation
--arch=ARCH              Target architecture (x86_64, aarch64, arm)
--target-os=OS           Target OS (linux, mingw32, darwin)
--cross-prefix=PREFIX    Prefix for toolchain binaries (e.g., x86_64-w64-mingw32-)
--sysroot=PATH           Target system root (for headers/libs)
```

---

## Linux → Windows (MinGW-w64)

### Install Toolchain (Ubuntu/Debian)

```bash
sudo apt install mingw-w64
```

This provides `x86_64-w64-mingw32-gcc` and `i686-w64-mingw32-gcc`.

### Build Dependencies for Windows

Each dependency must be cross-compiled. Example for x264:

```bash
git clone --depth 1 https://code.videolan.org/videolan/x264.git
cd x264
./configure \
  --prefix=/opt/ffmpeg-win64 \
  --host=x86_64-w64-mingw32 \
  --cross-prefix=x86_64-w64-mingw32- \
  --enable-static \
  --disable-cli

make -j$(nproc)
make install
```

### Build FFmpeg for Windows

```bash
git clone --depth 1 https://git.ffmpeg.org/ffmpeg.git
cd ffmpeg

./configure \
  --prefix=/opt/ffmpeg-win64 \
  --arch=x86_64 \
  --target-os=mingw32 \
  --cross-prefix=x86_64-w64-mingw32- \
  --pkg-config=pkg-config \
  --pkg-config-flags="--static" \
  --enable-cross-compile \
  --enable-gpl \
  --enable-libx264 \
  --enable-static \
  --disable-shared \
  --extra-cflags="-I/opt/ffmpeg-win64/include" \
  --extra-ldflags="-L/opt/ffmpeg-win64/lib"

make -j$(nproc)
```

Result: `ffmpeg.exe`, `ffprobe.exe` in working directory.

### 32-bit Windows Build

Replace `x86_64-w64-mingw32-` with `i686-w64-mingw32-` and `--arch=x86_64` with `--arch=x86`.

---

## Windows ARM64

Use LLVM MinGW toolchain (more mature for ARM64):

```bash
# Get LLVM MinGW
wget https://github.com/mstorsjo/llvm-mingw/releases/download/20240619/llvm-mingw-20240619-ucrt-ubuntu-20.04-x86_64.tar.xz
tar xf llvm-mingw-*.tar.xz
export PATH=$PWD/llvm-mingw-20240619-ucrt-ubuntu-20.04-x86_64/bin:$PATH

# Configure FFmpeg
./configure \
  --arch=arm64 \
  --target-os=mingw32 \
  --cross-prefix=aarch64-w64-mingw32- \
  --enable-cross-compile \
  ...
```

---

## x86_64 → ARM64 Linux

### Install Toolchain

```bash
# Ubuntu/Debian
sudo apt install gcc-aarch64-linux-gnu g++-aarch64-linux-gnu

# Provides aarch64-linux-gnu-gcc, etc.
```

### Build FFmpeg

```bash
./configure \
  --prefix=/opt/ffmpeg-arm64 \
  --arch=aarch64 \
  --target-os=linux \
  --cross-prefix=aarch64-linux-gnu- \
  --enable-cross-compile \
  --enable-gpl \
  --enable-shared \
  --enable-pic \
  --extra-cflags="-I/opt/ffmpeg-arm64/include" \
  --extra-ldflags="-L/opt/ffmpeg-arm64/lib"

make -j$(nproc)
```

### Cross-compile Dependencies

Each dependency needs cross-compilation. For cmake-based projects:

```bash
cmake .. \
  -DCMAKE_SYSTEM_NAME=Linux \
  -DCMAKE_SYSTEM_PROCESSOR=aarch64 \
  -DCMAKE_C_COMPILER=aarch64-linux-gnu-gcc \
  -DCMAKE_CXX_COMPILER=aarch64-linux-gnu-g++ \
  -DCMAKE_INSTALL_PREFIX=/opt/ffmpeg-arm64
```

For autoconf-based projects:

```bash
./configure \
  --prefix=/opt/ffmpeg-arm64 \
  --host=aarch64-linux-gnu \
  --enable-static
```

---

## Raspberry Pi (armhf)

### From x86_64 Linux

```bash
sudo apt install gcc-arm-linux-gnueabihf g++-arm-linux-gnueabihf

./configure \
  --arch=arm \
  --target-os=linux \
  --cross-prefix=arm-linux-gnueabihf- \
  --enable-cross-compile \
  --enable-neon \
  --enable-gpl \
  --cpu=cortex-a72  # RPi 4
```

### Native on Raspberry Pi

Better to build natively on Pi (slow but simpler):

```bash
sudo apt install libx264-dev libx265-dev ...
./configure --enable-gpl --enable-libx264 ...
make -j4  # Pi 4 has 4 cores
```

---

## Docker-Based Cross-Compilation

Most reliable approach - use pre-built toolchain containers.

### Using BtbN's Docker Images

```bash
# Clone build system
git clone https://github.com/BtbN/FFmpeg-Builds.git
cd FFmpeg-Builds

# Build for Windows x64
./build.sh win64 gpl

# Build for Linux ARM64  
./build.sh linuxarm64 gpl

# Result in artifacts/
```

### Using mstorsjo/llvm-mingw

```bash
docker run -it --rm -v $(pwd):/work mstorsjo/llvm-mingw bash
cd /work/ffmpeg
./configure \
  --arch=arm64 \
  --target-os=mingw32 \
  --cross-prefix=aarch64-w64-mingw32- \
  --enable-cross-compile
make -j$(nproc)
```

---

## Verifying Cross-Compiled Binaries

```bash
# Check binary type
file ffmpeg
# Should show: ELF 64-bit LSB executable, ARM aarch64...
# or: PE32+ executable (console) x86-64...

# Check dependencies (for shared builds)
# Linux
aarch64-linux-gnu-readelf -d ffmpeg | grep NEEDED

# Windows
x86_64-w64-mingw32-objdump -p ffmpeg.exe | grep "DLL Name"
```

---

## Troubleshooting Cross-Compilation

| Issue | Cause | Solution |
|-------|-------|----------|
| `cannot find -lx264` | Cross-compiled lib not found | Set `--extra-ldflags=-L/path/to/cross/lib` |
| `x264.h: No such file` | Headers not found | Set `--extra-cflags=-I/path/to/cross/include` |
| `undefined reference` | Link order wrong | Check dependency order in `--extra-libs` |
| Binary runs but segfaults | ABI mismatch | Ensure all deps compiled with same toolchain |
| `pkg-config` finds host libs | Wrong pkg-config | Set `PKG_CONFIG_PATH` to cross prefix |

### Correct pkg-config for Cross-Compilation

```bash
export PKG_CONFIG_PATH=/opt/ffmpeg-arm64/lib/pkgconfig
export PKG_CONFIG_LIBDIR=/opt/ffmpeg-arm64/lib/pkgconfig

# Or use wrapper
export PKG_CONFIG="pkg-config --define-prefix"
```
