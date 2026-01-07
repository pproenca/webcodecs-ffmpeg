# Change: Fix Linux ARM64 Cross-Compilation

## Why

Linux ARM64 builds fail with `configure: error: cannot run C compiled programs` during opus codec build. The autoconf-based codecs (opus, ogg, vorbis, lame) don't pass `--host` flag when cross-compiling, causing configure to attempt running ARM64 binaries on x86_64 host.

## Root Cause Analysis

From build logs:
```
checking build system type... x86_64-pc-linux-gnu
checking host system type... x86_64-pc-linux-gnu    ← WRONG: should be aarch64-linux-gnu
checking for gcc... aarch64-linux-gnu-gcc
checking whether the C compiler works... yes
configure: error: cannot run C compiled programs.
If you meant to cross compile, use `--host'.
```

The configure script detects it's running on x86_64, compiles a test program using `aarch64-linux-gnu-gcc` (producing ARM64 binary), then fails when trying to execute that ARM64 binary on the x86_64 host.

## What Changes

1. **Add `HOST_TRIPLET` variable** to `linux-arm64/config.mk` (already exists: `aarch64-linux-gnu`)
2. **Update autoconf codec recipes** to pass `--host=$(HOST_TRIPLET)` when `HOST_TRIPLET` is defined:
   - `shared/codecs/bsd/opus.mk`
   - `shared/codecs/bsd/ogg.mk`
   - `shared/codecs/bsd/vorbis.mk`
   - `shared/codecs/lgpl/lame.mk`

Note: `x264.mk` already has this pattern: `$(if $(X264_HOST),--host=$(X264_HOST))`

## Impact

- **Affected platforms**: linux-arm64 (and future cross-compiled platforms)
- **Affected codecs**: opus, ogg, vorbis, lame (autoconf-based)
- **No impact on**: darwin-* (native builds), linux-x64 (native build), cmake/meson codecs
- **Related change**: This unblocks `add-linux-builds` tasks 1.3.4-1.3.5 and 1.4.7

## Technical Details

For autoconf cross-compilation, three triplets matter:
- `--build`: where compilation happens (x86_64-pc-linux-gnu)
- `--host`: where binaries will run (aarch64-linux-gnu)
- `--target`: for compiler tools only (not needed here)

When `--host` differs from `--build`, autoconf knows to skip run tests.
