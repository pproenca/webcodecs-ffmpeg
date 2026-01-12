## ADDED Requirements

### Requirement: SVT-AV1 LTO Configuration

The build system SHALL support platform-specific LTO configuration for SVT-AV1 via the `SVTAV1_CMAKE_OPTS` variable.

#### Scenario: musl platform disables LTO
- **WHEN** building SVT-AV1 on `linuxmusl-x64` platform
- **THEN** LTO SHALL be disabled via `-DSVT_AV1_LTO=OFF`
- **AND** the resulting `libSvtAv1Enc.a` SHALL NOT contain LTO bytecode

#### Scenario: Other platforms retain default LTO behavior
- **WHEN** building SVT-AV1 on non-musl platforms (darwin-arm64, darwin-x64, linux-arm64, linux-x64)
- **THEN** `SVTAV1_CMAKE_OPTS` SHALL be empty by default
- **AND** SVT-AV1's default LTO behavior SHALL be preserved
