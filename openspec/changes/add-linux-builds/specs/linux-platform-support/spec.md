## ADDED Requirements

### Requirement: Linux Platform Builds

The build system SHALL support building statically-linked FFmpeg binaries for Linux platforms across multiple architectures and C library implementations.

#### Scenario: glibc x64 build produces correct binary

- **WHEN** `./platforms/linux-x64/build.sh all` is executed
- **THEN** `artifacts/linux-x64-gpl/bin/ffmpeg` exists
- **AND** `file` reports "ELF 64-bit LSB executable, x86-64"
- **AND** `ldd` shows only glibc runtime dependencies (libc.so, libm.so, libpthread.so, ld-linux-x86-64.so)

#### Scenario: glibc ARM64 build produces correct binary

- **WHEN** `./platforms/linux-arm64/build.sh all` is executed
- **THEN** `artifacts/linux-arm64-gpl/bin/ffmpeg` exists
- **AND** `file` reports "ELF 64-bit LSB executable, ARM aarch64"
- **AND** `ldd` shows only glibc runtime dependencies

#### Scenario: musl x64 build produces fully static binary

- **WHEN** `./platforms/linuxmusl-x64/build.sh all` is executed
- **THEN** `artifacts/linuxmusl-x64-gpl/bin/ffmpeg` exists
- **AND** `file` reports "statically linked"
- **AND** `ldd` reports "not a dynamic executable"

#### Scenario: musl ARM64 build produces fully static binary

- **WHEN** `./platforms/linuxmusl-arm64/build.sh all` is executed
- **THEN** `artifacts/linuxmusl-arm64-gpl/bin/ffmpeg` exists
- **AND** `file` reports "statically linked"
- **AND** `ldd` reports "not a dynamic executable"

### Requirement: Docker-based Build Environment

The Linux build system SHALL use Docker containers to provide reproducible build environments with pre-configured toolchains.

#### Scenario: Build container provides required toolchain

- **GIVEN** `docker/Dockerfile.linux` exists
- **WHEN** the container is built with `--build-arg TARGET=linux-arm64`
- **THEN** the container includes `aarch64-linux-gnu-gcc` cross-compiler
- **AND** the container includes cmake, meson, nasm, and pkg-config
- **AND** the container can build all codec dependencies

#### Scenario: Container build matches local environment

- **WHEN** the same source code is built in Docker container
- **AND** the same source code is built on a native Linux machine with matching toolchain
- **THEN** the resulting binaries have identical functionality
- **AND** both pass architecture verification

### Requirement: glibc Version Compatibility

Linux glibc builds SHALL target glibc 2.28 or later for maximum distribution compatibility.

#### Scenario: Binary runs on RHEL 8 compatible system

- **GIVEN** FFmpeg binary built with linux-x64 platform
- **WHEN** binary is executed on a RHEL 8 / CentOS 8 system (glibc 2.28)
- **THEN** the binary executes successfully
- **AND** `ffmpeg -version` returns valid output

#### Scenario: Binary runs on modern distributions

- **GIVEN** FFmpeg binary built with linux-x64 platform
- **WHEN** binary is executed on Ubuntu 22.04 (glibc 2.35)
- **THEN** the binary executes successfully without compatibility warnings

### Requirement: Architecture-Specific Codec Selection

The build system SHALL exclude codecs that lack support for specific architectures.

#### Scenario: SVT-AV1 excluded on unsupported architectures

- **GIVEN** platform is linux-armv6, linux-ppc64le, linux-riscv64, or linux-s390x
- **WHEN** `make codecs` is executed
- **THEN** SVT-AV1 is NOT included in `ACTIVE_CODECS`
- **AND** FFmpeg configure does NOT include `--enable-libsvtav1`

#### Scenario: SVT-AV1 included on supported architectures

- **GIVEN** platform is linux-x64, linux-arm64, linuxmusl-x64, or linuxmusl-arm64
- **WHEN** `make codecs` is executed
- **THEN** SVT-AV1 IS included in `ACTIVE_CODECS`
- **AND** FFmpeg configure includes `--enable-libsvtav1`

### Requirement: Cross-Compilation Support

The build system SHALL support cross-compiling for target architectures different from the build host.

#### Scenario: ARM64 cross-compilation from x64 host

- **GIVEN** build host is x86_64
- **AND** Docker with QEMU binfmt is configured
- **WHEN** `./platforms/linux-arm64/build.sh all` is executed
- **THEN** build completes successfully
- **AND** output binary is ARM64 architecture (not x86_64)

#### Scenario: Platform config specifies cross-compiler

- **GIVEN** platform is linux-arm64
- **WHEN** `config.mk` is evaluated
- **THEN** `CC` is set to `aarch64-linux-gnu-gcc`
- **AND** `CXX` is set to `aarch64-linux-gnu-g++`
- **AND** `PKG_CONFIG` uses cross-compilation prefix

### Requirement: Build Verification

All Linux builds SHALL verify architecture correctness and linkage before packaging.

#### Scenario: Architecture verification catches wrong-arch binary

- **GIVEN** build claims to target linux-arm64
- **WHEN** the binary is actually x86_64 (cross-compilation failure)
- **THEN** `make verify` fails with architecture mismatch error
- **AND** CI job fails before artifact upload

#### Scenario: Linkage verification for glibc builds

- **GIVEN** build targets linux-x64 (glibc)
- **WHEN** `make verify` runs
- **THEN** `ldd` output is checked for unexpected dependencies
- **AND** only standard glibc libraries are allowed

#### Scenario: Static linkage verification for musl builds

- **GIVEN** build targets linuxmusl-x64
- **WHEN** `make verify` runs
- **THEN** binary is verified as "statically linked"
- **AND** `ldd` reports "not a dynamic executable"

### Requirement: License Tier Support

All Linux platforms SHALL support the same three license tiers as macOS platforms.

#### Scenario: BSD tier builds only BSD-licensed codecs

- **GIVEN** platform is any Linux platform
- **WHEN** `make LICENSE=bsd all` is executed
- **THEN** only BSD-licensed codecs are built (libvpx, aom, dav1d, opus, ogg, vorbis)
- **AND** SVT-AV1 is included if architecture supports it
- **AND** x264, x265, lame are NOT built

#### Scenario: GPL tier builds all codecs

- **GIVEN** platform is any Linux platform
- **WHEN** `make LICENSE=gpl all` is executed
- **THEN** all supported codecs are built including x264 and x265
- **AND** FFmpeg is configured with `--enable-gpl`

### Requirement: CI Matrix Coverage

The CI system SHALL build all Linux platform and license combinations.

#### Scenario: Full matrix executes on push to master

- **WHEN** code is pushed to master branch
- **THEN** CI builds 24 Linux jobs (8 platforms × 3 licenses)
- **AND** CI builds 6 macOS jobs (2 platforms × 3 licenses)
- **AND** all 30 jobs must pass for green status

#### Scenario: Artifact naming follows convention

- **GIVEN** build completes for linux-arm64 with gpl license
- **WHEN** artifacts are packaged
- **THEN** tarball is named `ffmpeg-linux-arm64-gpl.tar.gz`
- **AND** checksum is named `ffmpeg-linux-arm64-gpl.tar.gz.sha256`
