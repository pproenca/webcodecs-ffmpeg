# =============================================================================
# Platform Configuration - linux-ppc64le
# =============================================================================
# Debian (glibc, ppc64le - IBM POWER Little Endian)
# =============================================================================

# Platform identification
PLATFORM := linux-ppc64le
ARCH := ppc64le

# Compiler settings (native Debian toolchain)
CC := gcc
CXX := g++

# Architecture flags for ppc64le (POWER8+ Little Endian)
# -mcpu=power8 is the baseline for ppc64le
ARCH_FLAGS := -mcpu=power8 -mtune=power8

# Optimization and hardening flags
CFLAGS := $(ARCH_FLAGS) -O2 -fPIC -fstack-protector-strong
CXXFLAGS := $(ARCH_FLAGS) -O2 -fPIC -fstack-protector-strong
LDFLAGS := -static-libgcc

# CMake cross-compilation settings (native build)
CMAKE_OPTS := \
	-DCMAKE_SYSTEM_NAME=Linux \
	-DCMAKE_SYSTEM_PROCESSOR=$(ARCH) \
	-DCMAKE_C_COMPILER=$(CC) \
	-DCMAKE_CXX_COMPILER=$(CXX) \
	-DCMAKE_C_FLAGS="$(CFLAGS)" \
	-DCMAKE_CXX_FLAGS="$(CXXFLAGS)" \
	-DCMAKE_INSTALL_PREFIX=$(PREFIX) \
	-DCMAKE_BUILD_TYPE=Release \
	-DBUILD_SHARED_LIBS=OFF

# Meson cross-compilation settings (native build)
MESON_OPTS := \
	--prefix=$(PREFIX) \
	--buildtype=release \
	--default-library=static \
	-Dc_args="$(CFLAGS)" \
	-Dcpp_args="$(CXXFLAGS)"

# =============================================================================
# Build Tool Configuration
# =============================================================================

# pkg-config setup for consistent dependency resolution
# PKG_CONFIG_LIBDIR replaces default search paths (prevents finding wrong libs)
PKG_CONFIG := pkg-config
PKG_CONFIG_LIBDIR := $(PREFIX)/lib/pkgconfig

# Number of parallel jobs
NPROC := $(shell nproc)

# =============================================================================
# Export Variables
# =============================================================================

export CC CXX
export CFLAGS CXXFLAGS LDFLAGS
export PKG_CONFIG PKG_CONFIG_LIBDIR
