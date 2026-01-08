<!-- OPENSPEC:START -->
# OpenSpec Instructions

These instructions are for AI assistants working in this project.

Always open `@/openspec/AGENTS.md` when the request:
- Mentions planning or proposals (words like proposal, spec, change, plan)
- Introduces new capabilities, breaking changes, architecture shifts, or big performance/security work
- Sounds ambiguous and you need the authoritative spec before coding

Use `@/openspec/AGENTS.md` to learn:
- How to create and apply change proposals
- Spec format and conventions
- Project structure and guidelines

Keep this managed block so 'openspec update' can refresh the instructions.

<!-- OPENSPEC:END -->

# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

FFmpeg prebuilds - a modular build system for creating statically-linked FFmpeg binaries with codec dependencies for multiple platforms. Currently implements macOS ARM64 (darwin-arm64) with architecture designed for multi-platform expansion.

## Build Commands

### macOS ARM64 (darwin-arm64)

```bash
# Full build (codecs + FFmpeg + package)
cd platforms/darwin-arm64
./build.sh all

# Or directly with Make
make -j$(nproc) all
```

### Build Targets

```bash
make codecs        # Build all codec libraries
make ffmpeg        # Build FFmpeg (requires codecs)
make package       # Create distribution package
make verify        # Verify build (ffmpeg -version, architecture check)
make codecs-info   # Show codec build status
```

### Individual Codec Build

```bash
make x264.stamp    # Build specific codec (creates .stamp file on success)
```

### Clean

```bash
make clean         # Remove build directory
make distclean     # Remove build + artifacts
make codecs-clean  # Remove codec sources only
```

### Linting

```bash
mise run lint              # All linters
mise run lint:workflows    # GitHub Actions (actionlint)
mise run lint:docker       # Dockerfiles (hadolint)
```

### Local CI Testing

```bash
mise run act:validate      # Dry-run workflows
mise run act               # Run workflows locally
```

## CI/CD Workflows

The repository uses a reusable workflow architecture with artifact reuse to avoid duplicate builds:

### Workflow Structure

```
Push to master
     │
     ▼
  ci.yml ──────► _build.yml (6 jobs) ──► Artifacts (30-day retention)
                                              │
                                              │ (required for release)
                                              ▼
workflow_dispatch ──► release.yml ──► Wait for CI (if running)
(bump_type dropdown)       │                  │
                           │                  ▼
                           │          Check for CI artifacts
                           │                  │
                           │          ┌───────┴───────┐
                           │          ▼               ▼
                           │       Found?          Missing/Expired?
                           │          │               │
                           │          ▼               ▼
                           │      Download         FAIL
                           │          │
                           │          ▼
                           └─► Create tag + GitHub Release
                                      │
                                      ▼
                              Publish to npm + GitHub
```

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| `lint.yml` | PR to master | Land-blocking validation (actionlint, shellcheck, hadolint) |
| `_build.yml` | Called by other workflows | Reusable build logic (matrix, attestations, artifacts) |
| `ci.yml` | Push to master | Continuous builds, stores artifacts for 30 days |
| `release.yml` | Manual dispatch with bump_type | One-click release: waits for CI, creates tag, reuses CI artifacts, publishes |

### Reusable Build Workflow (`_build.yml`)

- **Trigger:** `workflow_call` from ci.yml
- **Inputs:** `ref` (git ref to build), `retention-days` (artifact retention)
- **Matrix:** 2 platforms × 3 licenses = 6 parallel jobs
- **Concurrency:** Per-platform groups with cancel-in-progress
- **Artifacts:** Tarballs + SHA256 checksums
- **Attestations:** SLSA build provenance generated per artifact

### CI Workflow (`ci.yml`)

- **Trigger:** Push to master, manual dispatch
- **Calls:** `_build.yml` with 30-day artifact retention
- **Concurrency:** `build-${{ github.sha }}` with cancel-in-progress
- **Purpose:** Verify builds work on every commit, produce reusable artifacts

