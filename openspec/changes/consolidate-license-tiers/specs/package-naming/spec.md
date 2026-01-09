## ADDED Requirements

### Requirement: Two-Tier License Model

The build system SHALL support a two-tier license model with values `free` and `non-free` that controls codec inclusion.

#### Scenario: Free tier builds LGPL-compatible codecs
- **WHEN** `LICENSE=free` is specified
- **THEN** the build includes: libvpx, aom, dav1d, svt-av1, opus, ogg, vorbis, lame
- **AND** FFmpeg is built without `--enable-gpl`
- **AND** the resulting binary is LGPL-2.1+ licensed

#### Scenario: Non-free tier builds all codecs including GPL
- **WHEN** `LICENSE=non-free` is specified
- **THEN** the build includes all free-tier codecs plus: x264, x265
- **AND** FFmpeg is built with `--enable-gpl`
- **AND** the resulting binary is GPL-2.0+ licensed

#### Scenario: Free tier is the default
- **WHEN** no LICENSE value is specified
- **THEN** `LICENSE=free` is used by default

### Requirement: Backwards Compatibility for Old License Values

The build system SHALL accept legacy license values (`bsd`, `lgpl`, `gpl`) and map them to the new two-tier model with deprecation warnings.

#### Scenario: BSD maps to free tier
- **WHEN** `LICENSE=bsd` is specified
- **THEN** the build uses `free` tier codecs
- **AND** a deprecation warning is emitted

#### Scenario: LGPL maps to free tier
- **WHEN** `LICENSE=lgpl` is specified
- **THEN** the build uses `free` tier codecs
- **AND** a deprecation warning is emitted

#### Scenario: GPL maps to non-free tier
- **WHEN** `LICENSE=gpl` is specified
- **THEN** the build uses `non-free` tier codecs
- **AND** a deprecation warning is emitted

### Requirement: npm Package Naming Convention

npm packages SHALL follow a naming convention that reflects the two-tier license model.

#### Scenario: Meta package for free tier
- **WHEN** a user installs `@pproenca/ffmpeg`
- **THEN** they receive the free-tier FFmpeg build for their platform
- **AND** the package license is `LGPL-2.1-or-later`

#### Scenario: Meta package for non-free tier
- **WHEN** a user installs `@pproenca/ffmpeg-non-free`
- **THEN** they receive the non-free tier FFmpeg build for their platform
- **AND** the package license is `GPL-2.0-or-later`

#### Scenario: Platform-specific package naming
- **WHEN** platform-specific packages are published
- **THEN** free-tier packages are named `@pproenca/ffmpeg-{platform}`
- **AND** non-free tier packages are named `@pproenca/ffmpeg-{platform}-non-free`

### Requirement: Artifact Naming Convention

Build artifacts SHALL follow a naming convention that reflects the two-tier license model.

#### Scenario: Free tier artifact naming
- **WHEN** a free-tier build is packaged
- **THEN** the artifact is named `ffmpeg-{platform}.tar.gz`

#### Scenario: Non-free tier artifact naming
- **WHEN** a non-free tier build is packaged
- **THEN** the artifact is named `ffmpeg-{platform}-non-free.tar.gz`

### Requirement: CI/CD Matrix Reduction

The CI/CD build matrix SHALL use the two-tier license model to reduce build variants.

#### Scenario: Build matrix uses two license values
- **WHEN** the CI build workflow executes
- **THEN** it builds for `[free, non-free]` license tiers
- **AND** the total builds per platform is 2 (not 3)

### Requirement: Deprecation Notice for Legacy npm Packages

Legacy npm package names SHALL continue to work but display deprecation notices.

#### Scenario: ffmpeg-lgpl redirects to ffmpeg
- **WHEN** a user has `@pproenca/ffmpeg-lgpl` as a dependency
- **THEN** npm install succeeds
- **AND** the package description indicates deprecation
- **AND** the package recommends `@pproenca/ffmpeg` instead

#### Scenario: ffmpeg-gpl redirects to ffmpeg-non-free
- **WHEN** a user has `@pproenca/ffmpeg-gpl` as a dependency
- **THEN** npm install succeeds
- **AND** the package description indicates deprecation
- **AND** the package recommends `@pproenca/ffmpeg-non-free` instead
