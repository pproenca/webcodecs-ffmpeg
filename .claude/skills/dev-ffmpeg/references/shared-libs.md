# Shared Libraries for Native Addons

Building FFmpeg shared libraries for use in Node.js native addons, Python extensions, or other language bindings.

## Table of Contents
- Build Configuration
- pkg-config Setup
- Node.js Native Addon Integration
- Python FFI Integration
- Distribution Strategies

---

## Build Configuration

### Essential Configure Flags

```bash
./configure \
  --prefix=/usr/local \
  --enable-shared \          # Build .so/.dylib/.dll files
  --disable-static \         # Skip .a files (optional)
  --enable-pic \             # Position Independent Code (required)
  --enable-gpl \             # If using GPL codecs
  --enable-libx264 \
  --enable-libx265 \
  --enable-libvpx \
  --enable-libopus \
  --disable-programs \       # Optional: skip ffmpeg/ffprobe binaries
  --disable-debug \
  --disable-doc

make -j$(nproc)
sudo make install
sudo ldconfig  # Linux only
```

### Result

```
/usr/local/lib/
├── libavcodec.so -> libavcodec.so.60
├── libavcodec.so.60 -> libavcodec.so.60.31.102
├── libavcodec.so.60.31.102
├── libavformat.so -> libavformat.so.60
├── libavformat.so.60 -> libavformat.so.60.16.100
├── libavformat.so.60.16.100
├── libavutil.so -> libavutil.so.58
├── libswresample.so -> libswresample.so.4
├── libswscale.so -> libswscale.so.7
└── pkgconfig/
    ├── libavcodec.pc
    ├── libavformat.pc
    ├── libavutil.pc
    └── ...
```

---

## pkg-config Setup

### Verify Installation

```bash
# Check pkg-config finds FFmpeg
pkg-config --exists libavcodec && echo "Found"

# Get compile flags
pkg-config --cflags libavcodec libavformat libavutil
# Output: -I/usr/local/include

# Get link flags
pkg-config --libs libavcodec libavformat libavutil
# Output: -L/usr/local/lib -lavcodec -lavformat -lavutil
```

### Fix pkg-config Path Issues

```bash
# Add FFmpeg pkg-config path
export PKG_CONFIG_PATH=/usr/local/lib/pkgconfig:$PKG_CONFIG_PATH

# For Homebrew on macOS
export PKG_CONFIG_PATH=/opt/homebrew/lib/pkgconfig:$PKG_CONFIG_PATH

# Verify
pkg-config --variable=prefix libavcodec
```

### Static Linking via pkg-config

For statically linked binaries (single executable):

```bash
pkg-config --static --libs libavcodec libavformat libavutil
```

---

## Node.js Native Addon Integration

### binding.gyp Configuration

```python
{
  "targets": [{
    "target_name": "my_addon",
    "sources": ["src/addon.cc"],
    "include_dirs": [
      "<!@(pkg-config --cflags-only-I libavcodec libavformat libavutil | sed 's/-I//g')"
    ],
    "libraries": [
      "<!@(pkg-config --libs libavcodec libavformat libavutil)"
    ],
    "cflags!": ["-fno-exceptions"],
    "cflags_cc!": ["-fno-exceptions"],
    "cflags_cc": ["-std=c++17"],
    "conditions": [
      ["OS=='linux'", {
        "cflags_cc": ["-fPIC"]
      }],
      ["OS=='mac'", {
        "xcode_settings": {
          "GCC_ENABLE_CPP_EXCEPTIONS": "YES",
          "CLANG_CXX_LIBRARY": "libc++"
        }
      }]
    ]
  }]
}
```

### CMake Configuration (cmake-js)

```cmake
cmake_minimum_required(VERSION 3.15)
project(my_addon)

# Find FFmpeg via pkg-config
find_package(PkgConfig REQUIRED)
pkg_check_modules(FFMPEG REQUIRED 
  libavcodec 
  libavformat 
  libavutil 
  libswscale 
  libswresample
)

# Node.js addon setup
include_directories(${CMAKE_JS_INC})
add_library(${PROJECT_NAME} SHARED 
  src/addon.cc
  src/decoder.cc
)

target_include_directories(${PROJECT_NAME} PRIVATE 
  ${FFMPEG_INCLUDE_DIRS}
)
target_link_libraries(${PROJECT_NAME} 
  ${CMAKE_JS_LIB}
  ${FFMPEG_LIBRARIES}
)
target_compile_features(${PROJECT_NAME} PRIVATE cxx_std_17)

# Node.js module suffix
set_target_properties(${PROJECT_NAME} PROPERTIES 
  PREFIX "" 
  SUFFIX ".node"
)
```

### Runtime Library Path

Ensure FFmpeg libraries are found at runtime:

