# FFmpeg Prebuilds Modernization - Design Document

**Date:** 2026-01-04
**Status:** Approved
**Scope:** All 18 gaps from gap analysis
**Strategy:** Phased rollout (5 phases)
**Constraint:** Strict official FFmpeg guidance compliance

---

## Design Overview

This design modernizes the FFmpeg prebuilds repository to align with official FFmpeg compilation guides, implementing all 18 identified gaps through 5 distinct phases.

### Key Principles

1. **Strict Official Guidance**: Follow FFmpeg's official compilation guides exactly
2. **Phased Rollout**: Implement in 5 testable phases
3. **Progress Tracking**: Maintain `progress.txt` throughout implementation
4. **Backward Compatibility**: Existing packages continue working
5. **No Breaking Changes**: Additive improvements only

---

## Phase 1: Platform Expansion

**Goal:** Add Windows support and unify macOS builds
**Duration:** 2-3 weeks
**Official Guides:** Windows Cross-Compilation, macOS

### 1.1 Windows Support (Cross-Compilation)

**Implementation:**
- Platform: `windows-x64`
- Toolchain: MinGW-w64 on Ubuntu 24.04
- Cross-compiler: `x86_64-w64-mingw32-`
- Output: `ffmpeg.exe`, `ffprobe.exe`, static libraries

**Dockerfile:** `platforms/windows-x64/Dockerfile`
```dockerfile
FROM ubuntu:24.04

RUN apt-get update && apt-get install -y \
    mingw-w64 \
    mingw-w64-tools \
    gcc-mingw-w64-x86-64 \
    g++-mingw-w64-x86-64 \
    nasm \
    yasm \
    pkg-config \
    make \
    git \
    wget \
    cmake

# Set environment
ENV CROSS_PREFIX=x86_64-w64-mingw32-
ENV TARGET=/opt/ffmpeg
```

**Configure Flags (per official guide):**
```bash
./configure \
  --arch=x86_64 \
  --target-os=mingw32 \
  --cross-prefix=x86_64-w64-mingw32- \
  --prefix=$TARGET \
  --pkg-config=pkg-config \
  --enable-static \
  --disable-shared \
  --enable-gpl \
  --enable-version3 \
  --enable-runtime-cpudetect \
  --disable-doc \
  --disable-debug \
  --extra-cflags="-I$TARGET/include" \
  --extra-ldflags="-L$TARGET/lib -static" \
  --enable-libx264 \
  --enable-libx265 \
  --enable-libvpx \
  --enable-libaom \
  --enable-libopus \
  --enable-libmp3lame
```

**npm Package:** `@pproenca/ffmpeg-windows-x64`

### 1.2 macOS Universal Binaries

**Strategy:**
- Build x64 and arm64 separately
- Merge using `lipo` into universal binaries
- Single package: `@pproenca/ffmpeg-darwin-universal`

**Build Script:** `build/create-universal.sh`
```bash
#!/bin/bash
set -e

DARWIN_X64="artifacts/darwin-x64"
DARWIN_ARM64="artifacts/darwin-arm64"
DARWIN_UNIVERSAL="artifacts/darwin-universal"

mkdir -p $DARWIN_UNIVERSAL/{bin,lib,include}

# Merge binaries
for bin in ffmpeg ffprobe; do
  lipo -create \
    $DARWIN_X64/bin/$bin \
    $DARWIN_ARM64/bin/$bin \
    -output $DARWIN_UNIVERSAL/bin/$bin
done

# Merge static libraries
for lib in libavcodec libavformat libavutil libswscale libswresample libavfilter \
           libx264 libx265 libvpx libaom libopus libmp3lame; do
  lipo -create \
    $DARWIN_X64/lib/${lib}.a \
    $DARWIN_ARM64/lib/${lib}.a \
    -output $DARWIN_UNIVERSAL/lib/${lib}.a
done

# Copy headers (identical across architectures)
cp -r $DARWIN_X64/include/* $DARWIN_UNIVERSAL/include/

echo "Universal binaries created successfully"
```

**CI Workflow Update:**
```yaml
- name: Build macOS x64
  if: matrix.platform == 'darwin-universal'
  run: ./build/orchestrator.sh darwin-x64

- name: Build macOS arm64
  if: matrix.platform == 'darwin-universal'
  run: ./build/orchestrator.sh darwin-arm64

- name: Create Universal
  if: matrix.platform == 'darwin-universal'
  run: ./build/create-universal.sh
```

**Migration:**
- Deprecate: `@pproenca/ffmpeg-darwin-x64`, `@pproenca/ffmpeg-darwin-arm64`
- Publish: `@pproenca/ffmpeg-darwin-universal`

---

## Phase 2: Codec Library Expansion

**Goal:** Add 9 new codecs following official guides
**Duration:** 2-3 weeks
**Official Guides:** Ubuntu, CentOS

### 2.1 New Codecs

**Video Codecs:**

1. **SVT-AV1** (v2.3.0, BSD License)
   - Repo: `https://gitlab.com/AOMediaCodec/SVT-AV1.git`
   - Build: CMake
   - Flag: `--enable-libsvtav1`

