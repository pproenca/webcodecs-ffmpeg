# =============================================================================
# Platform Configuration - linux-armv6
# =============================================================================
# Debian (glibc, ARMv6 - Raspberry Pi Zero/1)
# =============================================================================

# Platform identification
PLATFORM := linux-armv6
ARCH := arm

# Compiler settings (native Debian toolchain)
CC := gcc
CXX := g++

# Architecture flags for ARMv6 with VFP (Raspberry Pi Zero/1)
# -mfpu=vfp enables vector floating point
# -mfloat-abi=hard for hardware floating point ABI
ARCH_FLAGS := -march=armv6 -mfpu=vfp -mfloat-abi=hard

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

# Number of parallel jobs
NPROC := $(shell nproc)

# =============================================================================
# Build Tool Configuration
# =============================================================================

# pkg-config setup for consistent dependency resolution
# PKG_CONFIG_LIBDIR replaces default search paths (prevents finding wrong libs)
PKG_CONFIG := pkg-config
PKG_CONFIG_LIBDIR := $(PREFIX)/lib/pkgconfig

# =============================================================================
# Export Variables
# =============================================================================

export CC CXX
export CFLAGS CXXFLAGS LDFLAGS
export PKG_CONFIG PKG_CONFIG_LIBDIR
