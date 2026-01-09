# macOS Build Capability

This capability defines requirements for building FFmpeg on macOS platforms (darwin-arm64, darwin-x64).

## ADDED Requirements

### Requirement: Native Build Configuration

macOS builds SHALL use native compilation when building on matching architecture runners.

#### Scenario: darwin-arm64 native build
- **WHEN** building darwin-arm64 on ARM64 macOS runner
- **THEN** FFmpeg configure SHALL NOT use `--enable-cross-compile`
- **AND** FFmpeg configure SHALL use `--arch=arm64`
- **AND** FFmpeg configure SHALL use `--target-os=darwin`
- **AND** produced binary SHALL be arm64 architecture

#### Scenario: darwin-x64 native build
- **WHEN** building darwin-x64 on Intel macOS runner
- **THEN** FFmpeg configure SHALL NOT use `--enable-cross-compile`
- **AND** FFmpeg configure SHALL use `--arch=x86_64`
- **AND** FFmpeg configure SHALL use `--target-os=darwin`
- **AND** produced binary SHALL be x86_64 architecture

### Requirement: Xcode CLI Tools Prerequisite

macOS builds SHALL verify Xcode Command Line Tools are installed before building.

#### Scenario: Xcode CLI tools present
- **WHEN** build.sh runs on macOS
- **AND** Xcode Command Line Tools are installed
- **THEN** build SHALL proceed to dependency installation

#### Scenario: Xcode CLI tools missing
- **WHEN** build.sh runs on macOS
- **AND** Xcode Command Line Tools are NOT installed
- **THEN** build SHALL fail immediately
- **AND** error message SHALL include `xcode-select --install` command

### Requirement: Hardware Acceleration Support

macOS builds SHALL enable Apple hardware acceleration frameworks.

#### Scenario: VideoToolbox enabled
- **WHEN** building FFmpeg for any macOS platform
- **THEN** FFmpeg configure SHALL use `--enable-videotoolbox`
- **AND** produced FFmpeg SHALL support VideoToolbox encoding/decoding

#### Scenario: AudioToolbox enabled
- **WHEN** building FFmpeg for any macOS platform
- **THEN** FFmpeg configure SHALL use `--enable-audiotoolbox`
- **AND** produced FFmpeg SHALL support AudioToolbox AAC encoding

### Requirement: Assembly Optimization

macOS builds SHALL enable assembly optimizations when appropriate tools are available.

#### Scenario: x264 with NASM
- **WHEN** building x264 codec
- **AND** NASM assembler is available
- **THEN** x264 configure SHALL detect and use NASM
- **AND** assembly optimizations SHALL be enabled

#### Scenario: x265 with CMake assembly
- **WHEN** building x265 codec
- **THEN** CMake SHALL use `-DENABLE_ASSEMBLY=ON`
- **AND** assembly optimizations SHALL be enabled

### Requirement: Build Tool Versions

macOS builds SHALL use compatible versions of build tools.

#### Scenario: CMake version constraint
- **WHEN** installing CMake for macOS builds
- **THEN** CMake version SHALL be >=3.20 and <4.0
- **AND** CMake 4.x SHALL NOT be used (breaks codec builds)

#### Scenario: NASM version for darwin-x64
- **WHEN** building darwin-x64
- **AND** system NASM is version 3.x or newer
- **THEN** build SHALL install NASM 2.x from source
- **AND** NASM 2.16.03 SHALL be used (NASM 3.x breaks libaom)

### Requirement: Documentation Accuracy

Build script documentation SHALL accurately reflect the build environment.

#### Scenario: darwin-x64 build.sh header
- **WHEN** darwin-x64/build.sh is executed
- **THEN** header comments SHALL state "Native Intel build"
- **AND** header comments SHALL NOT mention cross-compilation from ARM64
