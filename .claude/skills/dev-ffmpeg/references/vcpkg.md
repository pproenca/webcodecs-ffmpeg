# vcpkg FFmpeg Integration

Using vcpkg to manage FFmpeg dependencies for Visual Studio and CMake projects.

## Table of Contents
- Setup
- Installing FFmpeg
- Feature Selection
- CMake Integration
- Troubleshooting

---

## Setup

### Clone and Bootstrap

```cmd
:: Windows
git clone https://github.com/microsoft/vcpkg
cd vcpkg
bootstrap-vcpkg.bat
```

```bash
# Linux/macOS
git clone https://github.com/microsoft/vcpkg
cd vcpkg
./bootstrap-vcpkg.sh
```

### Add to PATH

```cmd
:: Add vcpkg to PATH (Windows)
set PATH=%PATH%;C:\path\to\vcpkg

:: Or set VCPKG_ROOT
set VCPKG_ROOT=C:\path\to\vcpkg
```

---

## Installing FFmpeg

### Default Installation

```cmd
vcpkg install ffmpeg
```

This installs debug + release builds with default features.

### Specify Triplet (Architecture)

```cmd
:: 64-bit Windows
vcpkg install ffmpeg:x64-windows

:: 32-bit Windows  
vcpkg install ffmpeg:x86-windows

:: Static linking
vcpkg install ffmpeg:x64-windows-static

:: Linux
vcpkg install ffmpeg:x64-linux

:: macOS
vcpkg install ffmpeg:x64-osx
vcpkg install ffmpeg:arm64-osx
```

### Release Only (Faster Build)

Create custom triplet `x64-windows-rel.cmake`:

```cmake
set(VCPKG_TARGET_ARCHITECTURE x64)
set(VCPKG_CRT_LINKAGE dynamic)
set(VCPKG_LIBRARY_LINKAGE dynamic)
set(VCPKG_BUILD_TYPE release)
```

```cmd
vcpkg install ffmpeg:x64-windows-rel
```

---

## Feature Selection

### Check Available Features

Features are defined in `ports/ffmpeg/vcpkg.json`:

```cmd
vcpkg search ffmpeg
```

Common features:
- `avcodec` - Core codec library
- `avformat` - Container/format handling
- `swscale` - Image scaling/conversion
- `swresample` - Audio resampling
- `avfilter` - Audio/video filters
- `avdevice` - Device I/O
- `x264` - H.264 encoder
- `x265` - H.265/HEVC encoder
- `vpx` - VP8/VP9 codec
- `opus` - Opus audio codec
- `mp3lame` - MP3 encoder
- `fdk-aac` - AAC encoder (nonfree)
- `openssl` - TLS support
- `ffmpeg` - CLI tools
- `ffprobe` - CLI probe tool

### Install with Specific Features

```cmd
:: Override defaults with [core], then add features
vcpkg install ffmpeg[core,avcodec,avformat,swscale,x264,x265]:x64-windows

:: All commonly needed features
vcpkg install ffmpeg[core,avcodec,avformat,avfilter,swscale,swresample,x264,x265,vpx,opus]:x64-windows

:: Minimal (decode only)
vcpkg install ffmpeg[core,avcodec,avformat]:x64-windows
```

### Dry Run

Preview what will be installed:

```cmd
vcpkg install ffmpeg[core,x264,x265]:x64-windows --dry-run
```

---

## CMake Integration

### Method 1: Toolchain File

```cmd
cmake -B build -S . -DCMAKE_TOOLCHAIN_FILE=C:/vcpkg/scripts/buildsystems/vcpkg.cmake
cmake --build build
```

### Method 2: CMake Preset

`CMakePresets.json`:
```json
{
  "version": 3,
  "configurePresets": [
    {
      "name": "vcpkg",
      "generator": "Ninja",
      "binaryDir": "${sourceDir}/build",
      "cacheVariables": {
        "CMAKE_TOOLCHAIN_FILE": "$env{VCPKG_ROOT}/scripts/buildsystems/vcpkg.cmake"
      }
    }
  ]
}
```

```cmd
cmake --preset vcpkg
cmake --build build
```

### CMakeLists.txt

