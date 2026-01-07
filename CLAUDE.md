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
workflow_dispatch ──► release.yml ──► Check for CI artifacts
(bump_type dropdown)       │                  │
                           │          ┌───────┴───────┐
                           │          ▼               ▼
                           │       Found?          Missing?
                           │          │               │
                           │          ▼               ▼
                           │      Download         FAIL
                           │          │          (must wait for CI)
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
| `release.yml` | Manual dispatch with bump_type | One-click release: creates tag, reuses CI artifacts, publishes |

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
  3. Search for successful CI run at that commit
  4. If artifacts found: download from CI run
  5. If artifacts missing/expired: **FAIL** (push to master and wait for CI first)
  6. Create git tag and push to origin
  7. Create GitHub Release with auto-generated notes
  8. Publish artifacts to GitHub Release and npm with provenance
- **Re-release:** Enter existing tag in the optional `tag` field to republish

### One-Click Release

**Via GitHub UI (recommended):**
1. Go to **Actions** → **Release** workflow
2. Click **Run workflow**
3. Select bump type: `patch`, `minor`, or `major`
4. Click **Run workflow**

The workflow automatically:
- Calculates new version (e.g., 0.1.3 → 0.1.4 for patch)
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

## Adding a New Codec

1. Create `platforms/<platform>/codecs/<codec>.mk`
2. Add version/URL/SHA256 to `shared/versions.mk`
3. Add to `CODEC_STAMPS` in platform `Makefile`
4. Add `--enable-lib<codec>` to FFmpeg configure

## Adding a New Platform

1. Create `platforms/<os>-<arch>/` directory
2. Copy and adapt `Makefile`, `config.mk`, `build.sh` from existing platform
3. Adjust compiler flags, SDK paths, and codec build recipes for platform specifics

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
