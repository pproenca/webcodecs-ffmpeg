# Change: Fix Linux pkg-config Isolation for Cross-Compilation

## Why

Linux ARM64 builds fail with `ERROR: aom >= 2.0.0 not found using pkg-config` during FFmpeg configuration, despite libaom being successfully built and installed with a valid `.pc` file.

## Root Cause Analysis

From CI build logs (linux-arm64-bsd job, commit 4b9dbfb):
```
PKG_CONFIG_LIBDIR="/build/build/linux-arm64/prefix/lib/pkgconfig" \
./configure \
    --cross-prefix=aarch64-linux-gnu- \
    --enable-libaom ...
ERROR: aom >= 2.0.0 not found using pkg-config
```

The failure occurs **despite inline `PKG_CONFIG_LIBDIR` being correctly set**.

### The Real Root Cause: Cross-Prefixed pkg-config

When FFmpeg's configure sees `--cross-prefix=aarch64-linux-gnu-`, it prepends this prefix to **all** toolchain binaries, including pkg-config:

```bash
# From FFmpeg configure script:
pkg_config_default="${cross_prefix}${pkg_config_default}"
# Results in: aarch64-linux-gnu-pkg-config
```

The Docker container has `/usr/bin/pkg-config` but **not** `/usr/bin/aarch64-linux-gnu-pkg-config`. When FFmpeg can't find the prefixed binary, it silently disables pkg-config detection entirely:

```bash
if ! $pkg_config --version >/dev/null 2>&1; then
    warn "$pkg_config not found, library detection may fail."
    pkg_config=false
```

This means `PKG_CONFIG_LIBDIR` is never read because pkg-config is never invoked.

### Previous Fix Attempt (Insufficient)

Commit `4b9dbfb` changed from `export PKG_CONFIG_LIBDIR` to inline prefix. This was a valid improvement for subprocess propagation but **doesn't solve the core issue** of FFmpeg looking for the wrong pkg-config binary.

### Evidence

FFmpeg mailing list discussion confirms this behavior:
> "When a cross-prefix is used, FFmpeg searches for a cross-prefixed pkg-config, and fails to use pkg-config if none is found."

Source: [FFmpeg-devel patch for cross-prefix pkg-config](https://ffmpeg.org/pipermail/ffmpeg-devel/2012-June/126683.html)

## What Changes

**Solution: Force FFmpeg to use the native pkg-config binary**

Add `--pkg-config=pkg-config` to FFmpeg configure options:

```makefile
cd $(FFMPEG_SRC) && \
    PKG_CONFIG_LIBDIR="$(PREFIX)/lib/pkgconfig" \
    ./configure \
        --pkg-config=pkg-config \
        --pkg-config-flags="--static" \
        ...
```

This explicitly tells FFmpeg "use `/usr/bin/pkg-config`, not the cross-prefixed variant."

### Why This Is Safe

1. `PKG_CONFIG_LIBDIR` ensures pkg-config searches ONLY our build prefix
2. Host system libraries are never found (isolation is maintained)
3. Cross-compilation still works because we're only using pkg-config for `.pc` file lookup, not for binary compilation

### Files to Update

| File | Change |
|------|--------|
| `platforms/linux-arm64/Makefile` | Add `--pkg-config=pkg-config` to FFMPEG_CONFIGURE_OPTS |
| `platforms/linux-x64/Makefile` | Same (proactive, even though linux-x64 doesn't cross-compile) |

## Impact

- **Affected platforms**: linux-arm64, linux-x64 (Docker-based builds)
- **No impact on**: darwin-* (native builds without cross-prefix)
- **Unblocks**: All 6 Linux CI jobs (2 platforms × 3 licenses)

## Technical Details

### FFmpeg pkg-config Detection Flow

```
1. Configure reads --cross-prefix=aarch64-linux-gnu-
2. Computes pkg_config = aarch64-linux-gnu-pkg-config
3. Tests: aarch64-linux-gnu-pkg-config --version
4. Binary not found → pkg_config=false
5. All pkg-config library checks fail silently
6. "ERROR: aom >= 2.0.0 not found" even though aom.pc exists
```

### With Fix

```
1. Configure reads --pkg-config=pkg-config
2. Uses pkg_config = pkg-config (overrides cross-prefix behavior)
3. Tests: pkg-config --version → OK
4. PKG_CONFIG_LIBDIR ensures correct search path
5. Library checks succeed
```

## References

- [FFmpeg-devel: Fix pkg-config detection when using cross-prefix](https://ffmpeg.org/pipermail/ffmpeg-devel/2012-June/126683.html)
- [FFmpeg trac: CompilationGuide/Generic](https://trac.ffmpeg.org/wiki/CompilationGuide/Generic)
- [FFmpeg FAQ on cross-compilation](https://ffmpeg.org/faq.html)