2. **rav1e** (v0.7.1, BSD License)
   - Repo: `https://github.com/xiph/rav1e.git`
   - Build: Cargo + C bindings
   - Flag: `--enable-librav1e`
   - Requires: Rust toolchain

3. **Theora** (v1.1.1, BSD License)
   - Repo: `https://gitlab.xiph.org/xiph/theora.git`
   - Build: autotools
   - Flag: `--enable-libtheora`

4. **Xvid** (1.3.7, GPL License)
   - Source: `https://downloads.xvid.com/downloads/xvidcore-1.3.7.tar.gz`
   - Build: autotools
   - Flag: `--enable-libxvid`

**Audio Codecs:**

5. **fdk-aac** (v2.0.3, Non-free)
   - Repo: `https://github.com/mstorsjo/fdk-aac.git`
   - Build: autotools
   - Flag: `--enable-libfdk-aac --enable-nonfree`

6. **FLAC** (1.4.3, BSD License)
   - Repo: `https://github.com/xiph/flac.git`
   - Build: CMake
   - Flag: `--enable-libflac`

7. **Speex** (1.2.1, BSD License)
   - Repo: `https://gitlab.xiph.org/xiph/speex.git`
   - Build: autotools
   - Flag: `--enable-libspeex`

**Rendering Libraries:**

8. **libass** (0.17.3, ISC License)
   - Repo: `https://github.com/libass/libass.git`
   - Build: autotools
   - Dependencies: libfreetype, fribidi, fontconfig
   - Flag: `--enable-libass`

