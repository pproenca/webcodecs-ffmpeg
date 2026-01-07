# Linux Platform Support Implementation Plan

## Overview

Extend the FFmpeg prebuilds system to support 8 Linux platforms matching sharp-libvips:

| Platform | Architecture | C Library | Build Strategy |
|----------|-------------|-----------|----------------|
| linux-x64 | x86_64 | glibc 2.26 | Native (Docker) |
| linux-arm64v8 | aarch64 | glibc 2.26 | QEMU userspace |
| linuxmusl-x64 | x86_64 | musl | Native (Docker) |
| linuxmusl-arm64v8 | aarch64 | musl | QEMU userspace |
| linux-armv6 | armv6 | glibc 2.26 | QEMU userspace |
| linux-ppc64le | ppc64le | glibc 2.26 | QEMU userspace |
| linux-riscv64 | riscv64 | glibc 2.26 | QEMU userspace |
| linux-s390x | s390x | glibc 2.26 | QEMU userspace |

**Total new CI jobs:** 24 (8 platforms x 3 license tiers)
**Total CI jobs after:** 30 (24 Linux + 6 macOS)

## Architecture Decision

**Approach:** Minimal Changes (Copy & Adapt Pattern)

Following the existing darwin-arm64/darwin-x64 pattern where each platform has its own complete set of files. This:
- Matches existing codebase conventions
- Minimizes risk to working Darwin builds
- Keeps platforms self-contained for easier debugging
- Allows platform-specific tweaks without affecting others

## Directory Structure

```
platforms/
├── darwin-arm64/          # Existing (unchanged)
├── darwin-x64/            # Existing (unchanged)
├── linux-x64/             # NEW
│   ├── Dockerfile
│   ├── Makefile
│   ├── build.sh
│   ├── config.mk
│   └── codecs/
│       ├── codec.mk
│       ├── bsd/{libvpx,aom,dav1d,svt-av1,opus,ogg,vorbis}.mk
│       ├── lgpl/lame.mk
│       └── gpl/{x264,x265}.mk
├── linux-arm64v8/         # NEW (same structure)
├── linuxmusl-x64/         # NEW (same structure)
├── linuxmusl-arm64v8/     # NEW (same structure)
├── linux-armv6/           # NEW (same structure)
├── linux-ppc64le/         # NEW (same structure)
├── linux-riscv64/         # NEW (same structure)
└── linux-s390x/           # NEW (same structure)
```

---

## Phase 1: Linux x64 Foundation

**Goal:** Prove Docker-based build approach with single glibc platform

### Task 1.1: Create linux-x64 Platform Directory

**Files to create:**

#### 1.1.1: `platforms/linux-x64/Dockerfile`

```dockerfile
FROM amazonlinux:2

LABEL maintainer="Pedro Proenca"
LABEL description="FFmpeg build environment for linux-x64 (glibc)"

# Install build dependencies
RUN yum update -y && \
    yum install -y \
        gcc \
        gcc-c++ \
        make \
        autoconf \
        automake \
        libtool \
        pkgconfig \
        git \
        curl \
        tar \
        xz \
        bzip2 \
        diffutils \
        perl \
        which \
    && yum clean all

# Install NASM (required for x264/x265 assembly)
ARG NASM_VERSION=2.16.03
RUN curl -fSL "https://www.nasm.us/pub/nasm/releasebuilds/${NASM_VERSION}/nasm-${NASM_VERSION}.tar.gz" -o nasm.tar.gz && \
    tar xzf nasm.tar.gz && \
    cd nasm-${NASM_VERSION} && \
    ./configure --prefix=/usr/local && \
    make -j$(nproc) && \
    make install && \
    cd .. && rm -rf nasm* && \
    nasm --version

# Install CMake 3.x (CMake 4.x breaks x265/aom/svt-av1)
ARG CMAKE_VERSION=3.30.5
RUN curl -fSL "https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/cmake-${CMAKE_VERSION}-linux-x86_64.tar.gz" -o cmake.tar.gz && \
    tar xzf cmake.tar.gz -C /usr/local --strip-components=1 && \
    rm cmake.tar.gz && \
    cmake --version

# Install Meson and Ninja (required for dav1d)
RUN curl -fSL "https://bootstrap.pypa.io/pip/3.6/get-pip.py" -o get-pip.py && \
    python3 get-pip.py && \
    rm get-pip.py && \
    pip3 install --no-cache-dir meson ninja && \
    meson --version && ninja --version

WORKDIR /build

# Default command (overridden by build.sh)
CMD ["bash"]
```

#### 1.1.2: `platforms/linux-x64/Makefile`

Copy from `platforms/darwin-arm64/Makefile` with these modifications:

