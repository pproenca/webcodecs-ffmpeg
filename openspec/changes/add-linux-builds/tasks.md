# Tasks: add-linux-builds

## Phase 1: Core Infrastructure + x64/ARM64 glibc

### 1.1 Docker Build Infrastructure
- [x] 1.1.1 Create `docker/Dockerfile.linux` with base stage (Debian Bullseye, build tools)
- [x] 1.1.2 Add x64 toolchain stage (native compilation)
- [x] 1.1.3 Add ARM64 toolchain stage (cross-compilation with aarch64-linux-gnu)
- [x] 1.1.4 Add builder stage that copies project and runs make
- [x] 1.1.5 Create `docker/build.sh` helper script for local testing
- [x] 1.1.6 Add `.dockerignore` to exclude artifacts and node_modules

### 1.2 Platform: linux-x64
- [x] 1.2.1 Create `platforms/linux-x64/config.mk` with glibc compiler settings
- [x] 1.2.2 Create `platforms/linux-x64/Makefile` (mirror darwin pattern)
- [x] 1.2.3 Create `platforms/linux-x64/build.sh` that invokes Docker
- [ ] 1.2.4 Test local build: `./platforms/linux-x64/build.sh all`
- [ ] 1.2.5 Verify architecture: `file artifacts/linux-x64-gpl/bin/ffmpeg`
- [ ] 1.2.6 Verify static linking: `ldd artifacts/linux-x64-gpl/bin/ffmpeg`

### 1.3 Platform: linux-arm64
- [x] 1.3.1 Create `platforms/linux-arm64/config.mk` with cross-compiler settings
- [x] 1.3.2 Create `platforms/linux-arm64/Makefile`
- [x] 1.3.3 Create `platforms/linux-arm64/build.sh`
- [ ] 1.3.4 Test local build with QEMU: `./platforms/linux-arm64/build.sh all`
- [ ] 1.3.5 Verify architecture and linking

### 1.4 CI Integration (Phase 1)
- [x] 1.4.1 Update `_build.yml` matrix to include linux-x64 and linux-arm64
- [x] 1.4.2 Add Docker build step before make for Linux platforms
- [x] 1.4.3 Replace `otool -L` with `ldd` for Linux verification
- [x] 1.4.4 Replace `stat -f%z` with `stat -c%s` for Linux (tarball size check)
- [x] 1.4.5 Add QEMU setup step for ARM64 emulation
- [ ] 1.4.6 Test CI with linux-x64 first (no emulation)
- [ ] 1.4.7 Test CI with linux-arm64 (QEMU)

### 1.5 Shared Code Updates
- [x] 1.5.1 Update `shared/common.mk` with Linux-specific commands (ldd vs otool)
- [x] 1.5.2 Add `ARCH_VERIFY_PATTERN` documentation for Linux platforms
- [x] 1.5.3 Verify `SED_INPLACE` works in container (should already)

## Phase 2: Additional glibc Platforms

### 2.1 Platform: linux-armv6
- [ ] 2.1.1 Add armv6 cross-compiler stage to Dockerfile
- [ ] 2.1.2 Create `platforms/linux-armv6/config.mk`
- [ ] 2.1.3 Create `platforms/linux-armv6/Makefile`
- [ ] 2.1.4 Create `platforms/linux-armv6/build.sh`
- [ ] 2.1.5 Test build and verify ARM architecture

### 2.2 Platform: linux-ppc64le
- [ ] 2.2.1 Add ppc64le cross-compiler stage to Dockerfile
- [ ] 2.2.2 Create `platforms/linux-ppc64le/config.mk`
- [ ] 2.2.3 Create `platforms/linux-ppc64le/Makefile`
- [ ] 2.2.4 Create `platforms/linux-ppc64le/build.sh`
- [ ] 2.2.5 Test build and verify PowerPC architecture

### 2.3 Platform: linux-riscv64
- [ ] 2.3.1 Add riscv64 cross-compiler stage to Dockerfile
- [ ] 2.3.2 Create `platforms/linux-riscv64/config.mk`
- [ ] 2.3.3 Create `platforms/linux-riscv64/Makefile`
- [ ] 2.3.4 Create `platforms/linux-riscv64/build.sh`
- [ ] 2.3.5 Test build and verify RISC-V architecture

### 2.4 Platform: linux-s390x
- [ ] 2.4.1 Add s390x cross-compiler stage to Dockerfile
- [ ] 2.4.2 Create `platforms/linux-s390x/config.mk`
- [ ] 2.4.3 Create `platforms/linux-s390x/Makefile`
- [ ] 2.4.4 Create `platforms/linux-s390x/build.sh`
- [ ] 2.4.5 Test build and verify IBM Z architecture

