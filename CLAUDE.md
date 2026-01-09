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

FFmpeg prebuilds - a modular build system for creating statically-linked FFmpeg binaries with codec dependencies. Supports macOS (ARM64, x64) and Linux (ARM64, x64).

## Build Commands

```bash
# Full build for any platform
cd platforms/<os>-<arch>
./build.sh all              # Or: make -j$(nproc) all

# Targets
make codecs                 # Build all codec libraries
make ffmpeg                 # Build FFmpeg (requires codecs)
make package                # Create distribution package
make verify                 # Verify build (architecture check)
make preflight              # Pre-build environment validation
make x264.stamp             # Build specific codec

# Clean
make clean                  # Remove build directory
make distclean              # Remove build + artifacts

# Lint & CI
mise run lint               # All linters (actionlint, shellcheck, hadolint)
mise run act:validate       # Dry-run workflows locally
```

## CI/CD Workflows

```
Push to master → ci.yml → _build.yml (8 jobs) → Artifacts (30-day)
                                                     ↓
bump-version.sh → push tag → release.yml → Download artifacts → Release + npm
```

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| `lint.yml` | PR to master | Land-blocking validation |
| `_build.yml` | workflow_call | Reusable build (4 platforms × 2 licenses) |
| `ci.yml` | Push to master | Continuous builds, stores artifacts |
| `release.yml` | Manual dispatch | Release existing tag, publish to npm |

**Release flow:**
1. Run `./scripts/bump-version.sh patch` (or minor/major)
2. Push: `git push origin master v0.7.0`
3. Actions → Release → Run workflow → Enter tag `v0.7.0`

**Version source of truth:** `npm/webcodecs-ffmpeg/package.json`

**Artifact naming:** `ffmpeg-{platform}-{license}.tar.gz` (e.g., `ffmpeg-darwin-arm64-free.tar.gz`)

## Architecture

```
platforms/<os>-<arch>/     # Platform-specific builds
├── Makefile               # Build orchestrator
├── build.sh               # CI entry point
├── config.mk              # Compiler/SDK configuration

shared/                    # Cross-platform
├── common.mk              # Reusable Make functions
├── versions.mk            # Centralized versions/URLs/SHA256
├── verify.mk              # Build verification guardrails
└── codecs/                # Shared codec recipes by license tier
    ├── bsd/               # libvpx, aom, dav1d, svt-av1, opus, ogg, vorbis
    ├── lgpl/              # lame
    └── gpl/               # x264, x265
```

### Build Patterns

**Stamp files:** Each codec creates `.stamp` on success for incremental builds.

**Build systems:** Autoconf (`autoconf_build`), CMake (`cmake_build`), Meson (`meson_build`)

**Common functions** (from `shared/common.mk`):
- `download_and_extract` / `git_clone` - Dependency fetching
- `verify_static_lib` / `verify_pkgconfig` - Post-build verification

### License Tiers

| Tier | Codecs | FFmpeg Flag | Use Case |
|------|--------|-------------|----------|
| `free` | libvpx, aom, dav1d, svt-av1, opus, ogg, vorbis, lame | (default) | Commercial/proprietary apps (LGPL-safe) |
| `non-free` | All above + x264, x265 | `--enable-gpl` | Open source projects (GPL-licensed) |

**Default is `free`** - safe for commercial use with LGPL compliance.

Use `LICENSE=non-free` to include GPL x264/x265 codecs.

## Adding Components

**New codec:**
1. Add version/URL/SHA256 to `shared/versions.mk`
2. Create `shared/codecs/<license>/<codec>.mk`
3. Add to `CODEC_STAMPS` in platform Makefile
4. Add `--enable-lib<codec>` to FFmpeg configure

**New platform:**
1. Create `platforms/<os>-<arch>/` with Makefile, config.mk, build.sh
2. Set platform variables in config.mk (see existing platforms)

## Package Management

Internal tooling uses **pnpm** for workspace management and publishing. Consumers install packages via npm/yarn/pnpm from the npm registry.