```makefile
# Line 23: Update platform
PLATFORM := linux-x64

# Lines 95-110: Remove macOS hardware acceleration
FFMPEG_BASE_OPTS := \
    --prefix=$(PREFIX) \
    --arch=x86_64 \
    --enable-version3 \
    --enable-static \
    --disable-shared \
    --enable-pic \
    --enable-pthreads \
    --disable-debug \
    --disable-doc \
    --disable-htmlpages \
    --disable-manpages \
    --disable-podpages \
    --disable-txtpages
# NOTE: Removed --enable-videotoolbox --enable-audiotoolbox (macOS only)

# Lines 182-205: Update verification for Linux
verify: package
    $(call log_info,Verifying build...)
    @echo "=== FFmpeg Version ==="
    @$(ARTIFACTS_DIR)/bin/ffmpeg -version
    @echo ""
    @echo "=== Build Configuration ==="
    @$(ARTIFACTS_DIR)/bin/ffmpeg -buildconf 2>&1 | grep -E "(enable|configuration)" | head -20
    @echo ""
    @echo "=== Enabled Encoders (sample) ==="
    @$(ARTIFACTS_DIR)/bin/ffmpeg -encoders 2>&1 | grep -E "(libx264|libx265|libvpx|libaom|libsvtav1|libopus)" || true
    @echo ""
    @echo "=== Binary Architecture ==="
    @file $(ARTIFACTS_DIR)/bin/ffmpeg
    @file $(ARTIFACTS_DIR)/bin/ffmpeg | grep -q "x86-64" && echo "OK: x86-64 verified" || (echo "ERROR: Not x86-64!" && exit 1)
    @echo ""
    @echo "=== Dynamic Library Dependencies ==="
    @ldd $(ARTIFACTS_DIR)/bin/ffmpeg || true
    @# Verify minimal dynamic libs (only libc, libm, libpthread, libdl expected)
    @if ldd $(ARTIFACTS_DIR)/bin/ffmpeg 2>/dev/null | grep -vE "(linux-vdso|ld-linux|libc\.so|libm\.so|libpthread|libdl)" | grep "=>" | grep -v "not found"; then \
        echo "WARNING: Unexpected dynamic libraries found"; \
    else \
        echo "OK: Static linkage verified"; \
    fi
    $(call log_info,Verification passed)
```

#### 1.1.3: `platforms/linux-x64/config.mk`

```makefile
# =============================================================================
# Linux x86_64 Platform Configuration (glibc - Amazon Linux 2)
# =============================================================================

# Platform identification
PLATFORM := linux-x64
ARCH := x86_64
TARGET_OS := linux

# =============================================================================
# Compiler Settings
# =============================================================================

CC := gcc
CXX := g++
AR := ar
RANLIB := ranlib

# =============================================================================
# Architecture Flags
# =============================================================================

ARCH_FLAGS := -m64

# Base compiler flags
# -static-libgcc -static-libstdc++ ensures no dependency on specific GCC runtime
COMMON_FLAGS := $(ARCH_FLAGS) -O3 -fPIC
CFLAGS := $(COMMON_FLAGS)
CXXFLAGS := $(COMMON_FLAGS)

# Suppress deprecated warnings unless DEBUG=1
ifndef DEBUG
    CFLAGS += -Wno-deprecated-declarations
    CXXFLAGS += -Wno-deprecated-declarations
endif

LDFLAGS := $(ARCH_FLAGS)

# =============================================================================
# Build Tool Configuration
# =============================================================================

# pkg-config setup
PKG_CONFIG := pkg-config
PKG_CONFIG_LIBDIR := $(PREFIX)/lib/pkgconfig

# CMake configuration for cmake-based codecs (x265, aom, svt-av1)
CMAKE_OPTS := \
    -DCMAKE_SYSTEM_NAME=Linux \
    -DCMAKE_SYSTEM_PROCESSOR=x86_64 \
    -DCMAKE_INSTALL_PREFIX=$(PREFIX) \
    -DCMAKE_PREFIX_PATH=$(PREFIX) \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_C_COMPILER=$(CC) \
    -DCMAKE_CXX_COMPILER=$(CXX) \
    $(if $(DEBUG),,-Wno-dev)

# Meson configuration for meson-based codecs (dav1d)
MESON_OPTS := \
    --prefix=$(PREFIX) \
    --libdir=lib \
    --buildtype=release \
    --default-library=static

# =============================================================================
# ccache Integration (if available)
# =============================================================================

CCACHE := $(shell command -v ccache 2>/dev/null)
ifdef CCACHE
    CC := $(CCACHE) $(CC)
    CXX := $(CCACHE) $(CXX)
    CMAKE_OPTS += -DCMAKE_C_COMPILER_LAUNCHER=ccache -DCMAKE_CXX_COMPILER_LAUNCHER=ccache
endif

# =============================================================================
# Export Variables
# =============================================================================

export CC CXX AR RANLIB
export CFLAGS CXXFLAGS LDFLAGS
export PKG_CONFIG PKG_CONFIG_LIBDIR
```

#### 1.1.4: `platforms/linux-x64/build.sh`