### 2.5 SVT-AV1 Architecture Filtering
- [ ] 2.5.1 Add `SVT_AV1_SUPPORTED_ARCHS` to `shared/codecs/codec.mk`
- [ ] 2.5.2 Filter SVT-AV1 from `BSD_CODECS` for unsupported architectures
- [ ] 2.5.3 Update FFmpeg configure to skip `--enable-libsvtav1` when excluded
- [ ] 2.5.4 Test that armv6/ppc64le/riscv64/s390x build without SVT-AV1

### 2.6 CI Integration (Phase 2)
- [ ] 2.6.1 Add armv6, ppc64le, riscv64, s390x to `_build.yml` matrix
- [ ] 2.6.2 Configure QEMU for all additional architectures
- [ ] 2.6.3 Monitor CI times, adjust `make -j` if needed
- [ ] 2.6.4 Verify all 18 jobs pass (6 platforms × 3 licenses)

## Phase 3: musl Platforms

### 3.1 musl Docker Infrastructure
- [ ] 3.1.1 Add Alpine-based musl stage to Dockerfile
- [ ] 3.1.2 Configure static linking flags (`-static`, stack size 2MB)
- [ ] 3.1.3 Add musl-specific build tools (musl-gcc, etc.)

### 3.2 Platform: linuxmusl-x64
- [ ] 3.2.1 Create `platforms/linuxmusl-x64/config.mk` with musl settings
- [ ] 3.2.2 Create `platforms/linuxmusl-x64/Makefile`
- [ ] 3.2.3 Create `platforms/linuxmusl-x64/build.sh`
- [ ] 3.2.4 Verify fully static binary (no dynamic interpreter)
- [ ] 3.2.5 Test binary runs on Alpine Linux container

### 3.3 Platform: linuxmusl-arm64
- [ ] 3.3.1 Create `platforms/linuxmusl-arm64/config.mk`
- [ ] 3.3.2 Create `platforms/linuxmusl-arm64/Makefile`
- [ ] 3.3.3 Create `platforms/linuxmusl-arm64/build.sh`
- [ ] 3.3.4 Verify fully static binary
- [ ] 3.3.5 Test binary runs on Alpine ARM64 container

### 3.4 CI Integration (Phase 3)
- [ ] 3.4.1 Add linuxmusl-x64 and linuxmusl-arm64 to matrix
- [ ] 3.4.2 Add static binary verification (file shows "statically linked")
- [ ] 3.4.3 Verify all 24 jobs pass (8 platforms × 3 licenses)

## Phase 4: Distribution & Documentation

### 4.1 npm Package Updates (sharp-libvips pattern)
- [ ] 4.1.1 Create `npm/linux-x64/package.json` with `os`, `cpu`, `libc: ["glibc"]` fields
- [ ] 4.1.2 Create `npm/linux-arm64/package.json` with platform fields
- [ ] 4.1.3 Create `npm/linuxmusl-x64/package.json` with `libc: ["musl"]`
- [ ] 4.1.4 Create `npm/linuxmusl-arm64/package.json` with platform fields
- [ ] 4.1.5 Create remaining glibc platform packages (armv6, ppc64le, riscv64, s390x)
- [ ] 4.1.6 Update consumer `package.json` optionalDependencies listing all platforms
- [ ] 4.1.7 Update `populate-npm.sh` to handle Linux platforms
- [ ] 4.1.8 Test npm install on Linux x64 (glibc)
- [ ] 4.1.9 Test npm install on Alpine (musl)

### 4.2 CI Release Updates
- [ ] 4.2.1 Update `release.yml` to handle 24 artifacts (8 platforms × 3 licenses)
- [ ] 4.2.2 Verify npm publish for Linux packages
- [ ] 4.2.3 Test release workflow with pre-release tag

### 4.3 Documentation
- [ ] 4.3.1 Update README.md with Linux platform support
- [ ] 4.3.2 Document Docker build requirements
- [ ] 4.3.3 Document musl vs glibc considerations
- [ ] 4.3.4 Update CLAUDE.md with Linux build patterns

### 4.4 Final Verification
- [ ] 4.4.1 Code review all changes
- [ ] 4.4.2 Run full CI matrix (all 24 jobs)
- [ ] 4.4.3 Test end-to-end: push to master → CI → release → npm