```bash
# Workspace operations (from npm/ directory)
pnpm install                  # Install dependencies
pnpm list -r                  # List all workspace packages
pnpm publish -r --dry-run     # Preview publishing

# Local development
./scripts/local-publish.sh --latest --version v0.1.0 --dry-run
```

Workspace configuration is in `npm/pnpm-workspace.yaml`.

## FFmpeg Skill

Use `/dev-ffmpeg` skill for guidance on FFmpeg compilation, license compliance, and platform-specific configuration. Reference docs in `.claude/skills/dev-ffmpeg/references/`.

## Researching Build Issues

**Primary sources:**
1. `https://ffmpeg.org/pipermail/ffmpeg-devel/` - Developer mailing list
2. `https://trac.ffmpeg.org/` - Bug tracker
3. `https://ffmpeg.org/general.html` - External library requirements

**FFmpeg 7+ gotchas:**
- x265 static linking requires `--extra-libs=-lc++` (broken .pc file)
- Use `--pkg-config-flags="--static"` for static builds
- NASM required for x86 assembly (YASM deprecated)

## Bug Pattern Prevention

### Environment Variables Don't Cross Process Boundaries

**Wrong:**
```makefile
cd $(SRC) && export PKG_CONFIG_LIBDIR="$(PREFIX)/lib/pkgconfig" && ./configure
```

**Right:** Use inline prefix (propagates to child processes):
```makefile
cd $(SRC) && PKG_CONFIG_LIBDIR="$(PREFIX)/lib/pkgconfig" ./configure
```

Docker-specific: Environment isolation is stricter. Always use inline prefixes.

### Verify Architecture, Don't Trust Build Flags

Cross-compilation flags can silently produce wrong-arch binaries. Every build must verify:
```bash
file "$BINARY" | grep -q "$EXPECTED_ARCH" || exit 1
```

**Native > cross-compile:** darwin-x64 required 8+ fixes for cross-compilation. Switched to native Intel runner (`macos-13`).

### Autoconf Cross-Compilation Requires --host

```makefile
./configure --prefix=$(PREFIX) $(if $(HOST_TRIPLET),--host=$(HOST_TRIPLET))
```

Affected: opus, ogg, vorbis, lame, x264

### FFmpeg Cross-Prefix Disables pkg-config

FFmpeg prepends `--cross-prefix` to pkg-config binary. Force native:
```makefile
./configure --cross-prefix=aarch64-linux-gnu- --pkg-config=pkg-config
```

### CMake 4.x Breaks Codec Builds

aom, x265, svt-av1 require CMake 3.x:
```bash
pip3 install 'cmake>=3.20,<4'
```

### CI Race Conditions Need Retry

npm registry E409 conflicts need retry with backoff:
```bash
for attempt in 1 2 3; do pnpm publish && break; sleep $((attempt * 5)); done
```

## Build System Guardrails

Layered verification defined in `shared/verify.mk`:

| Layer | When | Catches |
|-------|------|---------|
| 0. Parse-Time | Makefile parse | Mutable git refs |
| 1. Preflight | `make preflight` | Wrong arch toolchain, env issues |
| 2. Post-Codec | After each codec | Silent build failures |
| 3. Pre-Configure | Before FFmpeg | Missing codecs |
| 4. Post-Build | `make verify` | Wrong arch, dynamic deps |

**Common errors:**

Wrong architecture:
```
ERROR: Toolchain produces wrong architecture
  Fix: Check CC and CFLAGS in config.mk
```

Missing codec:
```
ERROR: Some codecs not available for FFmpeg
  Fix: Build missing codecs first with 'make codecs'
```

Mutable ref:
```
*** x264 uses mutable ref 'stable'. Pin to commit hash.
```

### Platform Variables

| Variable | Purpose | Example |
|----------|---------|---------|
| `ARCH_VERIFY_PATTERN` | Architecture verification | `arm64`, `aarch64`, `x86-64` |
| `FFMPEG_EXTRA_LIBS` | Link libraries | `-lpthread -lm -lc++` |

Linux requires `-ldl` for x265's `dlopen()`:
```makefile
FFMPEG_EXTRA_LIBS := -lpthread -lm -lstdc++ -ldl
```
