# =============================================================================
# Linux x86_64 (glibc) Platform Configuration
# =============================================================================

# Platform identification
PLATFORM := linux-x64
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
COMMON_FLAGS := $(ARCH_FLAGS) -O3 -fPIC -pthread
CFLAGS := $(COMMON_FLAGS)
CXXFLAGS := $(COMMON_FLAGS)

# Suppress deprecated warnings unless DEBUG=1
ifndef DEBUG
    CFLAGS += -Wno-deprecated-declarations
    CXXFLAGS += -Wno-deprecated-declarations
endif

# Linker flags for static build
# -static-libgcc -static-libstdc++: Link C/C++ runtime statically
# -pthread: Thread support
LDFLAGS := $(ARCH_FLAGS) -pthread

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

# SVT-AV1: Disable LTO for portable static libraries
# GCC LTO embeds compiler-specific bytecode that requires matching GCC LTO plugin
# to link. Most consumer toolchains don't have this plugin, causing linker errors:
#   "plugin needed to handle lto object"
# Disabling LTO ensures the .a files contain standard object code.
SVTAV1_CMAKE_OPTS := -DSVT_AV1_LTO=OFF

# Architecture pattern for file command verification
ARCH_VERIFY_PATTERN := x86-64

# FFmpeg extra libraries for linking
# Linux requires -ldl for x265's dlopen() usage
FFMPEG_EXTRA_LIBS := -lpthread -lm -lstdc++ -ldl

# =============================================================================
# Export Variables
# =============================================================================

export CC CXX AR RANLIB STRIP
export CFLAGS CXXFLAGS LDFLAGS
export PKG_CONFIG PKG_CONFIG_LIBDIR