```bash
#!/usr/bin/env bash
#
# build.sh - Build FFmpeg for linux-x64 using Docker
#
# Usage:
#   ./build.sh [target]        - Run in Docker container
#   ./build.sh all             - Full build (codecs + FFmpeg + package)
#   LICENSE=bsd ./build.sh all - Build BSD tier only
#
# Environment:
#   LICENSE - License tier: bsd, lgpl, gpl (default: gpl)
#   DEBUG   - Enable debug output: 1 (default: empty)

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
readonly PLATFORM="linux-x64"

# -----------------------------------------------------------------------------
# Logging
# -----------------------------------------------------------------------------

log_info() {
  printf "\033[0;32m[INFO]\033[0m %s\n" "$*"
}

log_error() {
  printf "\033[0;31m[ERROR]\033[0m %s\n" "$*" >&2
}

# -----------------------------------------------------------------------------
# Docker Detection
# -----------------------------------------------------------------------------

in_docker() {
  [[ -f /.dockerenv ]] || grep -q docker /proc/1/cgroup 2>/dev/null
}

# -----------------------------------------------------------------------------
# Build Functions
# -----------------------------------------------------------------------------

build_in_docker() {
  local target="${1:-all}"
  local license="${LICENSE:-gpl}"
  local debug="${DEBUG:-}"

  log_info "Building ${PLATFORM} (${license} tier) in Docker..."

  # Build Docker image
  log_info "Building Docker image..."
  docker build \
    -t "ffmpeg-builder:${PLATFORM}" \
    -f "${SCRIPT_DIR}/Dockerfile" \
    "${PROJECT_ROOT}"

  # Run build in container
  log_info "Running build in container..."
  docker run --rm \
    -v "${PROJECT_ROOT}/artifacts:/build/artifacts" \
    -v "${PROJECT_ROOT}/build:/build/build" \
    -e "LICENSE=${license}" \
    -e "DEBUG=${debug}" \
    -w "/build/platforms/${PLATFORM}" \
    "ffmpeg-builder:${PLATFORM}" \
    make -j"$(nproc)" LICENSE="${license}" DEBUG="${debug}" "${target}"

  log_info "Build complete: ${PROJECT_ROOT}/artifacts/${PLATFORM}-${license}/"
}

build_native() {
  local target="${1:-all}"
  local license="${LICENSE:-gpl}"
  local debug="${DEBUG:-}"

  log_info "Building ${PLATFORM} (${license} tier) natively..."

  cd "${SCRIPT_DIR}"
  make -j"$(nproc)" LICENSE="${license}" DEBUG="${debug}" "${target}"

  log_info "Build complete: ${PROJECT_ROOT}/artifacts/${PLATFORM}-${license}/"
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------

main() {
  local target="${1:-all}"

  if in_docker; then
    # Running inside Docker container - build directly
    build_native "${target}"
  else
    # Running on host - use Docker
    build_in_docker "${target}"
  fi
}

main "$@"
```

#### 1.1.5: Copy codec recipes from darwin-arm64

Copy the entire `codecs/` directory from darwin-arm64:

```bash
cp -r platforms/darwin-arm64/codecs platforms/linux-x64/
```

**Files copied:**
- `codecs/codec.mk` (license tier logic - unchanged)
- `codecs/bsd/libvpx.mk`
- `codecs/bsd/aom.mk`
- `codecs/bsd/dav1d.mk`
- `codecs/bsd/svt-av1.mk`
- `codecs/bsd/opus.mk`
- `codecs/bsd/ogg.mk`
- `codecs/bsd/vorbis.mk`
- `codecs/lgpl/lame.mk`
- `codecs/gpl/x264.mk`
- `codecs/gpl/x265.mk`

**Required modifications to codec recipes:**

1. **libvpx.mk** - Change target from `arm64-darwin23-gcc` to `x86_64-linux-gcc`:
   ```makefile
   # Line with --target=
   --target=x86_64-linux-gcc \
   ```

2. **vorbis.mk** - Remove macOS-specific PowerPC flag patch (not needed on Linux):
   ```makefile
   # Remove the sed command that patches -force_cpusubtype_ALL
   # This flag doesn't exist on Linux
   ```

---

### Task 1.2: Test linux-x64 Build Locally

**Test commands:**
```bash
cd platforms/linux-x64

# Build BSD tier (fastest, fewest codecs)
LICENSE=bsd ./build.sh all

# Verify artifact
file ../../artifacts/linux-x64-bsd/bin/ffmpeg
# Expected: ELF 64-bit LSB executable, x86-64

../../artifacts/linux-x64-bsd/bin/ffmpeg -version
# Expected: ffmpeg version n7.1

# Check dynamic dependencies
ldd ../../artifacts/linux-x64-bsd/bin/ffmpeg
# Expected: Only libc, libm, libpthread, libdl

# Test LGPL tier
LICENSE=lgpl ./build.sh all

# Test GPL tier
LICENSE=gpl ./build.sh all
```

---

## Phase 2: ARM64 glibc Platform (QEMU)

**Goal:** Add linux-arm64v8 with QEMU userspace emulation

### Task 2.1: Create linux-arm64v8 Platform Directory

Copy linux-x64 and modify for ARM64:

```bash
cp -r platforms/linux-x64 platforms/linux-arm64v8
```

**Modifications:**

#### 2.1.1: `platforms/linux-arm64v8/Dockerfile`

