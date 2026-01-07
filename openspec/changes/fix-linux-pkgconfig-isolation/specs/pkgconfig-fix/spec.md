## MODIFIED Requirements

### Requirement: Cross-Compilation pkg-config Override (from linux-platform-support)

The build system SHALL explicitly specify the pkg-config binary to override FFmpeg's cross-prefix behavior.

#### Scenario: FFmpeg finds libraries despite cross-prefix

- **GIVEN** FFmpeg configure is invoked with `--cross-prefix=aarch64-linux-gnu-`
- **AND** the Docker container lacks `aarch64-linux-gnu-pkg-config`
- **WHEN** configure options include `--pkg-config=pkg-config`
- **THEN** FFmpeg uses `/usr/bin/pkg-config` instead of the non-existent prefixed variant
- **AND** library detection via pkg-config succeeds

#### Scenario: pkg-config isolation maintained with override

- **GIVEN** `--pkg-config=pkg-config` is specified
- **AND** `PKG_CONFIG_LIBDIR` is set inline to `$(PREFIX)/lib/pkgconfig`
- **WHEN** FFmpeg configure checks for libaom
- **THEN** pkg-config searches ONLY the build prefix
- **AND** system libraries in `/usr/lib/pkgconfig` are NOT found
- **AND** cross-compilation isolation is maintained

### Requirement: Cross-Compilation Support (from linux-platform-support)

The build system SHALL support cross-compiling for target architectures different from the build host, with proper pkg-config isolation in containerized environments.

#### Scenario: pkg-config finds cross-compiled libraries in Docker

- **GIVEN** build runs inside Docker container
- **AND** codec libraries are installed to `$(PREFIX)/lib/pkgconfig/`
- **AND** `--pkg-config=pkg-config` is passed to FFmpeg configure
- **WHEN** FFmpeg configure runs with `--enable-libaom`
- **THEN** pkg-config finds `aom.pc` at the correct prefix
- **AND** configure reports `aom >= 2.0.0 found`
- **AND** FFmpeg builds successfully with libaom support

#### Scenario: pkg-config does NOT find host system libraries

- **GIVEN** Docker container has system pkg-config files in `/usr/lib/pkgconfig`
- **AND** build targets aarch64 but runs on x86_64 host
- **AND** `PKG_CONFIG_LIBDIR` is set to build prefix only
- **WHEN** FFmpeg configure checks for libaom
- **THEN** pkg-config searches ONLY `$(PREFIX)/lib/pkgconfig`
- **AND** system paths are NOT searched
- **AND** wrong-architecture libraries are never linked

### Requirement: FFmpeg Configure Pattern

The FFmpeg configure command SHALL:
1. Set `PKG_CONFIG_LIBDIR` as an inline environment variable prefix
2. Pass `--pkg-config=pkg-config` to override cross-prefix binary selection

#### Scenario: Correct FFmpeg configure invocation

- **GIVEN** ffmpeg.stamp target in linux-arm64 Makefile
- **WHEN** the target executes
- **THEN** configure command includes:
  ```makefile
  PKG_CONFIG_LIBDIR="$(PREFIX)/lib/pkgconfig" ./configure \
      --pkg-config=pkg-config \
      --pkg-config-flags="--static" \
      --cross-prefix=aarch64-linux-gnu- \
      ...
  ```
- **AND** does NOT rely solely on environment variable for pkg-config selection
