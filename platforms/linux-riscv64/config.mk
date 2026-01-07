# =============================================================================
# Platform Configuration - linux-riscv64
# =============================================================================
# Debian (glibc, RISC-V 64-bit)
# =============================================================================

# Platform identification
PLATFORM := linux-riscv64
ARCH := riscv64

# Compiler settings (native Debian toolchain)
CC := gcc
CXX := g++

# Architecture flags for RISC-V 64-bit
# -march=rv64gc is the baseline (general + compressed instructions)
ARCH_FLAGS := -march=rv64gc -mabi=lp64d

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