### Release Workflow (`release.yml`)

- **Trigger:** `workflow_dispatch` with bump_type dropdown (patch/minor/major)
- **Artifact requirement:** FAILS if no CI artifacts exist (no fallback build)
- **Steps:**
  1. Calculate new version from latest tag based on bump_type
  2. Find HEAD commit
  3. Wait for CI workflow to complete (if still running)
  4. Search for successful CI run at that commit
  5. If artifacts found: download from CI run
  6. If artifacts missing/expired: **FAIL** (re-run CI workflow first)
  7. Create git tag and push to origin
  8. Create GitHub Release with auto-generated notes
  9. Publish artifacts to GitHub Release and npm with provenance
- **Re-release:** Enter existing tag in the optional `tag` field to republish

### One-Click Release

**Via GitHub UI (recommended):**
1. Go to **Actions** → **Release** workflow
2. Click **Run workflow**
3. Select bump type: `patch`, `minor`, or `major`
4. Click **Run workflow**

The workflow automatically:
- Calculates new version (e.g., 0.1.3 → 0.1.4 for patch)
- Waits for CI to complete (if still running)
- Verifies CI artifacts exist at HEAD
- Creates and pushes git tag
- Creates GitHub Release with auto-generated notes
- Publishes to npm with provenance

**Re-release existing tag:**
- Enter existing tag in the `tag` field (e.g., `v0.1.4`)
- Leave bump_type as default
- Workflow skips tag/release creation, only republishes to npm

**Local version bump (optional):**
```bash
# Create tag locally without releasing
mise run bump:patch  # or bump:minor, bump:major
git push origin v0.x.x
```

**Note:** Version bumping only creates a git tag. The `package.json` versions are
injected at publish time from the tag name via `populate-npm.sh`. This avoids
creating "chore(release)" commits that would trigger duplicate CI builds.

### Artifact Naming Convention

```
ffmpeg-{platform}-{license}.tar.gz
ffmpeg-{platform}-{license}.tar.gz.sha256
```

Example: `ffmpeg-darwin-arm64-gpl.tar.gz`

## Architecture

### Directory Structure

```
platforms/<os>-<arch>/     # Platform-specific builds
├── Makefile               # Build orchestrator
├── build.sh               # CI entry point
├── config.mk              # Compiler/SDK configuration
└── codecs/                # Individual codec recipes
    ├── codec.mk           # Common patterns
    └── <codec>.mk         # Per-codec build recipe

shared/                    # Cross-platform utilities
├── common.mk              # Reusable Make functions
└── versions.mk            # Centralized dependency versions
```

### Makefile Hierarchy

1. `platforms/<platform>/Makefile` - Main entry, defines targets
2. `shared/versions.mk` - Single source of truth for versions/URLs
3. `platforms/<platform>/config.mk` - Compiler flags, SDK paths
4. `codecs/codec.mk` - Common codec patterns
5. `codecs/<name>.mk` - Per-codec build recipe

### Build Patterns

**Stamp files**: Each codec creates a `.stamp` file on success for incremental builds.

**Build systems supported**:
- Autoconf: `$(call autoconf_build,...)` - opus, vorbis, ogg, lame, x264, libvpx
- CMake: `$(call cmake_build,...)` - aom, x265, svt-av1
- Meson: `$(call meson_build,...)` - dav1d

**Common functions** (from `shared/common.mk`):
- `download_and_extract` - Fetch and cache tarballs
- `git_clone` - Clone repos at specific versions
- `verify_static_lib` / `verify_pkgconfig` - Build verification

### Codec License Categories

| License | Codecs | FFmpeg Flag |
|---------|--------|-------------|
| BSD | libvpx, aom, dav1d, svt-av1, opus, ogg, vorbis | (default) |
| LGPL | lame | (default) |
| GPL | x264, x265 | `--enable-gpl` |

### Version Management

All versions, URLs, and SHA256 checksums are in `shared/versions.mk`. Bump `CACHE_VERSION` to invalidate CI cache.

