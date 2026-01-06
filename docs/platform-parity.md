# Platform Parity Requirements

This document defines the parity requirements between darwin-arm64 and darwin-x64 platforms to ensure consistent behavior and maintainability.

## Configuration Parity Matrix

| Component | darwin-arm64 | darwin-x64 | Notes |
|-----------|--------------|------------|-------|
| `PKG_CONFIG_LIBDIR` | ✓ | ✓ | Both use LIBDIR (not PATH) for isolation |
| `CMAKE_SYSTEM_PROCESSOR` | N/A (native) | `x86_64` | Required for cross-compilation |
| `CMAKE_OSX_ARCHITECTURES` | `arm64` | `x86_64` | Per-platform |
| Meson cross-file | N/A (native) | `x86_64-darwin.ini` | Required for cross-compilation |
| NASM build | Homebrew | Source (x86_64) | darwin-x64 needs Rosetta 2 |
| `--host` flag (autoconf) | N/A (native) | `x86_64-apple-darwin` | Required for x264, etc. |
| Binary verification | ✓ | ✓ | Both verify in build.sh |
| CI verification step | ✓ | ✓ | Both verify in workflow |

## Files That Must Stay In Sync

When modifying one platform, check if the same change is needed on the other:

### Configuration Files
| File | darwin-arm64 | darwin-x64 |
|------|--------------|------------|
| `config.mk` | Platform-specific flags | Platform-specific flags + cross-compile flags |
| `Makefile` | Codec stamps, FFmpeg build | Same + NASM dependency |
| `build.sh` | Verify arm64 | Verify x86_64 |

### Codec Files (Must Match Structure)
```
platforms/darwin-arm64/codecs/
├── bsd/
│   ├── aom.mk
│   ├── dav1d.mk
│   ├── libvpx.mk
│   ├── ogg.mk
│   ├── opus.mk
│   ├── svt-av1.mk
│   └── vorbis.mk
├── gpl/
│   ├── x264.mk
│   └── x265.mk
├── lgpl/
│   └── lame.mk
└── codec.mk

platforms/darwin-x64/codecs/
├── (same structure)
└── (+ cross-compilation flags where needed)
```

## Cross-Compilation Specific (darwin-x64 only)

These files/features exist only in darwin-x64:

| File | Purpose |
|------|---------|
| `tools/nasm.mk` | Build x86_64 NASM from source |
| `x86_64-darwin.ini` | Meson cross-file |

## Parity Checklist for New Features

When adding a feature to one platform:

- [ ] Does the other platform need the same feature?
- [ ] Are configuration variables consistent?
- [ ] Are environment variables exported consistently?
- [ ] Does darwin-x64 need additional cross-compilation flags?
- [ ] Is the feature documented in both platforms' config.mk?

## Known Differences (Intentional)

| Difference | Reason |
|------------|--------|
| `MACOSX_DEPLOYMENT_TARGET` | 11.0 (arm64) vs 10.15 (x64) - different minimum OS versions |
| Cross-compilation machinery | darwin-x64 needs extra flags/tools because host ≠ target |
| NASM source | darwin-x64 needs x86_64 NASM; darwin-arm64 uses Homebrew |

## Enforcement

1. **Linting**: Consider adding a script to detect common parity issues
2. **Code Review**: Check both platforms when reviewing PRs
3. **CI Matrix**: Both platforms build in CI to catch divergence early

## Historical Issues

These bugs resulted from platform parity drift:

| Bug | Cause | Fix |
|-----|-------|-----|
| PKG_CONFIG_PATH vs LIBDIR | darwin-arm64 used PATH, darwin-x64 used LIBDIR | Standardized on LIBDIR |
| Missing architecture verification | darwin-arm64 had it, darwin-x64 didn't | Added to both |

## Migration Notes

### Adding a New Platform

When adding a new platform (e.g., `linux-x64`, `linux-arm64`):

1. Copy closest existing platform as template
2. Update architecture-specific variables
3. Add cross-compilation support if needed
4. Ensure PKG_CONFIG uses LIBDIR
5. Add architecture verification to build.sh
6. Add to CI matrix
7. Update this document
