# =============================================================================
# Platform Configuration - linuxmusl-x64
# =============================================================================
# Alpine Linux (musl libc, x86_64)
# =============================================================================

# Platform identification
PLATFORM := linuxmusl-x64
ARCH := x86_64

# Compiler settings (native Alpine toolchain)
CC := gcc
CXX := g++

# Architecture flags for x86_64
ARCH_FLAGS := -m64

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

# pkg-config setup for consistent dependency resolution
PKG_CONFIG := pkg-config
PKG_CONFIG_LIBDIR := $(PREFIX)/lib/pkgconfig

# Export variables
export CC CXX CFLAGS CXXFLAGS LDFLAGS
export PKG_CONFIG PKG_CONFIG_LIBDIR

# Number of parallel jobs
NPROC := $(shell nproc)
