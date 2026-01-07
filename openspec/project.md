# Project Context

## Purpose

FFmpeg prebuilds - a modular build system for creating statically-linked FFmpeg binaries with codec dependencies for multiple platforms. Distributed as npm packages (`@pproenca/ffmpeg`, `@pproenca/ffmpeg-lgpl`, `@pproenca/ffmpeg-gpl`) for use in Node.js native addons.

**Goals:**
- Provide ready-to-use static FFmpeg libraries for native addon development
- Support multiple platforms (macOS ARM64/x64, Linux, Windows planned)
- Offer three license tiers (BSD, LGPL, GPL) with different codec sets
- Automate builds and releases via CI/CD

## Tech Stack

**Build System:**
- GNU Make (build orchestration, codec recipes)
- Shell scripts (Bash - CI entry points, packaging, version bumping)
- CMake, Meson, Autoconf (codec build systems)

**CI/CD:**
- GitHub Actions (reusable workflows for build, release)
- SLSA build provenance attestations

**Distribution:**
- npm (platform-specific packages with optional dependencies)

**Development Tools:**
- mise (task runner, tool versioning)
- actionlint (GitHub Actions linting)
- hadolint (Dockerfile linting)
- shellcheck (shell script linting)
- Node.js 22

## Project Conventions

### Code Style

**Makefiles:**
- Use `=` for recursive variables, `:=` for immediate assignment
- Sections separated by `# ===` comment banners
- Include descriptive header comments in each `.mk` file
- Use `$(call function_name,...)` for reusable patterns

**Shell Scripts:**
- Follow Google Shell Style Guide
- Use `set -euo pipefail` at script start
- Quote variables: `"${VAR}"`
- Use `[[` for conditionals (Bash)

**Naming:**
- Platforms: `<os>-<arch>` (e.g., `darwin-arm64`, `darwin-x64`)
- Artifacts: `ffmpeg-{platform}-{license}.tar.gz`
- Stamp files: `<codec>.stamp` for incremental builds

### Architecture Patterns

**Directory Structure:**
```
platforms/<os>-<arch>/     # Platform-specific builds
├── Makefile               # Build orchestrator (includes shared)
├── config.mk              # Platform compiler/SDK configuration
└── build.sh               # CI entry point

shared/                    # Cross-platform code
├── versions.mk            # Single source of truth for versions
├── common.mk              # Reusable Make functions
└── codecs/                # Centralized codec recipes
    ├── bsd/               # BSD-licensed (libvpx, aom, dav1d, etc.)
    ├── lgpl/              # LGPL-licensed (lame)
    └── gpl/               # GPL-licensed (x264, x265)
```

**Build Patterns:**
- Stamp files for dependency tracking and incremental builds
- Platform includes shared codecs; only `config.mk` differs
- License tiers: `LICENSE=bsd|lgpl|gpl` controls which codecs build

**CI/CD Architecture:**
- `_build.yml`: Reusable build workflow (matrix: 2 platforms × 3 licenses)
- `ci.yml`: Continuous builds on push to master, stores artifacts 30 days
- `release.yml`: One-click release - reuses CI artifacts, never rebuilds
- Concurrency groups prevent duplicate builds

### Testing Strategy

**Build Verification (in Makefile):**
- `make verify`: Runs after every build
  - `ffmpeg -version` output check
  - Architecture verification via `file` command
  - Static linkage verification via `otool -L`
  - Encoder presence checks

**CI Validation:**
- `lint.yml`: Land-blocking checks (actionlint, shellcheck, hadolint)
- `_build.yml`: Matrix builds with attestations
- Architecture verification catches cross-compilation failures

**No Unit Tests:** Build system - verification is "does FFmpeg work?"

### Git Workflow

**Branch Strategy:**
- `master` is the main branch
- Feature branches for development
- PRs required for changes (lint.yml blocks on failure)

**Commit Convention:** Conventional Commits
```
<type>(<scope>): <description>

Types: feat, fix, docs, refactor, revert, chore
Scopes: ci, npm, make, codecs, release, scripts, patterns
```

Examples from history:
- `feat(npm): add LICENSE files to all packages`
- `fix(release): publish npm packages sequentially to avoid E409`
- `refactor(make): centralize codec recipes to eliminate 50% duplication`
- `docs(patterns): add bug prevention guidance`

**Release Flow:**
1. Push to master triggers CI build
2. Manual dispatch of `release.yml` with bump type (patch/minor/major)
3. Workflow reuses CI artifacts (never rebuilds)
4. Creates git tag, GitHub Release, publishes to npm

## Domain Context

**FFmpeg License Tiers:**
| Tier | License | Codecs | FFmpeg Flag |
|------|---------|--------|-------------|
| BSD | BSD-3-Clause | libvpx, aom, dav1d, svt-av1, opus, ogg, vorbis | (default) |
| LGPL | LGPL-2.1+ | + lame (MP3) | (default) |
| GPL | GPL-2.0+ | + x264, x265 (H.264/H.265) | `--enable-gpl` |

**Static Linking Requirements:**
- All codec libraries must be built with `-fPIC`
- FFmpeg uses `--pkg-config-flags="--static"`
- x265 requires `--extra-libs=-lc++` (broken .pc file in FFmpeg 7+)

**Platform-Specific Variables:**
Each platform's `config.mk` sets: `LIBVPX_TARGET`, `X264_HOST`, `AOM_TARGET_CPU`, `ARCH_VERIFY_PATTERN`

## Important Constraints

**Technical:**
- CMake must be 3.x (CMake 4.x breaks aom, x265, svt-av1)
- Prefer native runners over cross-compilation (darwin-x64 required 8+ fixes)
- Environment variables don't propagate to subprocesses - use wrapper scripts
- npm E409 conflicts require sequential publishing with retry

**Security:**
- No credentials in tarballs or packages
- SLSA provenance attestations required for releases
- Monitor ffmpeg.org/security.html for CVE patches

**Licensing:**
- Package license determined by included codecs
- Users must comply with GPL if using x264/x265

## External Dependencies

**Codec Sources:**
- VideoLAN: x264, x265, dav1d (code.videolan.org, bitbucket)
- Google/WebM: libvpx (github.com/webmproject)
- AOMedia: libaom, SVT-AV1 (storage.googleapis.com, gitlab.com)
- Xiph: opus, ogg, vorbis (downloads.xiph.org)
- SourceForge: lame

**CI Services:**
- GitHub Actions (build runners: macos-14 ARM, macos-13 Intel)
- npm registry (@pproenca scope)

**Version Management:**
All versions, URLs, and checksums centralized in `shared/versions.mk`. Bump `CACHE_VERSION` to invalidate CI cache.