### Shared Codec System

Codec build recipes are centralized in `shared/codecs/` to eliminate duplication:

```
shared/codecs/
├── codec.mk           # License tier configuration
├── pkgconfig.mk       # Templated pkg-config generation
├── bsd/               # BSD-licensed codecs (7)
├── lgpl/              # LGPL-licensed codecs (1)
└── gpl/               # GPL-licensed codecs (2)
```

**Platform-Specific Variables** (set in `platforms/*/config.mk`):

| Variable | Description | Example (arm64) | Example (x64) |
|----------|-------------|-----------------|---------------|
| `LIBVPX_TARGET` | libvpx target triplet | arm64-darwin23-gcc | x86_64-darwin19-gcc |
| `X264_HOST` | x264 host triplet | (empty) | x86_64-apple-darwin |
| `AOM_TARGET_CPU` | aom CPU target | (empty) | x86_64 |
| `ARCH_VERIFY_PATTERN` | Architecture verification | arm64 | x86_64 |

## Adding a New Codec

1. Create `platforms/<platform>/codecs/<codec>.mk`
2. Add version/URL/SHA256 to `shared/versions.mk`
3. Add to `CODEC_STAMPS` in platform `Makefile`
4. Add `--enable-lib<codec>` to FFmpeg configure

## Adding a New Platform

1. Create `platforms/<os>-<arch>/` directory
2. Copy and adapt `Makefile`, `config.mk`, `build.sh` from existing platform
3. Adjust compiler flags, SDK paths, and codec build recipes for platform specifics

### Native vs Cross-Compilation Decision

**Prefer native runners** when available. Cross-compilation is fragile:

| Approach | Pros | Cons |
|----------|------|------|
| Native runner | Reliable, simpler config | May cost more, limited availability |
| Cross-compile | One runner type | 8+ fixes needed for darwin-x64, PKG_CONFIG issues, arch detection failures |

**darwin-x64 case study:** Started with cross-compilation from ARM runner. Required fixes for:
- CMake architecture flags not propagating
- x264 auto-detecting wrong architecture
- NASM version incompatibility (had to build from source)
- PKG_CONFIG_LIBDIR isolation failures

**Resolution:** Switched to native Intel runner (`macos-13`). Slower but reliable.

**When cross-compilation is unavoidable:**
1. Use wrapper scripts for environment variables (not exports)
2. Add architecture verification to `make verify`
3. Test in CI before merging

## FFmpeg Skill

Use `/dev-ffmpeg` skill for guidance on FFmpeg compilation decisions including license compliance, codec selection, and platform-specific configuration. Reference docs in `.claude/skills/dev-ffmpeg/references/`.

## Researching FFmpeg Build Issues

When encountering build problems or validating configuration decisions, consult official FFmpeg sources:

**Primary Sources (in order of priority):**
1. `https://ffmpeg.org/pipermail/ffmpeg-devel/` - Developer mailing list archives (search by year/month)
2. `https://trac.ffmpeg.org/` - Bug tracker and wiki
3. `https://ffmpeg.org/general.html` - External library requirements
4. `https://ffmpeg.org/platform.html` - Platform-specific notes
5. `https://ffmpeg.org/security.html` - CVE patches and security updates

**Research Process:**
1. Search ffmpeg-devel archives for the specific issue (e.g., "x265 static linking")
2. Check trac.ffmpeg.org for related tickets
3. Verify configure flags against general.html documentation
4. Document findings and sources in commit messages

**Common Gotchas (FFmpeg 7+):**
- x265 static linking requires `--extra-libs=-lc++` (broken .pc file)
- Use `--pkg-config-flags="--static"` for static builds
- NASM required for x86 assembly (YASM deprecated)
- Channel layout API changed - old bitmask API removed

## Bug Pattern Prevention

Lessons from iterative fixes in this codebase. Follow these to avoid repeat mistakes.

