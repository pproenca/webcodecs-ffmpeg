# Change: Disable LTO for SVT-AV1 on musl Builds

## Why

SVT-AV1 enables Link-Time Optimization (LTO) by default when compiled with GCC. On Alpine Linux (musl), linking FFmpeg against SVT-AV1 libraries built with LTO fails because musl's GCC toolchain lacks the LTO plugin (`liblto_plugin.so`). This causes CI failures for the `linuxmusl-x64` platform when consumers attempt to link against the published npm packages.

Error symptom:
```
lto1: fatal error: bytecode stream in file 'libSvtAv1Enc.a' generated with LTO version X.Y instead of the expected X.Z
```

## What Changes

- Add `-DSVT_AV1_LTO=OFF` to SVT-AV1 CMake configuration specifically for musl builds
- Introduce platform-specific CMake override mechanism (`CMAKE_CODEC_OPTS`) for codec-specific flags

## Impact

- **Affected specs**: None (build system configuration, no spec changes)
- **Affected code**:
  - `platforms/linuxmusl-x64/config.mk` - Add SVT-AV1 LTO disable flag
  - `shared/codecs/bsd/svt-av1.mk` - Consume platform-specific CMake options

## Scope

- **Platform**: `linuxmusl-x64` only (other platforms are unaffected)
- **Codec**: SVT-AV1 only
- **License tiers**: Both `free` and `non-free` (SVT-AV1 is in BSD tier)

## Problems Solved

1. **CI failures**: `linuxmusl-x64` builds will complete successfully
2. **Consumer linking**: npm package consumers on Alpine Linux can link against the libraries without LTO plugin requirements
3. **Compatibility**: Ensures binaries work across GCC versions without strict LTO version matching

## Alternatives Considered

1. **Install GCC LTO plugin on Alpine** - Rejected: Fragile, requires matching GCC versions between build and link time
2. **Disable LTO globally via CFLAGS** - Rejected: Overly broad, may impact performance on other codecs
3. **Platform-specific SVT-AV1 recipe** - Rejected: Creates duplication, harder to maintain

## Release

Publish as `@pproenca/webcodecs-ffmpeg-linux-x64-musl@0.1.5` after verification.
