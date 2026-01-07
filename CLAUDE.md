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

**Problem:** `export PKG_CONFIG_LIBDIR=x` doesn't propagate when configure spawns subprocesses.

**Wrong:**
```bash
export PKG_CONFIG_LIBDIR="$BUILD_DIR/lib/pkgconfig"
./configure  # spawns child processes that lose the env
```

**Right:** Use wrapper scripts that set env per-invocation:
```bash
PKG_CONFIG="$BUILD_DIR/pkg-config-wrapper.sh" ./configure
```

**Before proposing env-based fixes:** Trace full process tree. Ask: "Does this survive `sh -c`?"

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
