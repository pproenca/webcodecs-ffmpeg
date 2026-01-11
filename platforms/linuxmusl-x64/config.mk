# =============================================================================
# Linux x86_64 (musl) Platform Configuration
# =============================================================================
# Produces fully static binaries suitable for Alpine Linux and scratch containers.

# Platform identification
PLATFORM := linuxmusl-x64
ARCH := x86_64
TARGET_OS := linux

# =============================================================================
# Compiler Settings
# =============================================================================

# Native compilation - use system compilers
CC := gcc
CXX := g++
AR := ar
RANLIB := ranlib
STRIP := strip

# =============================================================================
# Architecture Flags
# =============================================================================

ARCH_FLAGS := -m64

# Base compiler flags
# -fPIC: Position-independent code for static libs
# -O3: Maximum optimization
# -pthread: Enable threading
# -static: Fully static linking (musl specialty)
COMMON_FLAGS := $(ARCH_FLAGS) -O3 -fPIC -pthread
CFLAGS := $(COMMON_FLAGS)
CXXFLAGS := $(COMMON_FLAGS)

# Suppress deprecated warnings unless DEBUG=1
ifndef DEBUG
    CFLAGS += -Wno-deprecated-declarations
    CXXFLAGS += -Wno-deprecated-declarations
endif

# Linker flags for fully static build
# -static: Link everything statically (musl makes this work correctly)
# -pthread: Thread support
# Note: musl default stack is 128KB, increase to 2MB for FFmpeg
LDFLAGS := $(ARCH_FLAGS) -static -pthread -Wl,-z,stack-size=2097152

# =============================================================================
# Build Tool Configuration
# =============================================================================

# pkg-config setup
PKG_CONFIG := pkg-config
PKG_CONFIG_LIBDIR := $(PREFIX)/lib/pkgconfig

# CMake configuration for cmake-based codecs (x265, aom, svt-av1)
CMAKE_OPTS := \
    -DCMAKE_INSTALL_PREFIX=$(PREFIX) \
    -DCMAKE_PREFIX_PATH=$(PREFIX) \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_C_COMPILER=$(CC) \
    -DCMAKE_CXX_COMPILER=$(CXX) \
    -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
    -DCMAKE_EXE_LINKER_FLAGS="-static" \
    $(if $(DEBUG),,-Wno-dev)

# Meson configuration for meson-based codecs (dav1d)
MESON_OPTS := \
    --prefix=$(PREFIX) \
    --libdir=lib \
    --buildtype=release \
    --default-library=static

# =============================================================================
# Codec-Specific Platform Overrides
# =============================================================================

# libvpx target triple
LIBVPX_TARGET := x86_64-linux-gcc

# x264 host triple (empty for native build)
X264_HOST :=

# aom CPU target
AOM_TARGET_CPU := x86_64

# Architecture pattern for file command verification
ARCH_VERIFY_PATTERN := x86-64

# FFmpeg extra libraries for linking
# musl doesn't need -ldl (dlopen is in libc)
FFMPEG_EXTRA_LIBS := -lpthread -lm -lstdc++

# =============================================================================
# Export Variables
# =============================================================================

export CC CXX AR RANLIB STRIP
export CFLAGS CXXFLAGS LDFLAGS
export PKG_CONFIG PKG_CONFIG_LIBDIR