### Environment Variables Don't Cross Process Boundaries

**Problem:** `export PKG_CONFIG_LIBDIR=x` doesn't propagate when configure spawns subprocesses, especially in Docker containers.

**Wrong:**
```bash
export PKG_CONFIG_LIBDIR="$BUILD_DIR/lib/pkgconfig"
./configure  # spawns child processes that lose the env
```

**Wrong (Makefile):**
```makefile
cd $(SRC) && \
    export PKG_CONFIG_LIBDIR="$(PREFIX)/lib/pkgconfig" && \
    ./configure ...  # subshell export doesn't propagate reliably
```

**Right:** Use inline environment variable prefix:
```makefile
cd $(SRC) && \
    PKG_CONFIG_LIBDIR="$(PREFIX)/lib/pkgconfig" \
    ./configure ...  # inline prefix propagates to all child processes
```

**Alternative:** Use wrapper scripts that set env per-invocation:
```bash
PKG_CONFIG="$BUILD_DIR/pkg-config-wrapper.sh" ./configure
```

**Before proposing env-based fixes:** Trace full process tree. Ask: "Does this survive `sh -c`?"

**Docker-specific:** Environment isolation is stricter in containers. Always use inline prefixes instead of `export` when running builds in Docker.

### Verify Architecture, Don't Trust Build Flags

**Problem:** Cross-compilation flags can silently produce wrong-arch binaries.

**Rule:** Every build must end with architecture verification:
```bash
file "$BINARY" | grep -q "$EXPECTED_ARCH" || exit 1
```

**Why native > cross-compile:** darwin-x64 required 8+ fixes for cross-compilation. Switched to native Intel runner (`macos-13`) - slower but reliable. Cross-compile only when native runners unavailable.

### Understand Root Cause Before Fixing

**Anti-pattern:** 4 commits in 45 minutes fixing the same PKG_CONFIG issue from different angles.

**Before committing a fix:**
1. Reproduce the failure locally
2. Trace backwards to root cause (not just symptoms)
3. Verify fix addresses root cause, not downstream effect
4. Test that fix survives edge cases (subprocesses, different shells)

### CI/CD Race Conditions Need Retry, Not Sleep

**Problem:** npm E409 conflicts when publishing multiple packages.

**Wrong:** `sleep 2` between publishes (timing-dependent, fragile)

**Right:** Retry with backoff on known transient errors:
```bash
for attempt in 1 2 3; do
  npm publish && break
  sleep $((attempt * 5))
done
```

### CMake 4.x Breaks Codec Builds

aom, x265, svt-av1 require CMake 3.x. Pin version:
```bash
pip3 install 'cmake>=3.20,<4'
```

Monitor upstream for fixes before upgrading.

### Autoconf Cross-Compilation Requires --host Flag

**Problem:** Autoconf configure scripts try to run compiled test programs. When cross-compiling (e.g., x86_64 → aarch64), the compiled binary can't execute on the build host.

**Error signature:**
```
checking host system type... x86_64-pc-linux-gnu    ← WRONG
configure: error: cannot run C compiled programs.
If you meant to cross compile, use `--host'.
```

**Solution:** Pass `--host` to configure when `HOST_TRIPLET` is defined:
```makefile
./configure \
    --prefix=$(PREFIX) \
    $(if $(HOST_TRIPLET),--host=$(HOST_TRIPLET)) \
    CFLAGS="$(CFLAGS)"
```

**Affected codecs:** All autoconf-based (opus, ogg, vorbis, lame, x264). CMake and Meson codecs handle cross-compilation differently.

### FFmpeg Cross-Prefix Disables pkg-config

**Problem:** FFmpeg's configure prepends `--cross-prefix` to pkg-config binary name. If `aarch64-linux-gnu-pkg-config` doesn't exist, pkg-config is silently disabled.

**Error signature:**
```
PKG_CONFIG_LIBDIR="/build/prefix/lib/pkgconfig" ./configure \
    --cross-prefix=aarch64-linux-gnu- --enable-libaom ...