```cmake
cmake_minimum_required(VERSION 3.20)
project(my_project)

# Find FFmpeg packages
find_package(FFMPEG REQUIRED)

add_executable(my_app main.cpp)

target_include_directories(my_app PRIVATE ${FFMPEG_INCLUDE_DIRS})
target_link_libraries(my_app PRIVATE ${FFMPEG_LIBRARIES})

# Or use imported targets (preferred)
find_package(PkgConfig REQUIRED)
pkg_check_modules(LIBAV REQUIRED IMPORTED_TARGET
    libavcodec
    libavformat
    libavutil
    libswscale
)

target_link_libraries(my_app PRIVATE PkgConfig::LIBAV)
```

### Visual Studio Integration

```cmd
:: Integrate with Visual Studio (user-wide)
vcpkg integrate install

:: Now VS projects can #include FFmpeg headers
:: and linking is automatic
```

---

## Manifest Mode

For project-local dependencies, create `vcpkg.json`:

```json
{
  "name": "my-project",
  "version": "1.0.0",
  "dependencies": [
    {
      "name": "ffmpeg",
      "features": ["avcodec", "avformat", "swscale", "x264", "x265"]
    }
  ]
}
```

```cmd
:: vcpkg will auto-install when CMake configures
cmake -B build -S . -DCMAKE_TOOLCHAIN_FILE=C:/vcpkg/scripts/buildsystems/vcpkg.cmake
```

---

## Build from Source Modifications

### Custom Port Overlay

To modify FFmpeg build options:

1. Copy port:
```cmd
xcopy /E /I %VCPKG_ROOT%\ports\ffmpeg my-ports\ffmpeg
```

2. Edit `my-ports/ffmpeg/portfile.cmake`:
```cmake
# Add custom configure options
vcpkg_configure_make(
    SOURCE_PATH "${SOURCE_PATH}"
    OPTIONS
        --enable-gpl
        --enable-libx264
        --your-custom-option
)
```

3. Use overlay:
```cmd
vcpkg install ffmpeg:x64-windows --overlay-ports=my-ports
```

---

## Troubleshooting

### "Could not find FFmpeg"

```cmake
# Add verbose output
set(FFMPEG_DIR "${VCPKG_INSTALLED_DIR}/x64-windows/share/ffmpeg")
find_package(FFMPEG REQUIRED CONFIG)
```

### Missing DLLs at Runtime

```cmd
:: Copy DLLs to output directory
xcopy /Y "%VCPKG_INSTALLED_DIR%\x64-windows\bin\*.dll" ".\build\Release\"
```

Or in CMake:
```cmake
# Post-build copy
add_custom_command(TARGET my_app POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
        $<TARGET_RUNTIME_DLLS:my_app>
        $<TARGET_FILE_DIR:my_app>
    COMMAND_EXPAND_LISTS
)
```

### Feature Not Available

Check if feature is supported:
```cmd
vcpkg search ffmpeg

:: Check port info
type %VCPKG_ROOT%\ports\ffmpeg\vcpkg.json
```

### Long Build Times

- Use `--dry-run` to preview dependencies
- Use release-only triplet
- Use binary caching:
```cmd
set VCPKG_BINARY_SOURCES=clear;files,C:\vcpkg-cache,readwrite
vcpkg install ffmpeg:x64-windows
```

---

## Installed Files Location

```
vcpkg/installed/x64-windows/
├── bin/
│   ├── avcodec-60.dll
│   ├── avformat-60.dll
│   └── ...
├── include/
│   ├── libavcodec/
│   ├── libavformat/
│   └── ...
├── lib/
│   ├── avcodec.lib
│   ├── avformat.lib
│   └── ...
└── share/
    └── ffmpeg/
        └── FFmpegConfig.cmake
```

---

## Comparison: vcpkg vs Manual Build

| Aspect | vcpkg | Manual |
|--------|-------|--------|
| Setup time | Minutes | Hours |
| Customization | Limited | Full |
| Dependencies | Auto-managed | Manual |
| Updates | `vcpkg upgrade` | Rebuild |
| VS integration | Automatic | Manual |
| Cross-compile | Triplets | Complex |
| Best for | Typical projects | Custom needs |
