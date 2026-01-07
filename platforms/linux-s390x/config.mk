# =============================================================================
# Platform Configuration - linux-s390x
# =============================================================================
# Debian (glibc, s390x - IBM Z mainframe)
# =============================================================================

# Platform identification
PLATFORM := linux-s390x
ARCH := s390x

# Compiler settings (native Debian toolchain)
CC := gcc
CXX := g++

# Architecture flags for s390x (z/Architecture)
# -march=z13 is a reasonable baseline for modern IBM Z
ARCH_FLAGS := -march=z13 -mtune=z14

# Optimization and hardening flags
CFLAGS := $(ARCH_FLAGS) -O2 -fPIC -fstack-protector-strong
CXXFLAGS := $(ARCH_FLAGS) -O2 -fPIC -fstack-protector-strong
LDFLAGS := -static-libgcc

# =============================================================================
# Build Tool Configuration
# =============================================================================

# pkg-config setup for consistent dependency resolution
# PKG_CONFIG_LIBDIR replaces default search paths (prevents finding wrong libs)
PKG_CONFIG := pkg-config
PKG_CONFIG_LIBDIR := $(PREFIX)/lib/pkgconfig

# CMake cross-compilation settings (native build)
CMAKE_OPTS := \
	-DCMAKE_SYSTEM_NAME=Linux \
	-DCMAKE_SYSTEM_PROCESSOR=$(ARCH) \
	-DCMAKE_C_COMPILER=$(CC) \
	-DCMAKE_CXX_COMPILER=$(CXX) \
	-DCMAKE_C_FLAGS="$(CFLAGS)" \
	-DCMAKE_CXX_FLAGS="$(CXXFLAGS)" \
	-DCMAKE_INSTALL_PREFIX=$(PREFIX) \
	-DCMAKE_PREFIX_PATH=$(PREFIX) \
	-DCMAKE_BUILD_TYPE=Release \
	-DBUILD_SHARED_LIBS=OFF \
	$(if $(DEBUG),,-Wno-dev)

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
# Export Variables
# =============================================================================

export CC CXX
export CFLAGS CXXFLAGS LDFLAGS
export PKG_CONFIG PKG_CONFIG_LIBDIR
