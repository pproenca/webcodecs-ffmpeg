# Windows Platform Build Guide

## Table of Contents
- Build Approach Decision
- MSYS2/MinGW-w64 Native Build
- Cross-Compile from Linux
- vcpkg Integration
- Visual Studio / MSVC

---

## Build Approach Decision

| Approach | Pros | Cons | Best For |
|----------|------|------|----------|
| Cross-compile from Linux | Fast, scriptable, CI-friendly | Requires Linux host | Production builds |
| MSYS2/MinGW | Native Windows, easy deps | Slower, complex setup | Development |
| vcpkg | VS integration, managed deps | Less control | MSVC projects |
| Pre-built (BtbN/gyan.dev) | Zero build time | No customization | Quick use |

---

## MSYS2/MinGW-w64 Native Build

### Install MSYS2

1. Download from https://www.msys2.org/
2. Run installer, use default path `C:\msys64`
3. Open **MINGW64** terminal (not MSYS2 terminal)

### Install Dependencies

```bash
# Update package database
pacman -Syu

# Build essentials
pacman -S --needed \
  mingw-w64-x86_64-gcc \
  mingw-w64-x86_64-make \
  mingw-w64-x86_64-pkg-config \
  mingw-w64-x86_64-nasm \
  mingw-w64-x86_64-yasm \
  git \
  make \
  diffutils

# Codec libraries
pacman -S --needed \
  mingw-w64-x86_64-x264 \
  mingw-w64-x86_64-x265 \
  mingw-w64-x86_64-libvpx \
  mingw-w64-x86_64-opus \
  mingw-w64-x86_64-libvorbis \
  mingw-w64-x86_64-lame \
  mingw-w64-x86_64-fdk-aac \
  mingw-w64-x86_64-SDL2
```

### Build FFmpeg

```bash
git clone --depth 1 https://git.ffmpeg.org/ffmpeg.git
cd ffmpeg

./configure \
  --prefix=/mingw64 \
  --enable-gpl \
  --enable-nonfree \
  --enable-shared \
  --enable-libx264 \
  --enable-libx265 \
  --enable-libvpx \
  --enable-libopus \
  --enable-libvorbis \
  --enable-libmp3lame \
  --enable-libfdk-aac \
  --enable-sdl2 \
  --disable-debug \
  --disable-doc

make -j$(nproc)
make install
```

### 32-bit Build

Use **MINGW32** terminal instead:
```bash
# Replace mingw-w64-x86_64 with mingw-w64-i686 in all pacman commands
pacman -S mingw-w64-i686-gcc mingw-w64-i686-x264 ...
```

---

## Cross-Compile from Linux (Recommended)

Faster and more reliable than native Windows builds.

### Install Toolchain (Ubuntu/Debian)

```bash
sudo apt install mingw-w64
```

### Build x264 for Windows

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

### Build x265 for Windows

```bash
git clone --depth 1 https://bitbucket.org/multicoreware/x265_git.git
cd x265_git/build

cmake ../source \
  -DCMAKE_SYSTEM_NAME=Windows \
  -DCMAKE_C_COMPILER=x86_64-w64-mingw32-gcc \
  -DCMAKE_CXX_COMPILER=x86_64-w64-mingw32-g++ \
  -DCMAKE_INSTALL_PREFIX=/opt/ffmpeg-win64 \
  -DENABLE_SHARED=OFF \
  -DENABLE_CLI=OFF

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
  --enable-cross-compile \
  --enable-gpl \
  --enable-libx264 \
  --enable-libx265 \
  --enable-static \
  --disable-shared \
  --extra-cflags="-I/opt/ffmpeg-win64/include" \
  --extra-ldflags="-L/opt/ffmpeg-win64/lib" \
  --pkg-config-flags="--static"

make -j$(nproc)
```

Result: `ffmpeg.exe`, `ffprobe.exe`, `ffplay.exe`

---

## Windows ARM64

