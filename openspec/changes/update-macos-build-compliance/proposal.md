# Change: Align macOS Builds with FFmpeg Compilation Guide

## Why

The macOS builds (darwin-arm64, darwin-x64) have configuration inconsistencies when compared against FFmpeg's official macOS compilation guide (`docs/CompilationGuide_macOS.txt`). Specifically:

1. **darwin-arm64 uses `--enable-cross-compile` for native builds** - This flag is intended for cross-compilation scenarios. Using it on native ARM64 builds may cause FFmpeg to skip auto-detection of CPU features and use suboptimal code paths.

2. **darwin-x64 documentation is outdated** - The build.sh header says "cross-compiled from ARM64" but CI actually uses native Intel runners (`macos-15-intel`). This inconsistency creates confusion.

3. **Missing Xcode CLI tools verification** - The official guide requires Xcode Command Line Tools. Our build scripts don't verify this prerequisite.

4. **Assembly optimization verification** - Need to confirm NASM is properly detected for x264/x265 assembly optimizations.

## What Changes

### darwin-arm64 Platform
- **MODIFIED**: Remove `--enable-cross-compile` from FFmpeg configure options (native builds don't need it)
- **ADDED**: Explicit `--arch=arm64` without cross-compile mode
- **ADDED**: Verify Xcode CLI tools installation in build.sh

### darwin-x64 Platform
- **MODIFIED**: Update build.sh header comment to reflect native Intel builds
- **MODIFIED**: Remove platform verification code that mentions cross-compilation
- **ADDED**: Verify Xcode CLI tools installation in build.sh

### Build Verification
- **ADDED**: Log FFmpeg configure output showing detected CPU features and assembly status
- **ADDED**: Verify x264/x265 use NASM assembly (check configure output)

## Impact

- Affected specs: N/A (creating new `macos-build` capability spec)
- Affected code:
  - `platforms/darwin-arm64/Makefile` - FFmpeg configure options
  - `platforms/darwin-arm64/build.sh` - Xcode verification
  - `platforms/darwin-x64/build.sh` - Documentation and Xcode verification
- CI: No workflow changes needed (already uses native runners)

## Scope Justification

This is a **compliance and optimization fix**, not a feature change. The modifications:
1. Remove unnecessary flags that may inhibit optimizations
2. Fix misleading documentation
3. Add prerequisite verification per official FFmpeg guide

No breaking changes. Build artifacts remain compatible.
