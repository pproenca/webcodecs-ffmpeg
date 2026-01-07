# Proposal: add-linux-builds

## Summary

Add Linux platform support using Docker containers for cross-compilation, targeting 8 architecture/libc combinations with a phased rollout prioritizing glibc platforms.

## Why

The project currently only supports macOS (darwin-arm64, darwin-x64). Linux is the primary deployment target for server-side media processing, containerized workloads, and embedded systems. Without Linux builds, users must compile FFmpeg themselves or use third-party binaries without provenance guarantees.

## What Changes

**Phase 1 - Core glibc platforms (highest priority):**
- `linux-x64` (x86_64 glibc)
- `linux-arm64` (ARM64v8-A glibc)

**Phase 2 - Additional glibc platforms:**
- `linux-armv6` (ARMv6 glibc, Raspberry Pi Zero/1)
- `linux-ppc64le` (PowerPC 64-bit LE glibc)
- `linux-riscv64` (RISC-V 64-bit glibc)
- `linux-s390x` (IBM Z glibc)

**Phase 3 - musl platforms:**
- `linuxmusl-x64` (x86_64 musl)
- `linuxmusl-arm64` (ARM64v8-A musl)

**Architecture:**
- Single `Dockerfile.linux` with multi-stage build for all targets
- Build script orchestrates container execution with architecture-specific toolchains
- Shared codec recipes (`shared/codecs/`) reused across all Linux platforms
- Platform-specific `config.mk` per target (similar to darwin pattern)

**Codec availability by architecture:**

| Codec | x64 | ARM64 | ARMv6 | ppc64le | RISC-V | s390x |
|-------|-----|-------|-------|---------|--------|-------|
| libvpx | Y | Y | Y | Y | Y | Y |
| libaom | Y | Y | Y | Y | Y | Y |
| dav1d | Y | Y | Y | Y | Y | Y |
| svt-av1 | Y | Y | N | N | N | N |
| opus | Y | Y | Y | Y | Y | Y |
| vorbis | Y | Y | Y | Y | Y | Y |
| lame | Y | Y | Y | Y | Y | Y |
| x264 | Y | Y | Y | Y | Y | Y |
| x265 | Y | Y | Y | Y | Y | Y |

**Note:** SVT-AV1 excluded from ARMv6, ppc64le, RISC-V, s390x due to limited architecture support.

## Impact

- **Affected specs:** None existing (new capability)
- **Affected code:**
  - New: `docker/Dockerfile.linux` (multi-arch build container)
  - New: `platforms/linux-*/` directories (6 glibc platforms)
  - New: `platforms/linuxmusl-*/` directories (2 musl platforms)
  - Modified: `.github/workflows/_build.yml` (expand matrix)
  - Modified: `shared/codecs/codec.mk` (SVT-AV1 architecture filtering)
  - New: `npm/linux-*/` and `npm/linuxmusl-*/` packages (sharp-libvips pattern)

## Technical Approach

### Docker-based Builds

Use official toolchain images for reproducible builds:
- glibc targets: Debian-based images with specific glibc version for ABI stability
- musl targets: Alpine-based images for truly static binaries

**Why Docker over native runners:**
1. GitHub Actions lacks native ARM64 Linux runners (only macOS ARM64)
2. Cross-compilation toolchains are complex and fragile (learned from darwin-x64 experience)
3. Docker provides consistent build environment across all targets
4. QEMU userspace emulation handles architecture differences

### Container Execution Model

```bash
# Single script runs build in appropriate container
./platforms/linux-x64/build.sh all

# Under the hood:
docker run --rm -v $PWD:/build \
  -e LICENSE=gpl \
  ffmpeg-build:linux-x64 \
  make -C /build/platforms/linux-x64 all
```

### glibc Version Targeting

Target glibc 2.28 (RHEL 8/Debian 10 era) for broad compatibility:
- Older than common server distributions
- Avoids glibc symbol versioning issues
- Matches BtbN/FFmpeg-Builds approach

### musl Static Linking

musl builds produce fully static binaries with no runtime dependencies:
- Ideal for Alpine Linux and scratch containers
- Requires different linker flags (`-static`)
- Stack size increased to 2MB (musl default is 128KB)

## Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| QEMU emulation slow for non-x64 | Long CI times | Cache aggressively, parallelize by license tier |
| Codec build failures on exotic archs | Missing platform support | SVT-AV1 already excluded; monitor x265 on RISC-V |
| glibc version mismatch | Runtime failures on old distros | Pin to glibc 2.28, verify with container tests |
| Docker layer caching ineffective | Slow rebuilds | Multi-stage builds, cache codec sources separately |
| CI runner resource limits | OOM on ARM64 QEMU | Use swap, limit parallelism in containers |

## Success Criteria

- [ ] Phase 1: linux-x64 and linux-arm64 build and pass verification
- [ ] Phase 2: All 6 glibc platforms build successfully
- [ ] Phase 3: Both musl platforms build with fully static binaries
- [ ] All 24 CI jobs pass (8 platforms × 3 licenses)
- [ ] npm packages published with correct optionalDependencies
- [ ] Binary architecture verified via `file` command in CI
- [ ] Static linkage verified via `ldd` (glibc) or file inspection (musl)