```dockerfile
FROM arm64v8/amazonlinux:2

LABEL maintainer="Pedro Proenca"
LABEL description="FFmpeg build environment for linux-arm64v8 (glibc)"

# Same package installation as linux-x64...
RUN yum update -y && \
    yum install -y \
        gcc gcc-c++ make autoconf automake libtool pkgconfig \
        git curl tar xz bzip2 diffutils perl which \
    && yum clean all

# NASM not available for ARM64 - x264/x265 will use C fallbacks
# (ARM64 has NEON optimizations built-in)

# Install CMake 3.x (ARM64 binary)
ARG CMAKE_VERSION=3.30.5
RUN curl -fSL "https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/cmake-${CMAKE_VERSION}-linux-aarch64.tar.gz" -o cmake.tar.gz && \
    tar xzf cmake.tar.gz -C /usr/local --strip-components=1 && \
    rm cmake.tar.gz && \
    cmake --version

# Install Meson and Ninja
RUN curl -fSL "https://bootstrap.pypa.io/pip/3.6/get-pip.py" -o get-pip.py && \
    python3 get-pip.py && \
    rm get-pip.py && \
    pip3 install --no-cache-dir meson ninja

WORKDIR /build
CMD ["bash"]
```

#### 2.1.2: `platforms/linux-arm64v8/config.mk`

```makefile
# Platform identification
PLATFORM := linux-arm64v8
ARCH := aarch64
TARGET_OS := linux

CC := gcc
CXX := g++
AR := ar
RANLIB := ranlib

# ARM64 flags
ARCH_FLAGS := -march=armv8-a
COMMON_FLAGS := $(ARCH_FLAGS) -O3 -fPIC
CFLAGS := $(COMMON_FLAGS)
CXXFLAGS := $(COMMON_FLAGS)

ifndef DEBUG
    CFLAGS += -Wno-deprecated-declarations
    CXXFLAGS += -Wno-deprecated-declarations
endif

LDFLAGS := $(ARCH_FLAGS)

# pkg-config
PKG_CONFIG := pkg-config
PKG_CONFIG_LIBDIR := $(PREFIX)/lib/pkgconfig

# CMake options
CMAKE_OPTS := \
    -DCMAKE_SYSTEM_NAME=Linux \
    -DCMAKE_SYSTEM_PROCESSOR=aarch64 \
    -DCMAKE_INSTALL_PREFIX=$(PREFIX) \
    -DCMAKE_PREFIX_PATH=$(PREFIX) \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_C_COMPILER=$(CC) \
    -DCMAKE_CXX_COMPILER=$(CXX) \
    $(if $(DEBUG),,-Wno-dev)

# Meson options
MESON_OPTS := \
    --prefix=$(PREFIX) \
    --libdir=lib \
    --buildtype=release \
    --default-library=static

# ccache
CCACHE := $(shell command -v ccache 2>/dev/null)
ifdef CCACHE
    CC := $(CCACHE) $(CC)
    CXX := $(CCACHE) $(CXX)
    CMAKE_OPTS += -DCMAKE_C_COMPILER_LAUNCHER=ccache -DCMAKE_CXX_COMPILER_LAUNCHER=ccache
endif

export CC CXX AR RANLIB CFLAGS CXXFLAGS LDFLAGS PKG_CONFIG PKG_CONFIG_LIBDIR
```

#### 2.1.3: `platforms/linux-arm64v8/Makefile`

Update platform and architecture verification:

```makefile
PLATFORM := linux-arm64v8

# In verify target:
@file $(ARTIFACTS_DIR)/bin/ffmpeg | grep -q "aarch64" && echo "OK: aarch64 verified" || (echo "ERROR: Not aarch64!" && exit 1)
```

#### 2.1.4: Codec modifications for ARM64

**libvpx.mk:**
```makefile
--target=arm64-linux-gcc \
```

**x264.mk, x265.mk:** No assembly flag needed - ARM64 has NEON by default.

---

## Phase 3: musl/Alpine Platforms

**Goal:** Add linuxmusl-x64 and linuxmusl-arm64v8

### Task 3.1: Create linuxmusl-x64 Platform

Copy linux-x64 and modify for Alpine/musl:

#### 3.1.1: `platforms/linuxmusl-x64/Dockerfile`

```dockerfile
FROM alpine:3.15

LABEL maintainer="Pedro Proenca"
LABEL description="FFmpeg build environment for linuxmusl-x64 (musl)"

# Install build dependencies
RUN apk add --no-cache \
    gcc \
    g++ \
    make \
    cmake \
    nasm \
    autoconf \
    automake \
    libtool \
    pkgconfig \
    git \
    curl \
    tar \
    xz \
    bzip2 \
    diffutils \
    perl \
    bash \
    linux-headers \
    meson \
    ninja

WORKDIR /build
CMD ["bash"]
```

#### 3.1.2: `platforms/linuxmusl-x64/config.mk`

