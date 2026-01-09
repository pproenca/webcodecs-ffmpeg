# npm Distribution

## ADDED Requirements

### Requirement: Package Naming Convention

All npm packages SHALL use the `@pproenca/webcodecs-ffmpeg` namespace pattern to indicate their relationship to the webcodecs ecosystem and provide FFmpeg attribution.

**Package structure:**
- Meta packages: `@pproenca/webcodecs-ffmpeg` (LGPL), `@pproenca/webcodecs-ffmpeg-non-free` (GPL)
- Platform packages: `@pproenca/webcodecs-ffmpeg-{os}-{arch}[-non-free]`

**Naming rationale:**
- `webcodecs-` prefix shows ecosystem relationship
- `ffmpeg` provides attribution to underlying technology
- `-non-free` suffix (Ubuntu/Debian convention) signals license restrictions

#### Scenario: User installs LGPL-safe prebuilts
- **WHEN** a user runs `npm install @pproenca/webcodecs-ffmpeg`
- **THEN** the appropriate platform package is installed as an optionalDependency
- **AND** the package contains LGPL-licensed FFmpeg binaries without GPL codecs

#### Scenario: User installs GPL prebuilts with x264/x265
- **WHEN** a user runs `npm install @pproenca/webcodecs-ffmpeg-non-free`
- **THEN** the appropriate platform package with GPL codecs is installed
- **AND** the user understands GPL copyleft applies to their project

### Requirement: Directory Structure

Package directories in the repository SHALL match package names (without scope prefix) for consistency.

#### Scenario: Directory matches package name
- **GIVEN** a package named `@pproenca/webcodecs-ffmpeg-darwin-arm64`
- **THEN** its source directory is `npm/webcodecs-ffmpeg-darwin-arm64/`

### Requirement: Platform Package optionalDependencies

Meta packages SHALL declare platform packages as optionalDependencies to enable automatic platform selection during install.

#### Scenario: Platform auto-selection
- **WHEN** `@pproenca/webcodecs-ffmpeg` is installed on macOS ARM64
- **THEN** only `@pproenca/webcodecs-ffmpeg-darwin-arm64` is downloaded
- **AND** other platform packages are skipped
