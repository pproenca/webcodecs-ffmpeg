# Build Verification

Layered verification system that catches build issues early with actionable error messages.

## ADDED Requirements

### Requirement: Preflight Architecture Verification

The build system SHALL verify that the toolchain produces binaries with the correct target architecture BEFORE building any codec.

#### Scenario: Correct architecture detected
- **WHEN** `make preflight` is run on darwin-arm64
- **THEN** a test binary is compiled and verified to be arm64 architecture
- **AND** the preflight check passes

#### Scenario: Wrong architecture detected
- **WHEN** `make preflight` is run with a misconfigured cross-compiler
- **THEN** the build fails immediately with error message including:
  - Expected architecture pattern
  - Actual architecture from `file` command
  - Remediation hint pointing to config.mk

---

### Requirement: Codec Post-Build Verification

Each codec recipe SHALL verify that its static library and pkg-config file exist and are valid BEFORE creating the stamp file.

#### Scenario: Library verification passes
- **WHEN** x264 build completes successfully
- **THEN** verify_static_lib confirms libx264.a exists with correct architecture
- **AND** verify_pkgconfig confirms x264.pc resolves via pkg-config

#### Scenario: Missing library detected
- **WHEN** a codec build fails silently (exits 0 but no output)
- **THEN** verify_static_lib fails with error message including:
  - Expected library path
  - "Build may have failed silently"
  - No stamp file is created

#### Scenario: Wrong architecture library detected
- **WHEN** cross-compilation produces wrong-architecture library
- **THEN** verify_static_lib fails with error message including:
  - Expected architecture pattern
  - Actual architecture from `file` command
  - Hint to check CC and CFLAGS

---

### Requirement: FFmpeg Pre-Configure Codec Verification

The FFmpeg build SHALL verify that all required codecs are available via pkg-config BEFORE running FFmpeg configure.

#### Scenario: All codecs available
- **WHEN** `make ffmpeg LICENSE=gpl` is run after successful codec builds
- **THEN** verify_codecs_available lists each codec with ✓
- **AND** FFmpeg configure proceeds

#### Scenario: Missing codec detected
- **WHEN** `make ffmpeg LICENSE=gpl` is run but x264 build failed
- **THEN** build fails before FFmpeg configure with error including:
  - List of codecs checked (✓ for found, ✗ for missing)
  - PKG_CONFIG_LIBDIR value
  - List of available .pc files for debugging

---

### Requirement: Immutable Version References

The versions.mk file SHALL reject mutable Git references (branch names) at Make parse time.

#### Scenario: Commit hash accepted
- **WHEN** X264_VERSION is set to a 40-character commit hash
- **THEN** Make parses successfully

#### Scenario: Branch name rejected
- **WHEN** X264_VERSION is set to "stable" or "master"
- **THEN** Make fails at parse time with error:
  - "x264 uses mutable ref 'stable'"
  - "Pin to commit hash for cache correctness"

---

### Requirement: Actionable Error Messages

All verification failures SHALL provide diagnostic information that identifies the root cause, not just symptoms.

#### Scenario: Link failure diagnosed
- **WHEN** FFmpeg configure fails with "x265 not found using pkg-config"
- **AND** the actual cause is missing -ldl linker flag
- **THEN** the error message includes:
  - Whether x265.pc exists
  - Whether pkg-config can resolve x265
  - Link test output showing undefined symbols
  - Specific fix: "Add -ldl to FFMPEG_EXTRA_LIBS"

#### Scenario: pkg-config isolation failure
- **WHEN** FFmpeg finds system libraries instead of built libraries
- **THEN** verify_pkgconfig_isolation warns:
  - "pkg-config finds system libs (glib-2.0)"
  - PKG_CONFIG_LIBDIR value
  - "System libs may leak into build"

---

### Requirement: Platform-Specific Link Dependencies

Each platform configuration SHALL declare its required FFmpeg link libraries explicitly.

#### Scenario: Linux includes -ldl
- **WHEN** building on linux-arm64 or linux-x64
- **THEN** FFMPEG_EXTRA_LIBS includes -ldl
- **AND** x265 linking succeeds (dlopen/dlsym resolved)

#### Scenario: Darwin excludes -ldl
- **WHEN** building on darwin-arm64 or darwin-x64
- **THEN** FFMPEG_EXTRA_LIBS does NOT include -ldl
- **AND** x265 linking succeeds (dlopen in libSystem)
