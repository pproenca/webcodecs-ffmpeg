# Design: add-linux-builds

## Context

This project provides static FFmpeg builds for native addon development. macOS builds run natively on GitHub Actions runners. Linux builds require a different approach due to:

1. No native ARM64/RISC-V/ppc64le/s390x Linux runners on GitHub Actions
2. Cross-compilation is fragile (darwin-x64 required 8+ fixes before switching to native)
3. glibc version compatibility affects binary portability
4. musl requires different linking strategy for truly static binaries

## Goals

- Produce statically-linked FFmpeg for 8 Linux architecture/libc combinations
- Maintain codec parity with macOS builds (except architecture-specific limitations)
- Reuse existing shared codec recipes without duplication
- Fit within GitHub Actions resource limits (6-hour timeout, memory constraints)

## Non-Goals

- Windows support (separate future work)
- Dynamic/shared library builds
- GPU acceleration (CUDA, VA-API) - requires runtime dependencies
- Cross-compiling FROM Linux TO other platforms

## Decisions

### Decision 1: Docker-based containerized builds

**What:** All Linux builds execute inside Docker containers with pre-configured toolchains.

**Why:**
- GitHub Actions only provides x64 Linux runners
- QEMU userspace emulation allows building for any architecture
- Containers provide reproducible environments with pinned toolchain versions
- Industry precedent: BtbN/FFmpeg-Builds, wader/static-ffmpeg use this approach

**Alternatives considered:**
- Native GitHub Actions runners: Not available for ARM64/RISC-V Linux
- Cross-compilation without containers: Fragile, darwin-x64 experience showed 8+ fixes needed
- Third-party CI services with native ARM: Cost, vendor lock-in, less control

### Decision 2: Single multi-stage Dockerfile

**What:** One `Dockerfile.linux` with multi-stage builds for all targets.

**Why:**
- Reduces maintenance (one file vs 8 separate Dockerfiles)
- Shared base layers (build tools) cached across targets
- Clear separation: base → toolchain → codec-builder → final
- Build arguments (`--build-arg TARGET=linux-arm64`) select target

**Structure:**
```dockerfile
# Stage 1: Base build environment
FROM debian:bookworm-slim AS base
RUN apt-get update && apt-get install -y build-essential cmake meson ...

# Stage 2: Architecture-specific toolchain (per-target)
FROM base AS toolchain-arm64
RUN apt-get install -y gcc-aarch64-linux-gnu g++-aarch64-linux-gnu ...

FROM base AS toolchain-x64
# Native, no cross-compiler needed

# Stage 3: Build FFmpeg (selected by TARGET arg)
FROM toolchain-${TARGET} AS builder
COPY . /build
WORKDIR /build/platforms/linux-${TARGET}
RUN make all
```

### Decision 3: glibc 2.28 baseline for glibc builds

**What:** Target glibc 2.28 as minimum supported version.

**Why:**
- Matches RHEL 8 / CentOS 8 (still in extended support)
- Matches Debian 10 Buster
- Provides 5+ year old baseline, covers vast majority of deployments
- Same approach as BtbN/FFmpeg-Builds

**Implementation:**
- Use Debian Buster (glibc 2.28) or equivalent base image
- Verify glibc version in CI with `ldd --version`

### Decision 4: Alpine-based images for musl builds

**What:** Use Alpine Linux for musl static builds.

**Why:**
- Alpine is the de facto musl distribution
- Smaller base images (faster CI)
- Well-tested musl toolchain
- Natural fit for container deployments

**Implementation:**
- Separate Dockerfile stages for musl targets
- Use `-static` linker flag
- Increase stack size to 2MB (`-Wl,-z,stack-size=2097152`)

### Decision 5: Architecture-aware codec selection

**What:** Exclude SVT-AV1 from ARMv6, ppc64le, RISC-V, s390x.

**Why:**
- SVT-AV1 uses x86/ARM64-specific SIMD intrinsics
- No official support for other architectures
- Build failures or poor performance on unsupported platforms

**Implementation:**
```makefile
# In shared/codecs/codec.mk
SVT_AV1_SUPPORTED_ARCHS := x86_64 aarch64
ifeq ($(filter $(ARCH),$(SVT_AV1_SUPPORTED_ARCHS)),)
    BSD_CODECS := $(filter-out svt-av1,$(BSD_CODECS))
endif
```

### Decision 6: Platform naming convention

**What:** Use `linux-<arch>` for glibc and `linuxmusl-<arch>` for musl platforms.

**Why:**
- Follows sharp-libvips convention for npm platform resolution
- `linuxmusl-` prefix enables npm's `libc` field matching
- Consistent with existing `darwin-arm64`, `darwin-x64` pattern for glibc
- Clear, unambiguous identification

**Mapping:**

| Platform ID | Architecture | C Library | LLVM Triple |
|------------|--------------|-----------|-------------|
| linux-x64 | x86_64 | glibc | x86_64-linux-gnu |
| linux-arm64 | aarch64 | glibc | aarch64-linux-gnu |
| linux-armv6 | armv6 | glibc | arm-linux-gnueabihf |
| linux-ppc64le | ppc64le | glibc | powerpc64le-linux-gnu |
| linux-riscv64 | riscv64 | glibc | riscv64-linux-gnu |
| linux-s390x | s390x | glibc | s390x-linux-gnu |
| linuxmusl-x64 | x86_64 | musl | x86_64-linux-musl |
| linuxmusl-arm64 | aarch64 | musl | aarch64-linux-musl |

**Note:** musl platforms use `linuxmusl-` prefix (not `linux-*-musl`) to match npm's platform resolution and sharp-libvips naming convention.

## Risks / Trade-offs

