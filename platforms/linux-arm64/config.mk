# =============================================================================
# Linux ARM64 (aarch64, glibc) Platform Configuration
# =============================================================================
# Cross-compilation from x86_64 host to aarch64 target.

# Platform identification
PLATFORM := linux-arm64
ARCH := aarch64
TARGET_OS := linux

# =============================================================================
# Cross-Compiler Settings
# =============================================================================

# Cross-compilation toolchain (from Dockerfile)
CROSS_PREFIX := aarch64-linux-gnu-
CC := $(CROSS_PREFIX)gcc
CXX := $(CROSS_PREFIX)g++
AR := $(CROSS_PREFIX)ar
RANLIB := $(CROSS_PREFIX)ranlib
STRIP := $(CROSS_PREFIX)strip

# Host triplet for autoconf
HOST_TRIPLET := aarch64-linux-gnu

# =============================================================================
# Architecture Flags
# =============================================================================

# ARM64 specific flags
ARCH_FLAGS :=

# Base compiler flags
COMMON_FLAGS := $(ARCH_FLAGS) -O3 -fPIC -pthread
CFLAGS := $(COMMON_FLAGS)
CXXFLAGS := $(COMMON_FLAGS)

# Suppress deprecated warnings unless DEBUG=1
ifndef DEBUG
    CFLAGS += -Wno-deprecated-declarations
    CXXFLAGS += -Wno-deprecated-declarations
endif

LDFLAGS := $(ARCH_FLAGS) -pthread

# =============================================================================
# Build Tool Configuration
# =============================================================================

# pkg-config setup for cross-compilation
PKG_CONFIG := pkg-config
PKG_CONFIG_LIBDIR := $(PREFIX)/lib/pkgconfig

# CMake configuration for cross-compilation
CMAKE_OPTS := \
    -DCMAKE_INSTALL_PREFIX=$(PREFIX) \
    -DCMAKE_PREFIX_PATH=$(PREFIX) \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_C_COMPILER=$(CC) \
    -DCMAKE_CXX_COMPILER=$(CXX) \
    -DCMAKE_SYSTEM_NAME=Linux \
    -DCMAKE_SYSTEM_PROCESSOR=aarch64 \
    -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
    -DCMAKE_FIND_ROOT_PATH=$(PREFIX) \
    -DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER \
    -DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY \
    -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY \
    $(if $(DEBUG),,-Wno-dev)

# Meson cross-compilation configuration
# Meson requires a cross file for cross-compilation
MESON_CROSS_FILE := $(BUILD_DIR)/meson-cross.ini
MESON_OPTS := \
    --prefix=$(PREFIX) \
    --libdir=lib \
    --buildtype=release \
    --default-library=static \
    --cross-file=$(MESON_CROSS_FILE)

# =============================================================================
# Codec-Specific Platform Overrides
# =============================================================================

# libvpx target triple
LIBVPX_TARGET := arm64-linux-gcc

# x264 host triple for cross-compilation
X264_HOST := aarch64-linux-gnu

# aom CPU target
AOM_TARGET_CPU := arm64

# Architecture pattern for file command verification
ARCH_VERIFY_PATTERN := aarch64

# =============================================================================
# Export Variables
# =============================================================================

export CC CXX AR RANLIB STRIP
export CFLAGS CXXFLAGS LDFLAGS
export PKG_CONFIG PKG_CONFIG_LIBDIR

# =============================================================================
# Meson Cross File Generation
# =============================================================================
# This target creates a meson cross-compilation configuration file.
# Called by codec builds that use meson (e.g., dav1d).

.PHONY: meson-cross-file

meson-cross-file: $(MESON_CROSS_FILE)

$(MESON_CROSS_FILE): | dirs
	@mkdir -p $(dir $@)
	@echo "[binaries]" > $@
	@echo "c = '$(CC)'" >> $@
	@echo "cpp = '$(CXX)'" >> $@
	@echo "ar = '$(AR)'" >> $@
	@echo "strip = '$(STRIP)'" >> $@
	@echo "pkgconfig = '$(PKG_CONFIG)'" >> $@
	@echo "" >> $@
	@echo "[host_machine]" >> $@
	@echo "system = 'linux'" >> $@
	@echo "cpu_family = 'aarch64'" >> $@
	@echo "cpu = 'aarch64'" >> $@
	@echo "endian = 'little'" >> $@
	@echo "" >> $@
	@echo "[built-in options]" >> $@
	@echo "c_args = ['-O3', '-fPIC']" >> $@
	@echo "cpp_args = ['-O3', '-fPIC']" >> $@
	@echo "c_link_args = []" >> $@
	@echo "cpp_link_args = []" >> $@
	@echo "pkg_config_path = '$(PREFIX)/lib/pkgconfig'" >> $@