```makefile
# Platform identification
PLATFORM := linuxmusl-x64
ARCH := x86_64
TARGET_OS := linux

CC := gcc
CXX := g++
AR := ar
RANLIB := ranlib

# x86_64 musl flags
# Note: musl produces fully static binaries by default
ARCH_FLAGS := -m64
COMMON_FLAGS := $(ARCH_FLAGS) -O3 -fPIC
CFLAGS := $(COMMON_FLAGS)
CXXFLAGS := $(COMMON_FLAGS)

ifndef DEBUG
    CFLAGS += -Wno-deprecated-declarations
    CXXFLAGS += -Wno-deprecated-declarations
endif

LDFLAGS := $(ARCH_FLAGS) -static

# pkg-config
PKG_CONFIG := pkg-config
PKG_CONFIG_LIBDIR := $(PREFIX)/lib/pkgconfig

# CMake options
CMAKE_OPTS := \
    -DCMAKE_SYSTEM_NAME=Linux \
    -DCMAKE_SYSTEM_PROCESSOR=x86_64 \
    -DCMAKE_INSTALL_PREFIX=$(PREFIX) \
    -DCMAKE_PREFIX_PATH=$(PREFIX) \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_C_COMPILER=$(CC) \
    -DCMAKE_CXX_COMPILER=$(CXX) \
    -DCMAKE_EXE_LINKER_FLAGS="-static" \
    $(if $(DEBUG),,-Wno-dev)

# Meson options
MESON_OPTS := \
    --prefix=$(PREFIX) \
    --libdir=lib \
    --buildtype=release \
    --default-library=static

# ccache
CCACHE := $(shell command -v ccache 2>/dev/null)
ifdef CCACHE
    CC := $(CCACHE) $(CC)
    CXX := $(CCACHE) $(CXX)
endif

export CC CXX AR RANLIB CFLAGS CXXFLAGS LDFLAGS PKG_CONFIG PKG_CONFIG_LIBDIR
```

#### 3.1.3: Verification for musl

musl builds should produce fully static binaries:

```makefile
verify: package
    # ...
    @echo "=== Static Linking Verification ==="
    @if ldd $(ARTIFACTS_DIR)/bin/ffmpeg 2>&1 | grep -q "not a dynamic executable"; then \
        echo "OK: Fully static binary"; \
    else \
        echo "WARNING: Not fully static"; \
        ldd $(ARTIFACTS_DIR)/bin/ffmpeg || true; \
    fi
```

### Task 3.2: Create linuxmusl-arm64v8 Platform

Copy linuxmusl-x64 and modify:

```dockerfile
FROM arm64v8/alpine:3.15
```

```makefile
PLATFORM := linuxmusl-arm64v8
ARCH := aarch64
ARCH_FLAGS := -march=armv8-a
```

---

## Phase 4: Exotic Architectures

**Goal:** Add armv6, ppc64le, riscv64, s390x

### Task 4.1: linux-armv6 (Raspberry Pi Zero/1)

#### Dockerfile

```dockerfile
FROM arm32v6/alpine:3.15

LABEL maintainer="Pedro Proenca"
LABEL description="FFmpeg build environment for linux-armv6 (glibc)"

# Alpine doesn't have glibc for armv6, so use musl
# If glibc is required, need different base image

RUN apk add --no-cache \
    gcc g++ make cmake autoconf automake libtool pkgconfig \
    git curl tar xz bzip2 diffutils perl bash linux-headers \
    meson ninja

WORKDIR /build
CMD ["bash"]
```

**Note:** ARMv6 glibc builds would require a different approach (Debian armhf). For simplicity, using Alpine/musl. If glibc is strictly required, use `balenalib/raspberry-pi` base image.

#### config.mk

```makefile
PLATFORM := linux-armv6
ARCH := armv6
TARGET_OS := linux

CC := gcc
CXX := g++

ARCH_FLAGS := -march=armv6 -mfpu=vfp -mfloat-abi=hard
COMMON_FLAGS := $(ARCH_FLAGS) -O3 -fPIC
```

### Task 4.2: linux-ppc64le (IBM POWER)

```dockerfile
FROM ppc64le/amazonlinux:2
```

```makefile
PLATFORM := linux-ppc64le
ARCH := ppc64le
ARCH_FLAGS := -mcpu=power8 -mtune=power8
```

### Task 4.3: linux-riscv64 (RISC-V)

```dockerfile
FROM riscv64/alpine:edge
# Note: RISC-V support is still maturing, using Alpine edge
```

```makefile
PLATFORM := linux-riscv64
ARCH := riscv64
ARCH_FLAGS := -march=rv64gc -mabi=lp64d
```

### Task 4.4: linux-s390x (IBM Z)

```dockerfile
FROM s390x/amazonlinux:2
```

```makefile
PLATFORM := linux-s390x
ARCH := s390x
ARCH_FLAGS := -march=z13 -mtune=z13
```

---

## Phase 5: CI/CD Integration

**Goal:** Update GitHub Actions to build all Linux platforms

### Task 5.1: Update `_build.yml` Workflow

