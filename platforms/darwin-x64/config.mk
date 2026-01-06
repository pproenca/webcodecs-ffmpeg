# =============================================================================
# macOS x86_64 (Intel) Platform Configuration
# =============================================================================
# Cross-compiled from ARM64 runners using -arch x86_64

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
LDFLAGS := $(ARCH_FLAGS)
ifdef SDKROOT
    LDFLAGS += -isysroot $(SDKROOT)
endif

# =============================================================================
# Build Tool Configuration
# =============================================================================

# pkg-config setup
PKG_CONFIG := pkg-config
PKG_CONFIG_PATH := $(PREFIX)/lib/pkgconfig

# CMake configuration for cmake-based codecs (x265, aom, svt-av1)
# CMAKE_SYSTEM_PROCESSOR is required when cross-compiling from ARM64 runners
# to x86_64 target - without it CMake detects ARM64 host and includes wrong
# assembly code (e.g., libaom would include ARM NEON instead of x86 SSE/AVX)
CMAKE_OPTS := \
    -DCMAKE_OSX_ARCHITECTURES=x86_64 \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=$(MACOSX_DEPLOYMENT_TARGET) \
    -DCMAKE_SYSTEM_PROCESSOR=x86_64 \
    -DCMAKE_INSTALL_PREFIX=$(PREFIX) \
    -DCMAKE_PREFIX_PATH=$(PREFIX) \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_C_COMPILER=$(CC) \
    -DCMAKE_CXX_COMPILER=$(CXX)

# Meson configuration for meson-based codecs (dav1d)
# Cross-file required when building x86_64 on ARM64 runners - ensures Meson
# detects x86_64 as host_machine.cpu_family() for correct assembly selection
MESON_CROSS_FILE := $(CURDIR)/x86_64-darwin.ini
MESON_OPTS := \
    --cross-file=$(MESON_CROSS_FILE) \
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

# Detect Homebrew prefix (different on Intel vs ARM)
HOMEBREW_PREFIX := $(shell brew --prefix 2>/dev/null || echo "/opt/homebrew")

# Add Homebrew paths for build tools
PATH := $(HOMEBREW_PREFIX)/bin:$(PATH)

# =============================================================================
# Export Variables
# =============================================================================

export CC CXX AR RANLIB
export CFLAGS CXXFLAGS LDFLAGS
export PKG_CONFIG PKG_CONFIG_PATH
export MACOSX_DEPLOYMENT_TARGET
export PATH
ifdef SDKROOT
    export SDKROOT
endif
