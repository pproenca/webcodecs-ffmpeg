## MODIFIED Requirements

### Requirement: Cross-Compilation Support

Linux ARM64 platform MUST cross-compile from x86_64 host to aarch64 target using the `aarch64-linux-gnu-*` toolchain.

All autoconf-based codec builds (opus, ogg, vorbis, lame) MUST pass `--host=aarch64-linux-gnu` to configure when `HOST_TRIPLET` is defined in platform config, enabling proper cross-compilation without attempting to execute target binaries.

#### Scenario: Opus builds successfully on linux-arm64
- **GIVEN** platform is linux-arm64 with `HOST_TRIPLET=aarch64-linux-gnu`
- **WHEN** opus codec is built via `make opus.stamp`
- **THEN** configure detects cross-compilation and skips run tests
- **AND** opus.stamp is created successfully
- **AND** `libopus.a` is an aarch64 ELF binary

#### Scenario: Native builds unaffected
- **GIVEN** platform is darwin-arm64 with `HOST_TRIPLET` undefined
- **WHEN** opus codec is built via `make opus.stamp`
- **THEN** configure runs normally without `--host` flag
- **AND** opus.stamp is created successfully