Use LLVM MinGW (better ARM64 support):

```bash
# Download LLVM MinGW
wget https://github.com/mstorsjo/llvm-mingw/releases/latest/download/llvm-mingw-*-ucrt-ubuntu-*.tar.xz
tar xf llvm-mingw-*.tar.xz
export PATH=$PWD/llvm-mingw-*/bin:$PATH

# Configure FFmpeg
./configure \
  --arch=arm64 \
  --target-os=mingw32 \
  --cross-prefix=aarch64-w64-mingw32- \
  --enable-cross-compile \
  ...
```

---

## vcpkg Integration

For Visual Studio / MSVC projects:

### Setup vcpkg

```cmd
git clone https://github.com/microsoft/vcpkg
cd vcpkg
bootstrap-vcpkg.bat
```

### Install FFmpeg via vcpkg

```cmd
:: Default build (debug + release)
vcpkg install ffmpeg

:: Release only
vcpkg install ffmpeg:x64-windows-rel

:: Specific features
vcpkg install ffmpeg[core,x264,x265,vpx,opus]:x64-windows

:: Check features in ports/ffmpeg/vcpkg.json
```

### Use in CMake

```cmake
# In CMakeLists.txt
find_package(FFmpeg REQUIRED)
target_link_libraries(myapp PRIVATE FFmpeg::avcodec FFmpeg::avformat)
```

```cmd
:: Configure with vcpkg toolchain
cmake -B build -S . -DCMAKE_TOOLCHAIN_FILE=C:/vcpkg/scripts/buildsystems/vcpkg.cmake
```

---

## Visual Studio / MSVC Build

FFmpeg can be built with MSVC, but it's more complex:

### Requirements

- Visual Studio 2019+ with C++ workload
- MSYS2 for configure script
- NASM in PATH

### Build Steps

```cmd
:: Open "x64 Native Tools Command Prompt for VS 2022"

:: Set MSYS2 in PATH (for bash/configure)
set PATH=C:\msys64\usr\bin;%PATH%

:: Enter MSYS2 bash
bash

# In bash:
./configure \
  --toolchain=msvc \
  --prefix=/c/ffmpeg-msvc \
  --enable-shared \
  --arch=x86_64

make -j8
make install
```

### MSVC Static Libraries

```bash
./configure \
  --toolchain=msvc \
  --enable-static \
  --disable-shared \
  --extra-cflags="-MT" \
  --extra-ldflags="-LIBPATH:C:/path/to/libs"
```

---

## DLL Dependencies

For shared builds, you need these DLLs alongside ffmpeg.exe:

From MinGW (`C:\msys64\mingw64\bin`):
- `libgcc_s_seh-1.dll`
- `libstdc++-6.dll`
- `libwinpthread-1.dll`

From codec packages:
- `libx264-*.dll`
- `libx265.dll`
- etc.

**Tip:** Use `ldd ffmpeg.exe` in MSYS2 to list dependencies.

---

## Pre-built Windows Binaries

If you don't need customization:

### BtbN Builds (Recommended)
https://github.com/BtbN/FFmpeg-Builds/releases

```
ffmpeg-master-latest-win64-gpl.zip      # Static, GPL
ffmpeg-master-latest-win64-lgpl.zip     # Static, LGPL
ffmpeg-master-latest-win64-gpl-shared.zip  # Shared libs
```

### Gyan.dev Builds
https://www.gyan.dev/ffmpeg/builds/

```
ffmpeg-release-full.7z     # Everything, release version
ffmpeg-git-full.7z         # Everything, latest git
ffmpeg-release-essentials  # Common codecs only
```

---

## Verification

```cmd
:: Check version
ffmpeg -version

:: Should show "built with gcc" for MinGW or "built with cl" for MSVC
ffmpeg -buildconf

:: Test encode
ffmpeg -f lavfi -i testsrc=duration=1:size=1280x720 -c:v libx264 test.mp4
```