**Linux:**
```bash
# Option 1: Install to system path
sudo ldconfig

# Option 2: Set rpath during build
./configure --extra-ldflags="-Wl,-rpath,/usr/local/lib"

# Option 3: Set LD_LIBRARY_PATH
export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH
```

**macOS:**
```bash
# Option 1: Set rpath
install_name_tool -add_rpath /usr/local/lib my_addon.node

# Option 2: Set DYLD_LIBRARY_PATH
export DYLD_LIBRARY_PATH=/usr/local/lib:$DYLD_LIBRARY_PATH
```

---

## Dockerfile for Node.js Addon Build

```dockerfile
FROM node:20-bookworm AS builder

# Install FFmpeg build dependencies
RUN apt-get update && apt-get install -y \
    build-essential pkg-config nasm yasm \
    libx264-dev libx265-dev libvpx-dev libopus-dev

# Build FFmpeg with shared libs
WORKDIR /ffmpeg
RUN git clone --depth 1 --branch n7.1 https://git.ffmpeg.org/ffmpeg.git .
RUN ./configure \
    --prefix=/usr/local \
    --enable-shared \
    --disable-static \
    --enable-pic \
    --enable-gpl \
    --enable-libx264 \
    --enable-libx265 \
    --enable-libvpx \
    --enable-libopus \
    --disable-programs \
    --disable-debug \
    --disable-doc \
    && make -j$(nproc) \
    && make install \
    && ldconfig

# Build Node.js addon
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
RUN npm run build

# Runtime image
FROM node:20-bookworm-slim

# Runtime dependencies only
RUN apt-get update && apt-get install -y \
    libx264-164 libx265-209 libvpx9 libopus0 \
    && rm -rf /var/lib/apt/lists/*

# Copy FFmpeg libraries
COPY --from=builder /usr/local/lib/libav*.so* /usr/local/lib/
COPY --from=builder /usr/local/lib/libsw*.so* /usr/local/lib/

# Update library cache
RUN ldconfig

# Copy addon
COPY --from=builder /app /app

WORKDIR /app
ENV LD_LIBRARY_PATH=/usr/local/lib
CMD ["node", "index.js"]
```

---

## Python FFI Integration

### Using cffi

```python
# build_ffi.py
from cffi import FFI

ffi = FFI()

ffi.cdef("""
    // FFmpeg function declarations
    int avcodec_version(void);
    const char *avcodec_configuration(void);
    
    // Add more declarations as needed
""")

ffi.set_source(
    "_ffmpeg",
    """
    #include <libavcodec/avcodec.h>
    """,
    libraries=['avcodec', 'avformat', 'avutil'],
    library_dirs=['/usr/local/lib'],
    include_dirs=['/usr/local/include'],
)

if __name__ == "__main__":
    ffi.compile(verbose=True)
```

### Using ctypes

```python
import ctypes
import ctypes.util

# Find library
libavcodec_path = ctypes.util.find_library('avcodec')
libavcodec = ctypes.CDLL(libavcodec_path)

# Call function
version = libavcodec.avcodec_version()
print(f"libavcodec version: {version}")
```

---

## Distribution Strategies

### Option 1: System Dependencies

Document required system packages:

**Ubuntu/Debian:**
```bash
sudo apt install libavcodec-dev libavformat-dev libavutil-dev
```

**macOS:**
```bash
brew install ffmpeg
```

### Option 2: Bundled Libraries

Include prebuilt FFmpeg libraries in your package:

```
my-package/
├── prebuilds/
│   ├── linux-x64/
│   │   ├── libavcodec.so.60
│   │   ├── libavformat.so.60
│   │   └── ...
│   ├── darwin-arm64/
│   │   ├── libavcodec.60.dylib
│   │   └── ...
│   └── win32-x64/
│       ├── avcodec-60.dll
│       └── ...
└── src/
```

Use `prebuild` or `prebuildify` for Node.js addons.

### Option 3: Build Script

Provide build script that downloads and compiles FFmpeg:

```bash
#!/bin/bash
# scripts/build-ffmpeg.sh

FFMPEG_VERSION=7.1
PREFIX=${1:-/usr/local}

curl -L https://ffmpeg.org/releases/ffmpeg-${FFMPEG_VERSION}.tar.bz2 | tar xj
cd ffmpeg-${FFMPEG_VERSION}

./configure \
  --prefix=$PREFIX \
  --enable-shared \
  --disable-static \
  --enable-pic \
  --enable-gpl \
  --enable-libx264 \
  --disable-programs \
  --disable-doc

make -j$(nproc)
make install
```

---

## Verification

```bash
# Check shared libraries exist
ls -la /usr/local/lib/libav*.so*

# Check pkg-config
pkg-config --modversion libavcodec

# Check symbols are exported
nm -D /usr/local/lib/libavcodec.so | grep avcodec_send_packet

# Test in Node.js
node -e "require('./build/Release/my_addon.node')"
```