```yaml
name: Build (Reusable)

on:
  workflow_call:
    inputs:
      ref:
        description: 'Git ref to build'
        type: string
        default: ''
      retention-days:
        description: 'Artifact retention days'
        type: number
        default: 30

permissions:
  contents: read
  id-token: write
  attestations: write

jobs:
  build:
    name: build-${{ matrix.platform }}-${{ matrix.license }}
    runs-on: ${{ matrix.runner }}
    strategy:
      fail-fast: false
      matrix:
        include:
          # macOS platforms (native)
          - platform: darwin-arm64
            runner: macos-15
            license: bsd
          - platform: darwin-arm64
            runner: macos-15
            license: lgpl
          - platform: darwin-arm64
            runner: macos-15
            license: gpl
          - platform: darwin-x64
            runner: macos-15-intel
            license: bsd
          - platform: darwin-x64
            runner: macos-15-intel
            license: lgpl
          - platform: darwin-x64
            runner: macos-15-intel
            license: gpl

          # Linux glibc platforms (Docker + QEMU)
          - platform: linux-x64
            runner: ubuntu-24.04
            license: bsd
            docker: true
            qemu: false
          - platform: linux-x64
            runner: ubuntu-24.04
            license: lgpl
            docker: true
            qemu: false
          - platform: linux-x64
            runner: ubuntu-24.04
            license: gpl
            docker: true
            qemu: false
          - platform: linux-arm64v8
            runner: ubuntu-24.04
            license: bsd
            docker: true
            qemu: true
            qemu_platform: linux/arm64
          - platform: linux-arm64v8
            runner: ubuntu-24.04
            license: lgpl
            docker: true
            qemu: true
            qemu_platform: linux/arm64
          - platform: linux-arm64v8
            runner: ubuntu-24.04
            license: gpl
            docker: true
            qemu: true
            qemu_platform: linux/arm64

          # Linux musl platforms
          - platform: linuxmusl-x64
            runner: ubuntu-24.04
            license: bsd
            docker: true
            qemu: false
          - platform: linuxmusl-x64
            runner: ubuntu-24.04
            license: lgpl
            docker: true
            qemu: false
          - platform: linuxmusl-x64
            runner: ubuntu-24.04
            license: gpl
            docker: true
            qemu: false
          - platform: linuxmusl-arm64v8
            runner: ubuntu-24.04
            license: bsd
            docker: true
            qemu: true
            qemu_platform: linux/arm64
          - platform: linuxmusl-arm64v8
            runner: ubuntu-24.04
            license: lgpl
            docker: true
            qemu: true
            qemu_platform: linux/arm64
          - platform: linuxmusl-arm64v8
            runner: ubuntu-24.04
            license: gpl
            docker: true
            qemu: true
            qemu_platform: linux/arm64

          # Exotic architectures
          - platform: linux-armv6
            runner: ubuntu-24.04
            license: bsd
            docker: true
            qemu: true
            qemu_platform: linux/arm/v6
          - platform: linux-armv6
            runner: ubuntu-24.04
            license: lgpl
            docker: true
            qemu: true
            qemu_platform: linux/arm/v6
          - platform: linux-armv6
            runner: ubuntu-24.04
            license: gpl
            docker: true
            qemu: true
            qemu_platform: linux/arm/v6
          - platform: linux-ppc64le
            runner: ubuntu-24.04
            license: bsd
            docker: true
            qemu: true
            qemu_platform: linux/ppc64le
          - platform: linux-ppc64le
            runner: ubuntu-24.04
            license: lgpl
            docker: true
            qemu: true
            qemu_platform: linux/ppc64le
          - platform: linux-ppc64le
            runner: ubuntu-24.04
            license: gpl
            docker: true
            qemu: true
            qemu_platform: linux/ppc64le
          - platform: linux-riscv64
            runner: ubuntu-24.04
            license: bsd
            docker: true
            qemu: true
            qemu_platform: linux/riscv64
          - platform: linux-riscv64
            runner: ubuntu-24.04
            license: lgpl
            docker: true
            qemu: true
            qemu_platform: linux/riscv64
          - platform: linux-riscv64
            runner: ubuntu-24.04
            license: gpl
            docker: true
            qemu: true
            qemu_platform: linux/riscv64
          - platform: linux-s390x
            runner: ubuntu-24.04
            license: bsd
            docker: true
            qemu: true
            qemu_platform: linux/s390x
          - platform: linux-s390x
            runner: ubuntu-24.04
            license: lgpl
            docker: true
            qemu: true
            qemu_platform: linux/s390x
          - platform: linux-s390x
            runner: ubuntu-24.04
            license: gpl
            docker: true
            qemu: true
            qemu_platform: linux/s390x

    concurrency:
      group: build-${{ matrix.platform }}-${{ matrix.license }}-${{ inputs.ref || github.sha }}
      cancel-in-progress: true

    steps:
      - name: Checkout
        uses: actions/checkout@v4
        with:
          ref: ${{ inputs.ref || github.sha }}

      - name: Cache sources
        uses: actions/cache@v4
        with:
          path: build/${{ matrix.platform }}/sources
          key: sources-${{ matrix.platform }}-${{ hashFiles('shared/versions.mk') }}
          restore-keys: |
            sources-${{ matrix.platform }}-

      - name: Set up QEMU
        if: matrix.qemu == true
        uses: docker/setup-qemu-action@v3
        with:
          platforms: ${{ matrix.qemu_platform }}

      - name: Set up Docker Buildx
        if: matrix.docker == true
        uses: docker/setup-buildx-action@v3

      - name: Build FFmpeg (macOS)
        if: startsWith(matrix.platform, 'darwin')
        run: LICENSE=${{ matrix.license }} ./platforms/${{ matrix.platform }}/build.sh all
        env:
          DEBUG: ${{ runner.debug }}

      - name: Build FFmpeg (Linux/Docker)
        if: matrix.docker == true
        run: LICENSE=${{ matrix.license }} ./platforms/${{ matrix.platform }}/build.sh all
        env:
          DEBUG: ${{ runner.debug }}
        timeout-minutes: 120  # QEMU builds can be slow

      - name: Verify binary architecture
        run: |
          FFMPEG_BIN="artifacts/${{ matrix.platform }}-${{ matrix.license }}/bin/ffmpeg"

          if [[ ! -f "$FFMPEG_BIN" ]]; then
            echo "::error::Binary not found: $FFMPEG_BIN"
            exit 1
          fi

          echo "Binary info:"
          file "$FFMPEG_BIN"

          # Architecture verification based on platform
          case "${{ matrix.platform }}" in
            darwin-arm64) EXPECTED="arm64" ;;
            darwin-x64) EXPECTED="x86_64" ;;
            linux-x64|linuxmusl-x64) EXPECTED="x86-64" ;;
            linux-arm64v8|linuxmusl-arm64v8) EXPECTED="aarch64" ;;
            linux-armv6) EXPECTED="ARM" ;;
            linux-ppc64le) EXPECTED="64-bit.*PowerPC" ;;
            linux-riscv64) EXPECTED="RISC-V" ;;
            linux-s390x) EXPECTED="S/390" ;;
          esac

          if ! file "$FFMPEG_BIN" | grep -qE "$EXPECTED"; then
            echo "::error::Architecture mismatch! Expected $EXPECTED"
            exit 1
          fi

          echo "Architecture verified: $EXPECTED"

      - name: Create tarball and checksum
        run: |
          TARBALL="ffmpeg-${{ matrix.platform }}-${{ matrix.license }}.tar.gz"

          tar -czvf "$TARBALL" \
            -C artifacts "${{ matrix.platform }}-${{ matrix.license }}"

          # Verify tarball size
          if [[ "$(uname)" == "Darwin" ]]; then
            TARBALL_SIZE=$(stat -f%z "$TARBALL")
          else
            TARBALL_SIZE=$(stat -c%s "$TARBALL")
          fi

          if [[ "$TARBALL_SIZE" -lt 1000000 ]]; then
            echo "::error::Tarball suspiciously small: ${TARBALL_SIZE} bytes"
            exit 1
          fi
          echo "Created $TARBALL (${TARBALL_SIZE} bytes)"

          shasum -a 256 "$TARBALL" > "${TARBALL}.sha256"

      - name: Generate build attestation
        uses: actions/attest-build-provenance@v2
        with:
          subject-path: 'ffmpeg-${{ matrix.platform }}-${{ matrix.license }}.tar.gz'

      - name: Upload artifact
        uses: actions/upload-artifact@v4
        with:
          name: ffmpeg-${{ matrix.platform }}-${{ matrix.license }}
          path: |
            ffmpeg-${{ matrix.platform }}-${{ matrix.license }}.tar.gz
            ffmpeg-${{ matrix.platform }}-${{ matrix.license }}.tar.gz.sha256
          retention-days: ${{ inputs.retention-days }}
```