9. **libfreetype** (2.13.3, FreeType License)
   - Source: `https://download.savannah.gnu.org/releases/freetype/freetype-2.13.3.tar.gz`
   - Build: autotools
   - Flag: `--enable-libfreetype`
   - Note: Build from source (don't use macOS `/opt/X11/`)

### 2.2 Version Management

Update `versions.properties`:
```properties
# Existing codecs (unchanged)
X264_VERSION=stable
X265_VERSION=3.6
LIBVPX_VERSION=v1.15.2
LIBAOM_VERSION=v3.12.1
OPUS_VERSION=1.5.2
LAME_VERSION=3.100
LIBVORBIS_VERSION=1.3.7
LIBOGG_VERSION=1.3.5

# New video codecs
SVTAV1_VERSION=v2.3.0
RAV1E_VERSION=v0.7.1
THEORA_VERSION=v1.1.1
XVID_VERSION=1.3.7
XVID_SHA256=abbdcbd39555691dd1c9b4d08f0a031376a3b211652c0d8b3b8aa9be1303ce2d

# New audio codecs
FDK_AAC_VERSION=v2.0.3
FLAC_VERSION=1.4.3
SPEEX_VERSION=1.2.1

# Rendering libraries
LIBASS_VERSION=0.17.3
FREETYPE_VERSION=2.13.3
FREETYPE_SHA256=0550350666d427c74daeb85d5ac7bb353acba5f76956395995311a9c6f063289
FRIBIDI_VERSION=1.0.16
FONTCONFIG_VERSION=2.15.0
```

### 2.3 Licensing Documentation

Create `CODECS.md`:
```markdown
# Codec Licensing Guide

## Quick Reference

| Codec | License | Enables GPL? | Enables Non-free? | Use Case |
|-------|---------|--------------|-------------------|----------|
| **Video Codecs** |
| x264 | GPL v2+ | ✅ Yes | - | H.264 encoding |
| x265 | GPL v2+ | ✅ Yes | - | H.265/HEVC encoding |
| xvid | GPL v2+ | ✅ Yes | - | MPEG-4 ASP |
| libvpx | BSD-3 | ❌ No | ❌ No | VP8/VP9 encoding |
| libaom | BSD-2 | ❌ No | ❌ No | AV1 encoding |
| SVT-AV1 | BSD-2 | ❌ No | ❌ No | Fast AV1 encoding |
| rav1e | BSD-2 | ❌ No | ❌ No | Rust AV1 encoder |
| Theora | BSD-3 | ❌ No | ❌ No | Ogg video |
| **Audio Codecs** |
| libmp3lame | LGPL v2+ | ❌ No | ❌ No | MP3 encoding |
| libopus | BSD-3 | ❌ No | ❌ No | Opus encoding |
| libvorbis | BSD-3 | ❌ No | ❌ No | Vorbis encoding |
| fdk-aac | Custom (non-free) | - | ✅ Yes | AAC encoding |
| FLAC | BSD-3 | ❌ No | ❌ No | Lossless audio |
| Speex | BSD-3 | ❌ No | ❌ No | Speech codec |
| **Rendering** |
| libass | ISC | ❌ No | ❌ No | Subtitle rendering |
| libfreetype | FreeType | ❌ No | ❌ No | Font rendering |

## Build Variants

### Full Build (Default)
- **License:** GPL v2+ + Non-free
- **Codecs:** All codecs enabled
- **Use Case:** Maximum compatibility, personal use
- **Distribution:** Can distribute binaries, but GPL applies

### GPL Build
- **License:** GPL v2+
- **Codecs:** All except fdk-aac
- **Use Case:** GPL-compatible projects
- **Distribution:** Can distribute, source must be available

### LGPL Build
- **License:** LGPL v2.1+
- **Codecs:** Excludes x264, x265, xvid, fdk-aac
- **Use Case:** Commercial/proprietary software
- **Distribution:** Can link dynamically without disclosing source

## Legal Implications

### Using GPL Codecs (x264, x265, xvid)
- Your entire build becomes GPL
- Must provide source code if distributing
- Cannot use in proprietary software without licensing

### Using Non-free Codecs (fdk-aac)
- Cannot distribute binaries without permission
- Patent licensing may be required
- Research/personal use typically OK

### Using BSD/Permissive Codecs
- No restrictions on use or distribution
- Can use in commercial software
- Attribution required (varies by license)

## Recommended Configurations

### Personal/Research Use
```bash
# Use full build - all codecs
./build/orchestrator.sh linux-x64-glibc
```

### Commercial Application
```bash
# Use LGPL build - excludes GPL codecs
BUILD_PRESET=lgpl ./build/orchestrator.sh linux-x64-glibc
```

### Open Source Project (GPL)
```bash
# Use GPL build - excludes non-free
BUILD_PRESET=gpl ./build/orchestrator.sh linux-x64-glibc
```
```

### 2.4 Build Script Changes

Modify `build/macos.sh` and `build/linux.sh` to include new codecs:

**Example: Adding SVT-AV1**
```bash
# Build SVT-AV1
cd "$SOURCES"
git clone --depth 1 --branch ${SVTAV1_VERSION} \
  https://gitlab.com/AOMediaCodec/SVT-AV1.git
cd SVT-AV1/Build
cmake .. -DCMAKE_INSTALL_PREFIX="$TARGET" \
  -DCMAKE_BUILD_TYPE=Release \
  -DBUILD_SHARED_LIBS=OFF \
  -DCMAKE_POSITION_INDEPENDENT_CODE=ON
make -j$(nproc)
make install
```

---

## Phase 3: Hardware Acceleration

**Goal:** Add HW acceleration for Linux, macOS, Windows
**Duration:** 4-5 weeks
**Official Guides:** Ubuntu, macOS, Windows

### 3.1 Linux Hardware Acceleration

**VA-API (Intel/AMD GPUs):**
- Variant: `linux-x64-glibc-vaapi`
- Dependencies: `libva-dev`, `libdrm-dev`
- Flag: `--enable-vaapi`

**VDPAU (NVIDIA GPUs - Decode only):**
- Variant: `linux-x64-glibc-vdpau`
- Dependencies: `libvdpau-dev`
- Flag: `--enable-vdpau`

**NVENC/NVDEC (NVIDIA - Encode/Decode):**
- Variant: `linux-x64-glibc-nvidia`
- Dependencies: nv-codec-headers (v12.2.72.0)
- Flags: `--enable-nvenc --enable-nvdec --enable-cuda-llvm`

**Dockerfile Example (VA-API):**
```dockerfile
FROM ubuntu:24.04

# Install VA-API dependencies
RUN apt-get update && apt-get install -y \
    libva-dev \
    libdrm-dev \
    libva-drm2 \
    vainfo

# Build FFmpeg with VA-API
RUN ./configure \
    --enable-vaapi \
    # ... other flags ...
```

### 3.2 macOS Hardware Acceleration

**VideoToolbox + AudioToolbox:**
- Variant: `darwin-universal-videotoolbox`
- Dependencies: None (built into macOS)
- Flags: `--enable-videotoolbox --enable-audiotoolbox`
- Benefits: 10-20x faster H.264/HEVC encoding

**Configure:**
```bash
./configure \
  --enable-videotoolbox \
  --enable-audiotoolbox \
  # ... other flags ...
```

### 3.3 Windows Hardware Acceleration

**DXVA2 (DirectX Video Acceleration):**
- Variant: `windows-x64-dxva2`
- Dependencies: Windows SDK (included in MinGW)
- Flag: `--enable-dxva2`

**D3D11VA (Direct3D 11):**
- Variant: `windows-x64-d3d11va`
- Flag: `--enable-d3d11va`

### 3.4 Platform Matrix

| Platform | Variant | HW Accel | npm Package |
|----------|---------|----------|-------------|
| Linux glibc | Base | None | `@pproenca/ffmpeg-linux-x64-glibc` |
| Linux glibc | VA-API | Intel/AMD | `@pproenca/ffmpeg-linux-x64-glibc-vaapi` |
| Linux glibc | NVIDIA | NVIDIA | `@pproenca/ffmpeg-linux-x64-glibc-nvidia` |
| Linux musl | Base | None | `@pproenca/ffmpeg-linux-x64-musl` |
| macOS | Base | None | `@pproenca/ffmpeg-darwin-universal` |
| macOS | VideoToolbox | Apple HW | `@pproenca/ffmpeg-darwin-universal-videotoolbox` |
| Windows | Base | None | `@pproenca/ffmpeg-windows-x64` |
| Windows | DXVA2 | DirectX | `@pproenca/ffmpeg-windows-x64-dxva2` |

### 3.5 Runtime Detection

Create `lib/detect-hw.js`:
```javascript
const os = require('os');
const { execSync } = require('child_process');

function detectHardwareAccel() {
  const platform = os.platform();

  if (platform === 'darwin') {
    // VideoToolbox always available on macOS 10.8+
    return 'videotoolbox';
  } else if (platform === 'linux') {
    // Check for VA-API
    try {
      execSync('vainfo', { stdio: 'ignore' });
      return 'vaapi';
    } catch {
      // Check for NVIDIA
      try {
        execSync('nvidia-smi', { stdio: 'ignore' });
        return 'nvidia';
      } catch {
        return 'software';
      }
    }
  } else if (platform === 'win32') {
    // Check for DirectX support
    // DXVA2 available on Windows 7+
    return 'dxva2';
  }

  return 'software';
}

module.exports = { detectHardwareAccel };
```

---

## Phase 4: Build System Enhancements

**Goal:** Add customization, incremental builds, ARM support
**Duration:** 2-3 weeks
**Official Guides:** Generic, vcpkg

### 4.1 Build Customization

**Configuration Schema:** `build-config.json`
```json
{
  "$schema": "./build-config.schema.json",
  "preset": "full",
  "codecs": {
    "video": {
      "h264": true,
      "h265": true,
      "vp8": true,
      "vp9": true,
      "av1": true,
      "svt-av1": true,
      "rav1e": false,
      "theora": false,
      "xvid": true
    },
    "audio": {
      "opus": true,
      "mp3": true,
      "aac": true,
      "fdk-aac": false,
      "flac": true,
      "speex": false,
      "vorbis": true
    }
  },
  "features": {
    "hwaccel": false,
    "subtitle_rendering": true,
    "network": false
  },
  "optimization": {
    "size": false,
    "speed": true
  }
}
```

**Preset Configs:**

**minimal.json:**
```json
{
  "preset": "minimal",
  "codecs": {
    "video": {"h264": true, "h265": true},
    "audio": {"opus": true, "mp3": true}
  },
  "features": {"hwaccel": false, "subtitle_rendering": false, "network": false}
}
```

**streaming.json:**
```json
{
  "preset": "streaming",
  "codecs": {
    "video": {"h264": true, "h265": true, "vp9": true, "av1": true},
    "audio": {"opus": true, "aac": true}
  },
  "features": {"hwaccel": true, "network": true}
}
```

**full.json:**
```json
{
  "preset": "full",
  "codecs": {
    "video": {"h264": true, "h265": true, "vp8": true, "vp9": true,
              "av1": true, "svt-av1": true, "rav1e": true,
              "theora": true, "xvid": true},
    "audio": {"opus": true, "mp3": true, "aac": true, "fdk-aac": true,
              "flac": true, "speex": true, "vorbis": true}
  },
  "features": {"hwaccel": true, "subtitle_rendering": true, "network": true}
}
```

**Build Script Integration:**

Modify `build/orchestrator.sh`:
```bash
#!/bin/bash

# Load build config
BUILD_CONFIG=${BUILD_CONFIG:-build-config.json}

if [ ! -f "$BUILD_CONFIG" ]; then
  echo "Using default full config"
  BUILD_CONFIG="presets/full.json"
fi

# Parse config and set environment variables
export ENABLE_H264=$(jq -r '.codecs.video.h264' $BUILD_CONFIG)
export ENABLE_H265=$(jq -r '.codecs.video.h265' $BUILD_CONFIG)
# ... etc for each codec ...

# Pass to platform-specific script
./build/macos.sh "$@"
```

Modify `build/macos.sh` to use config:
```bash
# Build x264 only if enabled
if [ "$ENABLE_H264" = "true" ]; then
  echo "Building x264..."
  cd "$SOURCES"
  git clone --depth 1 https://code.videolan.org/videolan/x264.git
  # ... build x264 ...
  FFMPEG_FLAGS="$FFMPEG_FLAGS --enable-libx264"
fi
```

### 4.2 Incremental Builds (ccache)

**macOS Implementation:**

Update `build/macos.sh`:
```bash
#!/bin/bash

# Setup ccache if available
if command -v ccache &> /dev/null; then
  export CC="ccache clang"
  export CXX="ccache clang++"
  export CCACHE_DIR="${CCACHE_DIR:-$HOME/.ccache}"
  echo "Using ccache (cache dir: $CCACHE_DIR)"
else
  echo "ccache not found, install with: brew install ccache"
fi

# Continue with normal build...
```

**Docker Implementation:**

Update Dockerfiles:
```dockerfile
FROM ubuntu:24.04

# Install ccache
RUN apt-get update && apt-get install -y ccache

# Setup ccache
ENV CCACHE_DIR=/cache
ENV PATH="/usr/lib/ccache:$PATH"

# Build
RUN make -j$(nproc)
```

**CI Integration:**
```yaml
- name: Setup ccache
  uses: hendrikmuhs/ccache-action@v1.2
  with:
    key: ${{ matrix.platform }}-${{ hashFiles('versions.properties') }}
    max-size: 2G

- name: Build
  run: ./build/orchestrator.sh ${{ matrix.platform }}
  env:
    CCACHE_DIR: ${{ github.workspace }}/.ccache
```

**Expected Performance:**
- First build: 20-30 min (no change)
- Incremental (FFmpeg only): 2-5 min
- Incremental (codec change): 10-15 min

### 4.3 ARM Linux Support

**New Platforms:**

1. **linux-arm64-glibc** (Raspberry Pi 4/5, AWS Graviton)
2. **linux-arm64-musl** (Alpine on ARM)
3. **linux-armv7-glibc** (Raspberry Pi 2/3)

**Dockerfile Example (ARM64 glibc):**
```dockerfile
FROM ubuntu:24.04

# Install ARM cross-compiler
RUN apt-get update && apt-get install -y \
    gcc-aarch64-linux-gnu \
    g++-aarch64-linux-gnu \
    binutils-aarch64-linux-gnu

# Configure for ARM64
RUN ./configure \
    --arch=aarch64 \
    --target-os=linux \
    --cross-prefix=aarch64-linux-gnu- \
    --enable-cross-compile \
    --sysroot=/usr/aarch64-linux-gnu \
    # ... rest of flags ...
```

**CI Matrix Update:**
```yaml
matrix:
  include:
    - platform: linux-arm64-glibc
      runner: ubuntu-24.04
      uses_docker: true
      arch: aarch64
```

### 4.4 Build Parallelization

**Current:** Already uses `make -j$(nproc)` ✅

**Enhancement - Parallel Codec Builds:**

Update build scripts:
```bash
# Build independent codecs in parallel
build_x264 &
PID_X264=$!

build_x265 &
PID_X265=$!

build_vpx &
PID_VPX=$!

build_aom &
PID_AOM=$!

# Wait for all to complete
wait $PID_X264 $PID_X265 $PID_VPX $PID_AOM

# Build FFmpeg (depends on all codecs)
build_ffmpeg
```

### 4.5 Enhanced Verification

Update `build/verify.sh`:
```bash
#!/bin/bash
set -e

PLATFORM=$1
ARTIFACTS="artifacts/$PLATFORM"

# 1. Check binaries exist (existing)
test -f "$ARTIFACTS/bin/ffmpeg" || { echo "ffmpeg not found"; exit 1; }
test -f "$ARTIFACTS/bin/ffprobe" || { echo "ffprobe not found"; exit 1; }

# 2. Check libraries exist (existing)
test -f "$ARTIFACTS/lib/libavcodec.a" || { echo "libavcodec.a not found"; exit 1; }
# ... etc ...

# 3. Verify codec availability (NEW)
echo "Checking codec availability..."
$ARTIFACTS/bin/ffmpeg -codecs 2>&1 | grep -q "h264" || { echo "h264 not found"; exit 1; }
$ARTIFACTS/bin/ffmpeg -codecs 2>&1 | grep -q "hevc" || { echo "hevc not found"; exit 1; }
$ARTIFACTS/bin/ffmpeg -codecs 2>&1 | grep -q "vp9" || { echo "vp9 not found"; exit 1; }
$ARTIFACTS/bin/ffmpeg -codecs 2>&1 | grep -q "av1" || { echo "av1 not found"; exit 1; }

# 4. Verify format support (NEW)
echo "Checking format support..."
$ARTIFACTS/bin/ffmpeg -formats 2>&1 | grep -q "mp4" || { echo "mp4 not found"; exit 1; }
$ARTIFACTS/bin/ffmpeg -formats 2>&1 | grep -q "webm" || { echo "webm not found"; exit 1; }

# 5. Check binary architecture (NEW)
echo "Checking binary architecture..."
if [[ "$PLATFORM" == "darwin-universal" ]]; then
  file $ARTIFACTS/bin/ffmpeg | grep -q "universal binary" || { echo "Not universal"; exit 1; }
elif [[ "$PLATFORM" == *"x64"* ]] || [[ "$PLATFORM" == *"x86_64"* ]]; then
  file $ARTIFACTS/bin/ffmpeg | grep -q "x86-64" || { echo "Not x86-64"; exit 1; }
elif [[ "$PLATFORM" == *"arm64"* ]]; then
  file $ARTIFACTS/bin/ffmpeg | grep -q "arm64" || { echo "Not arm64"; exit 1; }
fi

# 6. Verify static linking (NEW)
echo "Checking static linking..."
if [[ "$PLATFORM" != *"glibc"* ]]; then
  ldd $ARTIFACTS/bin/ffmpeg 2>&1 | grep -q "not a dynamic" || { echo "Not statically linked"; exit 1; }
fi

# 7. Check pkg-config removal (existing)
if [ -d "$ARTIFACTS/lib/pkgconfig" ]; then
  echo "ERROR: pkgconfig files should be removed"
  exit 1
fi

echo "✅ All verification checks passed for $PLATFORM"
```

---

## Phase 5: Quality & Automation

**Goal:** Add testing, security, automation
**Duration:** 1-2 weeks
**Official Guides:** Generic (testing recommendations)

### 5.1 Functional Testing

**Test Structure:**
```
tests/
├── fixtures/
│   ├── input.mp4          # 5 sec, 1280x720, H.264
│   ├── input.wav          # 5 sec, 48kHz, 16-bit
│   └── checksums.txt      # SHA256 of expected outputs
├── encode-tests.sh        # Encoding tests
├── decode-tests.sh        # Decoding tests
├── performance-tests.sh   # Benchmarks
└── README.md              # Test documentation
```

**Encoding Tests (`tests/encode-tests.sh`):**
```bash
#!/bin/bash
set -e

FFMPEG="${1:-ffmpeg}"
FIXTURES="tests/fixtures"
OUTPUT="tests/output"
mkdir -p "$OUTPUT"

echo "Running encoding tests..."

# Test H.264 encoding
echo "  Testing H.264..."
$FFMPEG -y -i $FIXTURES/input.mp4 -c:v libx264 -preset fast \
  -c:a copy $OUTPUT/h264.mp4 2>&1 | grep -q "frame=" || exit 1

# Test H.265 encoding
echo "  Testing H.265..."
$FFMPEG -y -i $FIXTURES/input.mp4 -c:v libx265 -preset fast \
  -c:a copy $OUTPUT/h265.mp4 2>&1 | grep -q "frame=" || exit 1

# Test VP9 encoding
echo "  Testing VP9..."
$FFMPEG -y -i $FIXTURES/input.mp4 -c:v libvpx-vp9 -b:v 1M \
  -c:a libopus $OUTPUT/vp9.webm 2>&1 | grep -q "frame=" || exit 1

# Test AV1 encoding
echo "  Testing AV1..."
$FFMPEG -y -i $FIXTURES/input.mp4 -c:v libaom-av1 -cpu-used 8 -crf 30 \
  -c:a libopus $OUTPUT/av1.webm 2>&1 | grep -q "frame=" || exit 1

# Test Opus audio
echo "  Testing Opus..."
$FFMPEG -y -i $FIXTURES/input.wav -c:a libopus -b:a 128k \
  $OUTPUT/opus.ogg 2>&1 | grep -q "size=" || exit 1

# Test MP3 audio
echo "  Testing MP3..."
$FFMPEG -y -i $FIXTURES/input.wav -c:a libmp3lame -b:a 192k \
  $OUTPUT/mp3.mp3 2>&1 | grep -q "size=" || exit 1

# Verify outputs exist and have data
for file in $OUTPUT/*; do
  [ -s "$file" ] || { echo "ERROR: $file is empty"; exit 1; }
  echo "  ✅ $(basename $file)"
done

echo "✅ All encoding tests passed!"
```

**Decoding Tests (`tests/decode-tests.sh`):**
```bash
#!/bin/bash
set -e

FFMPEG="${1:-ffmpeg}"
OUTPUT="tests/output"

echo "Running decoding tests..."

# Test decoding each format
for file in $OUTPUT/*.{mp4,webm,ogg,mp3}; do
  [ -f "$file" ] || continue
  echo "  Testing decode: $(basename $file)"
  $FFMPEG -i "$file" -f null - 2>&1 | grep -q "frame=" || {
    echo "ERROR: Failed to decode $file"
    exit 1
  }
  echo "  ✅ $(basename $file)"
done

echo "✅ All decoding tests passed!"
```

**Performance Tests (`tests/performance-tests.sh`):**
```bash
#!/bin/bash
set -e

FFMPEG="${1:-ffmpeg}"
FIXTURES="tests/fixtures"
PLATFORM="${2:-unknown}"

echo "Running performance benchmarks..."

# Benchmark H.264 encoding
echo "  Benchmarking H.264..."
$FFMPEG -y -i $FIXTURES/input.mp4 -c:v libx264 -preset medium \
  -f null - 2>&1 | tee /tmp/bench-h264.log

FPS=$(grep "fps=" /tmp/bench-h264.log | tail -1 | \
  sed 's/.*fps=\s*\([0-9.]*\).*/\1/')

echo "  H.264 FPS: $FPS"
echo "$PLATFORM,h264,$FPS,$(date +%s)" >> benchmarks.csv

# Track binary size
SIZE=$(du -h $(which $FFMPEG) | cut -f1)
echo "  Binary size: $SIZE"
echo "$PLATFORM,binary_size,$SIZE,$(date +%s)" >> benchmarks.csv

echo "✅ Performance tests complete!"
```

**CI Integration:**
```yaml
- name: Run Functional Tests
  run: |
    ./tests/encode-tests.sh ./artifacts/${{ matrix.platform }}/bin/ffmpeg
    ./tests/decode-tests.sh ./artifacts/${{ matrix.platform }}/bin/ffmpeg
    ./tests/performance-tests.sh ./artifacts/${{ matrix.platform }}/bin/ffmpeg ${{ matrix.platform }}

- name: Upload Test Results
  if: always()
  uses: actions/upload-artifact@v4
  with:
    name: test-results-${{ matrix.platform }}
    path: tests/output/
```

### 5.2 Security Scanning

**Trivy Workflow (`.github/workflows/security.yml`):**
```yaml
name: Security Scan

on:
  push:
    branches: [main]
  pull_request:
  schedule:
    - cron: '0 0 * * 0'  # Weekly on Sunday

jobs:
  trivy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Download Artifacts
        uses: actions/download-artifact@v4
        with:
          pattern: artifacts-*

      - name: Run Trivy Scan
        uses: aquasecurity/trivy-action@master
        with:
          scan-type: 'fs'
          scan-ref: 'artifacts/'
          format: 'sarif'
          output: 'trivy-results.sarif'
          severity: 'CRITICAL,HIGH'

      - name: Upload to GitHub Security
        uses: github/codeql-action/upload-sarif@v3
        if: always()
        with:
          sarif_file: 'trivy-results.sarif'

  cve-check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Check FFmpeg CVEs
        run: |
          FFMPEG_VER=$(grep FFMPEG_VERSION versions.properties | cut -d= -f2)
          echo "Checking FFmpeg $FFMPEG_VER for known CVEs..."

          # Query NVD database (example)
          curl -s "https://services.nvd.nist.gov/rest/json/cves/2.0?keyword=ffmpeg" | \
            jq -r '.vulnerabilities[] | select(.cve.published > "2024-01-01") |
                   .cve.id + ": " + .cve.descriptions[0].value' || true
```

### 5.3 Dependency Update Automation

**Update Checker (`.github/workflows/check-updates.yml`):**
```yaml
name: Check Dependency Updates

on:
  schedule:
    - cron: '0 0 * * 1'  # Monday mornings
  workflow_dispatch:

jobs:
  check-ffmpeg:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Check FFmpeg Updates
        id: check_ffmpeg
        run: |
          CURRENT=$(grep FFMPEG_VERSION versions.properties | cut -d= -f2)
          LATEST=$(git ls-remote --tags https://git.ffmpeg.org/ffmpeg.git | \
                   grep -o 'n[0-9.]*$' | sort -V | tail -1)

          echo "current=$CURRENT" >> $GITHUB_OUTPUT
          echo "latest=$LATEST" >> $GITHUB_OUTPUT

          if [ "$CURRENT" != "$LATEST" ]; then
            echo "update_available=true" >> $GITHUB_OUTPUT
          fi

      - name: Update versions.properties
        if: steps.check_ffmpeg.outputs.update_available == 'true'
        run: |
          sed -i "s/FFMPEG_VERSION=.*/FFMPEG_VERSION=${{ steps.check_ffmpeg.outputs.latest }}/" \
            versions.properties

      - name: Create Pull Request
        if: steps.check_ffmpeg.outputs.update_available == 'true'
        uses: peter-evans/create-pull-request@v6
        with:
          commit-message: "chore: Update FFmpeg to ${{ steps.check_ffmpeg.outputs.latest }}"
          title: "chore: Update FFmpeg to ${{ steps.check_ffmpeg.outputs.latest }}"
          body: |
            Automated dependency update

            - **Current:** ${{ steps.check_ffmpeg.outputs.current }}
            - **Latest:** ${{ steps.check_ffmpeg.outputs.latest }}

            ## Changelog
            https://git.ffmpeg.org/gitweb/ffmpeg.git/shortlog/refs/tags/${{ steps.check_ffmpeg.outputs.latest }}

            ## Checklist
            - [ ] Review changelog for breaking changes
            - [ ] Test build on all platforms
            - [ ] Run functional tests
            - [ ] Update documentation if needed
          branch: update-ffmpeg-${{ steps.check_ffmpeg.outputs.latest }}
          delete-branch: true
```

**Dependabot Config (`.github/dependabot.yml`):**
```yaml
version: 2
updates:
  - package-ecosystem: "npm"
    directory: "/"
    schedule:
      interval: "weekly"
    open-pull-requests-limit: 10
```

### 5.4 Documentation Updates

**PERFORMANCE.md:**
```markdown
# Performance Guide

## Hardware Acceleration

### macOS VideoToolbox
- **Speed:** 10-20x faster than software
- **Codecs:** H.264, H.265
- **Usage:** `-c:v h264_videotoolbox` or `-c:v hevc_videotoolbox`

### Linux VA-API (Intel/AMD)
- **Speed:** 5-15x faster
- **Codecs:** H.264, H.265, VP8, VP9
- **Usage:** `-hwaccel vaapi -c:v h264_vaapi`

### Linux NVENC (NVIDIA)
- **Speed:** 15-30x faster
- **Codecs:** H.264, H.265
- **Usage:** `-c:v h264_nvenc` or `-c:v hevc_nvenc`

## Build Optimizations

### ccache
- First build: 20-30 min
- Incremental: 2-5 min (90% faster)
- Setup: `brew install ccache` (macOS) or `apt install ccache` (Linux)

### Parallel Builds
- All codecs in parallel: ~20 min
- Sequential: ~35 min

## Binary Sizes

| Platform | Size | Codecs |
|----------|------|--------|
| linux-x64-glibc | ~12 MB | Full (15 codecs) |
| darwin-universal | ~15 MB | Full (15 codecs) |
| windows-x64 | ~13 MB | Full (15 codecs) |
| *-minimal | ~6 MB | Basic (4 codecs) |
```

### 5.5 Progress Tracking

**progress.txt** (Updated continuously):
```
FFmpeg Prebuilds Modernization Progress
========================================
Last Updated: 2026-01-04

Phase 1: Platform Expansion [COMPLETED]
  ✅ Windows x64 support (MinGW cross-compile)
  ✅ macOS universal binaries (lipo)
  ✅ CI/CD integration
  ✅ npm package publishing

Phase 2: Codec Library Expansion [IN PROGRESS]
  ✅ SVT-AV1 (v2.3.0)
  ✅ rav1e (v0.7.1)
  ⏳ Theora (v1.1.1)
  ⬜ Xvid (1.3.7)
  ⬜ fdk-aac (v2.0.3)
  ⬜ FLAC (1.4.3)
  ⬜ Speex (1.2.1)
  ⬜ libass (0.17.3)
  ⬜ libfreetype (2.13.3)

Phase 3: Hardware Acceleration [PENDING]
  ⬜ Linux VA-API
  ⬜ Linux VDPAU
  ⬜ Linux NVENC
  ⬜ macOS VideoToolbox
  ⬜ Windows DXVA2

Phase 4: Build System Enhancements [PENDING]
  ⬜ Build customization (build-config.json)
  ⬜ Incremental builds (ccache)
  ⬜ ARM64 Linux (glibc)
  ⬜ ARM64 Linux (musl)
  ⬜ ARMv7 Linux (glibc)

Phase 5: Quality & Automation [PENDING]
  ⬜ Functional testing suite
  ⬜ Performance benchmarks
  ⬜ Security scanning (Trivy)
  ⬜ Dependency automation
  ⬜ Documentation (CODECS.md, PERFORMANCE.md)

Legend:
  ✅ Completed
  ⏳ In Progress
  ⬜ Todo

Statistics:
  - Total Tasks: 35
  - Completed: 4
  - In Progress: 2
  - Remaining: 29
  - Progress: 11%
```

---

## Implementation Strategy

### Execution Order

1. **Phase 1** → Foundation (Windows + Universal macOS)
2. **Phase 2** → Codecs (expand library)
3. **Phase 3** → HW Acceleration (performance)
4. **Phase 4** → Build System (flexibility)
5. **Phase 5** → Quality (testing + automation)

### Progress Tracking

- Update `progress.txt` after each task completion
- Commit progress updates with task commits
- Use TodoWrite for sub-task tracking

### Testing Strategy

- Each phase ends with comprehensive testing
- Functional tests added in Phase 5, but manual testing throughout
- No phase proceeds until previous phase is validated

### Rollout Strategy

- Each phase creates new packages (non-breaking)
- Deprecate old packages gradually
- Maintain backward compatibility

---

## Official Guide Compliance

This design strictly follows:

1. **Generic Guide:** Build process, environment variables, pkg-config isolation
2. **vcpkg Guide:** Feature-based configuration approach
3. **Ubuntu Guide:** Codec library compilation steps, dependencies
4. **CentOS Guide:** NASM version requirements, enterprise considerations
5. **macOS Guide:** Homebrew integration, universal binaries
6. **Windows Cross-Compilation Guide:** MinGW-w64 toolchain, configure flags

All configure flags, build steps, and optimization recommendations are taken directly from official documentation.

---

## Success Criteria

### Phase 1
- [ ] Windows builds work on Windows 10+
- [ ] Universal macOS binaries run on both Intel and Apple Silicon
- [ ] All existing tests pass

### Phase 2
- [ ] 9 new codecs build successfully
- [ ] CODECS.md documents all licenses
- [ ] Build variants (GPL, LGPL) work correctly

### Phase 3
- [ ] HW acceleration variants 5-20x faster than software
- [ ] Runtime detection recommends correct package
- [ ] HW accel failures gracefully fall back to software

### Phase 4
- [ ] build-config.json customization works
- [ ] ccache reduces rebuild time by 80%+
- [ ] ARM Linux builds cross-compile successfully

### Phase 5
- [ ] Functional tests catch regressions
- [ ] Security scans run weekly
- [ ] Dependency updates automated
- [ ] Documentation complete and accurate

---

## Risks & Mitigation

| Risk | Impact | Mitigation |
|------|--------|------------|
| Codec licensing issues | High | Clear documentation in CODECS.md |
| HW accel driver dependencies | Medium | Separate variants, runtime detection |
| Binary size bloat | Medium | Provide minimal preset |
| Build time increase | Low | Implement ccache, parallel builds |
| ARM cross-compile issues | Medium | Use official toolchains, test thoroughly |
| Breaking changes | High | Maintain backward compatibility |

---

## Next Steps

After design approval:
1. Create detailed implementation plan with `/dev-workflow:write-plan`
2. Execute Phase 1 using plan
3. Validate Phase 1 before proceeding
4. Continue through phases sequentially
