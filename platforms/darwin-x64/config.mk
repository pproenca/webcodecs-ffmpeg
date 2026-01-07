# =============================================================================
# macOS x86_64 (Intel) Platform Configuration
# =============================================================================
# Native build on Intel runners (macos-15-intel)

# Platform identification
PLATFORM := darwin-x64
ARCH := x86_64
TARGET_OS := darwin

# =============================================================================
# Compiler Settings
# =============================================================================

CC := clang
CXX := clang++
AR := ar
RANLIB := ranlib

# macOS SDK path
SDKROOT := $(shell xcrun --show-sdk-path 2>/dev/null || echo "")

# Minimum macOS version (Catalina - last before ARM transition)
MACOSX_DEPLOYMENT_TARGET := 10.15

# =============================================================================
# Architecture Flags
# =============================================================================

ARCH_FLAGS := -arch x86_64

# Base compiler flags
COMMON_FLAGS := $(ARCH_FLAGS) -O3 -fPIC
ifdef SDKROOT
    COMMON_FLAGS += -isysroot $(SDKROOT)
endif
CFLAGS := $(COMMON_FLAGS)
CXXFLAGS := $(COMMON_FLAGS)

# Suppress deprecated warnings unless DEBUG=1
# In CI, DEBUG is set from RUNNER_DEBUG when debug logging is enabled
ifndef DEBUG
    CFLAGS += -Wno-deprecated-declarations
    CXXFLAGS += -Wno-deprecated-declarations
endif

LDFLAGS := $(ARCH_FLAGS)
ifdef SDKROOT
    LDFLAGS += -isysroot $(SDKROOT)
endif

# =============================================================================
# Build Tool Configuration
# =============================================================================

# pkg-config setup
PKG_CONFIG := pkg-config
PKG_CONFIG_LIBDIR := $(PREFIX)/lib/pkgconfig

# CMake configuration for cmake-based codecs (x265, aom, svt-av1)
# -Wno-dev suppresses CMake developer warnings unless DEBUG=1
CMAKE_OPTS := \
    -DCMAKE_OSX_ARCHITECTURES=x86_64 \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=$(MACOSX_DEPLOYMENT_TARGET) \
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
# Homebrew Integration
# =============================================================================

# Detect Homebrew prefix (Intel location)
HOMEBREW_PREFIX := $(shell brew --prefix 2>/dev/null || echo "/usr/local")

# Add tool paths
PATH := $(PREFIX)/bin:$(HOMEBREW_PREFIX)/bin:$(PATH)

# =============================================================================
# Export Variables
# =============================================================================

export CC CXX AR RANLIB
export CFLAGS CXXFLAGS LDFLAGS
export PKG_CONFIG PKG_CONFIG_LIBDIR
export MACOSX_DEPLOYMENT_TARGET
export PATH
ifdef SDKROOT
    export SDKROOT
endif
