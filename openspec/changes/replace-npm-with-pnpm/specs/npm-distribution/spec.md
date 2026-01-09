## ADDED Requirements

### Requirement: Package Manager Configuration

The project SHALL use pnpm as the internal package manager for workspace operations and publishing.

#### Scenario: pnpm workspace initialization

- **WHEN** a developer clones the repository
- **AND** runs `cd npm && pnpm install`
- **THEN** pnpm reads `pnpm-workspace.yaml` to discover workspace packages
- **AND** generates or updates `pnpm-lock.yaml`

#### Scenario: pnpm version is specified

- **WHEN** the project is set up for development
- **THEN** `.mise.toml` SHALL specify `pnpm = "9"` in the tools section
- **AND** `mise install` installs the correct pnpm version

### Requirement: Workspace Structure

The workspace SHALL contain all npm packages defined in `npm/pnpm-workspace.yaml`.

#### Scenario: Workspace package discovery

- **WHEN** `pnpm list -r` is executed in the `npm/` directory
- **THEN** it SHALL list exactly 11 packages:
  - `@pproenca/ffmpeg-dev`
  - `@pproenca/ffmpeg`
  - `@pproenca/ffmpeg-non-free`
  - `@pproenca/ffmpeg-darwin-arm64`
  - `@pproenca/ffmpeg-darwin-arm64-non-free`
  - `@pproenca/ffmpeg-darwin-x64`
  - `@pproenca/ffmpeg-darwin-x64-non-free`
  - `@pproenca/ffmpeg-linux-arm64`
  - `@pproenca/ffmpeg-linux-arm64-non-free`
  - `@pproenca/ffmpeg-linux-x64`
  - `@pproenca/ffmpeg-linux-x64-non-free`

### Requirement: Publishing to npm Registry

The project SHALL publish all workspace packages to the npm registry using pnpm.

#### Scenario: CI publishing with provenance

- **WHEN** the release workflow runs in GitHub Actions
- **AND** artifacts are available from CI
- **THEN** `pnpm publish -r --provenance --access public` SHALL be executed
- **AND** all packages are published with SLSA provenance attestations

#### Scenario: Local publishing for testing

- **WHEN** a developer runs `scripts/local-publish.sh --dry-run`
- **THEN** pnpm is used for all publish operations
- **AND** no packages are actually published

#### Scenario: Sequential publishing to avoid rate limits

- **WHEN** publishing multiple packages
- **THEN** packages MAY be published with delays between them
- **AND** npm E409 conflicts are handled gracefully

### Requirement: npm Registry Configuration

The workspace SHALL include an `.npmrc` file with appropriate settings.

#### Scenario: Public package access

- **WHEN** packages are published
- **THEN** they SHALL be accessible publicly
- **AND** `.npmrc` SHALL contain `access=public`

#### Scenario: Workspace linking disabled

- **WHEN** pnpm operates on the workspace
- **THEN** workspace packages SHALL NOT be linked
- **AND** `.npmrc` SHALL contain `link-workspace-packages=false`

### Requirement: Root Package Configuration

The `npm/package.json` SHALL be a minimal private root package.

#### Scenario: Private root prevents accidental publish

- **WHEN** `npm/package.json` exists
- **THEN** it SHALL contain `"private": true`
- **AND** it SHALL NOT contain a `workspaces` field (workspaces defined in pnpm-workspace.yaml)

### Requirement: Consumer Compatibility

Package consumers SHALL be able to install packages using any package manager.

#### Scenario: npm installation

- **WHEN** a consumer runs `npm install @pproenca/ffmpeg`
- **THEN** the package installs correctly from npm registry

#### Scenario: yarn installation

- **WHEN** a consumer runs `yarn add @pproenca/ffmpeg`
- **THEN** the package installs correctly from npm registry

#### Scenario: pnpm installation

- **WHEN** a consumer runs `pnpm add @pproenca/ffmpeg`
- **THEN** the package installs correctly from npm registry