### Risk: QEMU emulation performance

**Impact:** Non-x64 builds may take 30-60 minutes vs 10 minutes native.

**Mitigation:**
- Aggressive caching of codec sources and intermediate builds
- Parallelize license tiers (bsd/lgpl/gpl run concurrently)
- Consider self-hosted ARM64 runner for linux-arm64 if CI times become problematic

### Risk: x265 on exotic architectures

**Impact:** x265 assembly may fail on RISC-V or s390x.

**Mitigation:**
- Monitor build logs, add to exclusion list if needed
- x265 has generic C fallbacks, may just be slow

### Risk: Container image size

**Impact:** Large Docker images slow CI startup.

**Mitigation:**
- Multi-stage builds with minimal final stage
- Don't include codec sources in image (mount at runtime)
- Use `.dockerignore` to exclude artifacts

### Risk: Memory pressure under QEMU

**Impact:** OOM kills during QEMU-emulated builds.

**Mitigation:**
- Limit `make -j` parallelism in containers
- Use swap in CI runners
- x265 is the heaviest; may need sequential build

## Migration Plan

**Phase 1 (Week 1-2):**
1. Create `docker/Dockerfile.linux` with x64 and arm64 support
2. Add `platforms/linux-x64/` and `platforms/linux-arm64/` directories
3. Modify `_build.yml` to include linux-x64 and linux-arm64 in matrix
4. Verify builds produce correct architecture binaries

**Phase 2 (Week 3-4):**
1. Add remaining glibc platforms (armv6, ppc64le, riscv64, s390x)
2. Implement SVT-AV1 architecture filtering
3. Monitor CI times, adjust parallelism if needed

**Phase 3 (Week 5):**
1. Add musl Dockerfile stages (Alpine-based)
2. Add `platforms/linuxmusl-x64/` and `platforms/linuxmusl-arm64/`
3. Verify truly static linking (no dynamic dependencies)

**Phase 4 (Week 6):**
1. Update npm packages with Linux optionalDependencies
2. Update documentation
3. Release

### Decision 7: GitHub Actions runners only (QEMU for non-x64)

**What:** Use only GitHub-hosted runners; accept QEMU emulation overhead for non-x64 architectures.

**Why:**
- Simplifies CI configuration (no self-hosted runner management)
- GitHub Actions provides sufficient resources for builds
- Cost-effective (included in GitHub plan)
- QEMU performance acceptable given aggressive caching

**Trade-off:** ARM64/RISC-V builds will be slower (30-60 min vs 10 min native). Mitigated by source caching and parallel license tier builds.

### Decision 8: Cache codec sources (not Docker layers)

**What:** Cache downloaded codec source tarballs; don't rely on Docker layer caching.

**Why:**
- Codec source downloads are the slowest part of initial builds
- Docker layer caching is unreliable with multi-arch builds on GitHub Actions
- Source cache key based on `shared/versions.mk` hash (same as macOS)
- Simpler to debug cache misses

**Implementation:**
```yaml
- uses: actions/cache@v4
  with:
    path: build/${{ matrix.platform }}/sources
    key: sources-${{ matrix.platform }}-${{ hashFiles('shared/versions.mk') }}
```

### Decision 9: Architecture verification only (no transcode tests)

**What:** Verify binary architecture with `file` command; don't run FFmpeg transcode tests.

**Why:**
- Architecture verification catches cross-compilation failures (the main risk)
- Transcode tests under QEMU would be extremely slow
- FFmpeg's own test suite is comprehensive; we don't need to replicate
- `ffmpeg -version` already runs as part of verification
- Keeps CI times reasonable

**Implementation:**
```bash
file $FFMPEG_BIN | grep -q "$EXPECTED_ARCH" || exit 1
```

### Decision 10: npm packages per platform (sharp-libvips pattern)

**What:** Publish separate npm packages per platform-license combination using `os`, `cpu`, and `libc` fields for automatic platform selection.

**Why:**
- Follows proven sharp-libvips pattern used by millions of downloads
- npm automatically installs only the matching platform package via optionalDependencies
- `libc` field distinguishes glibc from musl (npm 9.4.0+)
- No runtime platform detection code needed
- Users only download binaries for their platform

**Package structure:**
```
@pproenca/ffmpeg-linux-x64       # glibc x64
@pproenca/ffmpeg-linux-arm64     # glibc ARM64
@pproenca/ffmpeg-linuxmusl-x64   # musl x64
@pproenca/ffmpeg-linuxmusl-arm64 # musl ARM64
...
```

**Platform package.json example (linux-x64):**
```json
{
  "name": "@pproenca/ffmpeg-linux-x64",
  "os": ["linux"],
  "cpu": ["x64"],
  "libc": ["glibc"]
}
```

**Platform package.json example (linuxmusl-x64):**
```json
{
  "name": "@pproenca/ffmpeg-linuxmusl-x64",
  "os": ["linux"],
  "cpu": ["x64"],
  "libc": ["musl"]
}
```

**Consumer package optionalDependencies:**
```json
{
  "optionalDependencies": {
    "@pproenca/ffmpeg-darwin-arm64": "0.2.0",
    "@pproenca/ffmpeg-darwin-x64": "0.2.0",
    "@pproenca/ffmpeg-linux-x64": "0.2.0",
    "@pproenca/ffmpeg-linux-arm64": "0.2.0",
    "@pproenca/ffmpeg-linuxmusl-x64": "0.2.0",
    "@pproenca/ffmpeg-linuxmusl-arm64": "0.2.0"
  }
}
```

**Note:** Following sharp-libvips, musl platforms use `linuxmusl-` prefix (not `linux-x64-musl`) to match npm's platform resolution expectations.
