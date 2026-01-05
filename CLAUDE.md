# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

FFmpeg Prebuilds is a build and distribution system for static FFmpeg binaries packaged as npm modules. It builds FFmpeg with comprehensive codec support across multiple platforms and distributes them as:
- Runtime packages (`@pproenca/ffmpeg-*`) - FFmpeg/ffprobe binaries
- Development packages (`@pproenca/ffmpeg-dev-*`) - Static libraries + headers
- Main meta-package (`@pproenca/ffmpeg`) - Auto-detects platform

## Commands

### Build Commands
```bash
# Build for a specific platform
./build/orchestrator.sh darwin-arm64   # macOS Apple Silicon
./build/orchestrator.sh darwin-x64     # macOS Intel
./build/orchestrator.sh linux-x64-glibc  # Linux (via Docker)
./build/orchestrator.sh linux-x64-musl   # Linux musl (via Docker)
./build/orchestrator.sh windows-x64      # Windows (via Docker)

# Create macOS universal binary (after building both darwin-x64 and darwin-arm64)
./build/create-universal.sh

# Verify build artifacts
./build/verify.sh darwin-arm64
```

### NPM Scripts
```bash
npm install                    # Install dev dependencies
npm test                       # Run TypeScript tests (Node.js test runner)
npm run package                # Create npm packages from artifacts/
npm run verify                 # Verify build artifacts
npm run gen                    # Generate docs tables and build-config.json
npm run gen:docs               # Regenerate auto-generated doc sections
npm run check:docs             # Validate documentation consistency
npm run versions               # Check for dependency updates (dry-run)
npm run versions:write         # Apply version updates to versions.properties
```

### Testing
```bash
# Full test suite (requires built artifacts)
./tests/run-all-tests.sh

# Test specific platform
./tests/run-all-tests.sh --platform linux-x64-glibc

# Regenerate test fixtures
./tests/run-all-tests.sh --fixtures
```

### Linting (via mise)
```bash
mise run lint-workflows     # Lint GitHub Actions with actionlint
mise run lint-dockerfiles   # Lint Dockerfiles with hadolint
```

## Architecture

### Build Flow
```
orchestrator.sh (entry point)
├── Loads versions.properties (all dependency versions)
├── Routes to platform builder:
│   ├── macos.sh → Native Xcode build
│   ├── linux.sh → Docker build
│   └── windows.sh → Docker cross-compile (MinGW)
└── Outputs to artifacts/<platform>/{bin,lib,include}
```

### Key Files
- `versions.properties` - **Single source of truth** for all codec/library versions. Edit here to update dependencies; bump `CACHE_VERSION` to invalidate CI caches.
- `scripts/lib/platforms.ts` - Platform definitions (os, cpu, libc, hwAccel)
- `scripts/lib/dependencies.ts` - Dependency metadata registry
- `build-config.json` - Default full build configuration
- `presets/*.json` - Build presets (minimal, streaming, full)

### Platform Support
| Platform | Build Method | Notes |
|----------|--------------|-------|
| darwin-x64/arm64 | Native (Xcode) | Combined into universal binary |
| linux-*-glibc | Docker (Ubuntu 24.04) | glibc 2.35+ |
| linux-*-musl | Docker (Alpine 3.21) | Fully static |
| windows-x64 | Docker (MinGW) | Cross-compiled from Linux |

### Hardware Acceleration Variants
- `linux-x64-glibc-vaapi` - Intel/AMD GPU
- `linux-x64-glibc-nvenc` - NVIDIA GPU
- `windows-x64-dxva2` - Windows GPU decode
- macOS includes VideoToolbox by default

## Code Organization

```
build/               # Shell scripts for building FFmpeg
  orchestrator.sh    # Main entry point
  macos.sh           # macOS native builds
  linux.sh           # Docker-based Linux builds
  windows.sh         # Windows cross-compile
  verify.sh          # ABI/binary validation
  patches/           # Patches for codec compatibility (x265 ARM64)
platforms/           # Dockerfiles for each platform
scripts/             # TypeScript utilities
  package-npm.ts     # Creates npm packages from artifacts
  generate-docs.ts   # Auto-generates README tables
  lib/platforms.ts   # Platform definitions
  lib/dependencies.ts # Dependency metadata
tests/               # Functional test suite
  run-all-tests.sh   # Test runner
  encode-tests.sh    # Codec encoding validation
  decode-tests.sh    # Format support tests
  performance-tests.sh # Benchmarks
artifacts/           # Build outputs (gitignored)
npm-dist/            # Generated npm packages (gitignored)
```

## Version Updates

1. Run `npm run versions` to check for updates
2. Edit `versions.properties` (or use `npm run versions:write`)
3. Increment `CACHE_VERSION` in `versions.properties`
4. Test locally: `./build/orchestrator.sh <platform>`
5. Tag and push to trigger CI build

## CI/CD

- `build.yml` - Matrix builds all platforms in parallel (~30min)
- `release.yml` - Triggered by `v*` tags; publishes to npm with OIDC provenance

## Conventions

- All builds are static-linked (no external dependencies)
- Shell scripts follow ShellCheck conventions
- TypeScript uses ESM (`"type": "module"`)
- Auto-generated doc sections are marked with `<!-- AUTO-GENERATED:section:START/END -->`
- Commit messages follow Conventional Commits (`feat:`, `fix:`, `chore:`, etc.)

## License

GPL-2.0-or-later (due to x264/x265 dependencies)
