# npm-package-exports

## ADDED Requirements

### Requirement: Platform packages MUST export link flags

Platform-specific npm packages MUST export a `./link-flags` subpath that provides pre-computed linker flags for native addon compilation.

#### Scenario: Consumer requires link flags from platform package

**Given** a consumer has installed `@pproenca/webcodecs-ffmpeg-darwin-arm64`
**When** they require `@pproenca/webcodecs-ffmpeg-darwin-arm64/link-flags`
**Then** they receive an object with:
  - `libDir`: absolute path to the lib directory
  - `flags`: string containing all linker flags

#### Scenario: Link flags include FFmpeg libraries in correct order

**Given** a platform package with link-flags.js
**When** the `flags` string is parsed
**Then** it contains FFmpeg libraries in reverse dependency order:
  - `-lavfilter` before `-lavcodec`
  - `-lavcodec` before `-lavutil`

#### Scenario: Darwin packages include macOS frameworks

**Given** a darwin-arm64 or darwin-x64 platform package
**When** the link-flags.js `flags` string is examined
**Then** it includes macOS frameworks:
  - `-framework VideoToolbox`
  - `-framework AudioToolbox`
  - `-framework CoreMedia`
  - `-framework CoreVideo`
  - `-framework CoreFoundation`
  - `-framework CoreServices`
  - `-framework Security`

#### Scenario: Linux glibc packages include dlopen support

**Given** a linux-arm64 or linux-x64 (glibc) platform package
**When** the link-flags.js `flags` string is examined
**Then** it includes `-ldl` for dynamic loading support

#### Scenario: Linux musl packages omit dlopen library

**Given** a linux-x64-musl platform package
**When** the link-flags.js `flags` string is examined
**Then** it does NOT include `-ldl` (musl includes dlopen in libc)

### Requirement: link-flags.js MUST be included in package files

Platform package.json files MUST include `link-flags.js` in the `files` array to ensure it is published.

#### Scenario: Package publishes link-flags.js

**Given** a platform package.json with `"files": ["lib", "versions.json", "link-flags.js"]`
**When** the package is published to npm
**Then** link-flags.js is included in the published tarball

### Requirement: populate-artifacts MUST generate link-flags.js

The `populate-artifacts.sh` script MUST generate a `link-flags.js` file for each platform package during artifact population.

#### Scenario: Artifact population creates link-flags.js

**Given** artifacts exist in `artifacts/<platform>-<tier>/`
**When** `./scripts/populate-artifacts.sh` is run
**Then** `npm/<package>/link-flags.js` is created with platform-appropriate flags

#### Scenario: Non-free tier includes GPL codec flags

**Given** artifacts for a non-free tier package
**When** link-flags.js is generated
**Then** the `flags` string includes:
  - `-lx265` for HEVC
  - `-lx264` for AVC
