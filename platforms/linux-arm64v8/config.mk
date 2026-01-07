# =============================================================================
# Linux ARM64 Platform Configuration (glibc - Amazon Linux 2)
# =============================================================================

# Platform identification
PLATFORM := linux-arm64v8
ARCH := aarch64
TARGET_OS := linux

# =============================================================================
# Compiler Settings
# =============================================================================

CC ?= gcc
CXX ?= g++
AR ?= ar
RANLIB ?= ranlib

# =============================================================================
# Architecture Flags
# =============================================================================

# ARMv8-A is the base for 64-bit ARM
ARCH_FLAGS := -march=armv8-a

# Base compiler flags
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
    -DCMAKE_SYSTEM_PROCESSOR=aarch64 \
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

# =============================================================================
# Codec Build Configuration
# =============================================================================

# libvpx target architecture
LIBVPX_TARGET := arm64-linux-gcc