### Task 5.2: Update `populate-npm.sh`

Update PLATFORM_MAP and workspaces:

```bash
# Line 23-29: Extend PLATFORM_MAP
declare -Ar PLATFORM_MAP=(
  ["darwin-arm64"]="darwin-arm64"
  ["darwin-x64"]="darwin-x64"
  ["linux-x64"]="linux-x64"
  ["linux-arm64v8"]="linux-arm64v8"
  ["linuxmusl-x64"]="linuxmusl-x64"
  ["linuxmusl-arm64v8"]="linuxmusl-arm64v8"
  ["linux-armv6"]="linux-armv6"
  ["linux-ppc64le"]="linux-ppc64le"
  ["linux-riscv64"]="linux-riscv64"
  ["linux-s390x"]="linux-s390x"
)

# Line 648-664: Update workspaces
cat >"${NPM_DIR}/package.json" <<'EOF'
{
  "private": true,
  "workspaces": [
    "dev",
    "ffmpeg",
    "ffmpeg-lgpl",
    "ffmpeg-gpl",
    "darwin-arm64",
    "darwin-arm64-lgpl",
    "darwin-arm64-gpl",
    "darwin-x64",
    "darwin-x64-lgpl",
    "darwin-x64-gpl",
    "linux-x64",
    "linux-x64-lgpl",
    "linux-x64-gpl",
    "linux-arm64v8",
    "linux-arm64v8-lgpl",
    "linux-arm64v8-gpl",
    "linuxmusl-x64",
    "linuxmusl-x64-lgpl",
    "linuxmusl-x64-gpl",
    "linuxmusl-arm64v8",
    "linuxmusl-arm64v8-lgpl",
    "linuxmusl-arm64v8-gpl",
    "linux-armv6",
    "linux-armv6-lgpl",
    "linux-armv6-gpl",
    "linux-ppc64le",
    "linux-ppc64le-lgpl",
    "linux-ppc64le-gpl",
    "linux-riscv64",
    "linux-riscv64-lgpl",
    "linux-riscv64-gpl",
    "linux-s390x",
    "linux-s390x-lgpl",
    "linux-s390x-gpl"
  ]
}
EOF
```

---

## Phase 6: Documentation Updates