ERROR: aom >= 2.0.0 not found using pkg-config
```

**Root cause:** FFmpeg computes `pkg_config = ${cross_prefix}pkg-config`:
```bash
# Inside FFmpeg configure:
pkg_config_default="${cross_prefix}${pkg_config_default}"
# Result: aarch64-linux-gnu-pkg-config (doesn't exist in Docker)
if ! $pkg_config --version; then
    pkg_config=false  # Silently disabled!
```

**Solution:** Explicitly override the pkg-config binary:
```makefile
./configure \
    --cross-prefix=aarch64-linux-gnu- \
    --pkg-config=pkg-config \        # Force native pkg-config
    --pkg-config-flags="--static" \
    ...
```

**Why this is safe:** `PKG_CONFIG_LIBDIR` still controls which `.pc` files are found. The native pkg-config only looks in our build prefix, maintaining cross-compilation isolation.

**Reference:** [FFmpeg-devel: Fix pkg-config detection with cross-prefix](https://ffmpeg.org/pipermail/ffmpeg-devel/2012-June/126683.html)

## Build System Guardrails

Layered verification to catch build issues early with actionable error messages. Defined in `shared/verify.mk`.

### Verification Layers

| Layer | When | What | Catches |
|-------|------|------|---------|
| 0. Parse-Time | Makefile parsing | Immutable refs, required vars | Mutable git refs causing stale cache |
| 1. Preflight | `make preflight` | Toolchain arch, pkg-config isolation | Wrong arch toolchain, env issues |
| 2. Post-Codec | After each codec builds | Library exists, correct arch | Silent build failures |
| 3. Pre-Configure | Before FFmpeg configure | All codecs available | Missing codecs before 30-min build |
| 4. Post-Build | `make verify` | Binary arch, static linkage | Runtime issues, dynamic deps |

### Running Preflight Checks

```bash
# Verify toolchain and environment before building
make -C platforms/darwin-arm64 preflight

# Preflight checks:
#   ✓ Toolchain produces correct architecture
#   ✓ pkg-config isolation (doesn't find system libs)
```

### Common Error Messages

**Wrong architecture toolchain:**
```
ERROR: Toolchain produces wrong architecture

  Diagnosis:
    Expected: aarch64
    Got: Mach-O 64-bit executable x86_64

  Fix: Check CC and CFLAGS in config.mk
       For cross-compile: verify CROSS_PREFIX is set
```

**Missing codec before FFmpeg:**
```
ERROR: Some codecs not available for FFmpeg

  [FAIL] x265 not found
  [OK] x264
  [OK] aom

  PKG_CONFIG_LIBDIR=/build/prefix/lib/pkgconfig

  Available .pc files:
    aom.pc
    x264.pc

  Fix: Build missing codecs first with 'make codecs'
```

**Mutable ref in versions.mk:**
```
*** x264 uses mutable ref 'stable'. Pin to commit hash for cache correctness.  Stop.
```

### Adding Verification to New Codecs

When adding a new codec, include post-build verification before the stamp:

```makefile
mycodec.stamp:
    # ... build steps ...
    $(call verify_static_lib,libmycodec,$(PREFIX))
    $(call verify_pkgconfig,mycodec,$(PREFIX))
    @touch $(STAMPS_DIR)/$@
```

### Platform-Specific Variables

Each platform's `config.mk` defines:

| Variable | Purpose | Example |
|----------|---------|---------|
| `ARCH_VERIFY_PATTERN` | Pattern for `file` command verification | `arm64`, `aarch64`, `x86-64` |
| `FFMPEG_EXTRA_LIBS` | Platform-specific link libraries | `-lpthread -lm -lc++` (darwin) |

Linux platforms require `-ldl` for x265's `dlopen()` usage:
```makefile
# platforms/linux-*/config.mk
FFMPEG_EXTRA_LIBS := -lpthread -lm -lstdc++ -ldl
```