### Task 6.1: Update CLAUDE.md

Add Linux build commands section:

```markdown
### Linux Platforms

```bash
# Full build (uses Docker)
cd platforms/linux-x64
./build.sh all

# Specific license tier
LICENSE=bsd ./build.sh all
LICENSE=lgpl ./build.sh all
LICENSE=gpl ./build.sh all

# Available platforms:
# - linux-x64 (glibc x86_64)
# - linux-arm64v8 (glibc ARM64)
# - linuxmusl-x64 (musl x86_64)
# - linuxmusl-arm64v8 (musl ARM64)
# - linux-armv6 (ARMv6, Raspberry Pi)
# - linux-ppc64le (PowerPC 64 LE)
# - linux-riscv64 (RISC-V 64)
# - linux-s390x (IBM Z)
```
```

### Task 6.2: Update README.md

Add supported platforms table.

---

## Implementation Checklist

### Phase 1: linux-x64 Foundation
- [ ] Create `platforms/linux-x64/Dockerfile`
- [ ] Create `platforms/linux-x64/Makefile` (adapt from darwin-arm64)
- [ ] Create `platforms/linux-x64/config.mk`
- [ ] Create `platforms/linux-x64/build.sh`
- [ ] Copy and adapt `platforms/linux-x64/codecs/` from darwin-arm64
- [ ] Modify `codecs/bsd/libvpx.mk` for Linux target
- [ ] Remove macOS-specific patch from `codecs/bsd/vorbis.mk`
- [ ] Test local build: `LICENSE=bsd ./build.sh all`
- [ ] Test all license tiers locally

### Phase 2: linux-arm64v8
- [ ] Create `platforms/linux-arm64v8/` (copy from linux-x64)
- [ ] Update Dockerfile for ARM64 base image
- [ ] Update config.mk with ARM64 flags
- [ ] Update Makefile with ARM64 verification
- [ ] Update libvpx.mk for arm64-linux-gcc target
- [ ] Test with QEMU: `docker run --platform linux/arm64 ...`

### Phase 3: musl Platforms
- [ ] Create `platforms/linuxmusl-x64/Dockerfile` (Alpine)
- [ ] Create `platforms/linuxmusl-x64/config.mk` (static linking)
- [ ] Create `platforms/linuxmusl-x64/Makefile`
- [ ] Create `platforms/linuxmusl-x64/build.sh`
- [ ] Copy codecs from linux-x64
- [ ] Create `platforms/linuxmusl-arm64v8/` (copy from linuxmusl-x64)
- [ ] Update for ARM64

### Phase 4: Exotic Architectures
- [ ] Create `platforms/linux-armv6/`
- [ ] Create `platforms/linux-ppc64le/`
- [ ] Create `platforms/linux-riscv64/`
- [ ] Create `platforms/linux-s390x/`
- [ ] Test each platform with QEMU

### Phase 5: CI Integration
- [ ] Update `.github/workflows/_build.yml` with full matrix
- [ ] Add QEMU setup step
- [ ] Add Docker Buildx setup
- [ ] Test CI with single platform first
- [ ] Enable full matrix

### Phase 6: npm Integration
- [ ] Update `scripts/populate-npm.sh` PLATFORM_MAP
- [ ] Update workspace list
- [ ] Test npm package generation
- [ ] Verify os/cpu fields in generated package.json

### Phase 7: Documentation
- [ ] Update CLAUDE.md with Linux commands
- [ ] Update README.md with platform table
- [ ] Add troubleshooting section for QEMU issues

---

## Expected Build Times

| Platform | Native/QEMU | Estimated Time (GPL) |
|----------|-------------|---------------------|
| darwin-arm64 | Native | ~8 min |
| darwin-x64 | Native | ~10 min |
| linux-x64 | Native (Docker) | ~12 min |
| linux-arm64v8 | QEMU | ~35 min |
| linuxmusl-x64 | Native (Docker) | ~12 min |
| linuxmusl-arm64v8 | QEMU | ~35 min |
| linux-armv6 | QEMU | ~45 min |
| linux-ppc64le | QEMU | ~40 min |
| linux-riscv64 | QEMU | ~50 min |
| linux-s390x | QEMU | ~40 min |

**Total CI time:** ~5 hours (30 jobs, some parallel)

---

## Troubleshooting

### QEMU Build Hangs

If QEMU builds hang, reduce parallelism:
```makefile
# In config.mk for QEMU platforms
NPROC := 2  # Override to limit parallelism
```

### Codec Assembly Failures on Exotic Architectures

If assembly optimizations fail on exotic architectures, disable them:
```makefile
# In specific codec .mk files
--disable-asm
```

### musl Static Linking Issues

If musl builds have linking issues, ensure:
```makefile
LDFLAGS := -static
CMAKE_OPTS += -DCMAKE_EXE_LINKER_FLAGS="-static"
```

---

## Success Criteria

1. All 30 CI jobs (10 platforms x 3 tiers) pass
2. All binaries verified for correct architecture
3. glibc binaries have minimal dynamic deps (libc only)
4. musl binaries are fully static
5. FFmpeg version and encoders verified on all platforms
6. npm packages generated with correct os/cpu fields
7. Documentation updated
