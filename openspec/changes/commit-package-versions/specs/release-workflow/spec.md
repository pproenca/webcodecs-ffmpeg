# Capability: Release Workflow

## Overview

Defines how versions are managed and packages are released to npm.

---

## ADDED Requirements

### Requirement: Package.json as version source of truth

The version in `npm/webcodecs-ffmpeg/package.json` SHALL be the single source of truth for all package versions. All packages in the workspace MUST have identical versions.

#### Scenario: Reading current version

- GIVEN the npm workspace
- WHEN the release process needs the current version
- THEN it reads from `npm/webcodecs-ffmpeg/package.json`
- AND all other package.json files have the same version

### Requirement: Version bump updates package.json files

The `bump-version.sh` script SHALL update all package.json files in the workspace atomically, create a commit, and create a git tag.

#### Scenario: Patch version bump

- GIVEN current version is `0.6.4`
- WHEN `./scripts/bump-version.sh patch` is executed
- THEN all package.json files are updated to `0.6.5`
- AND optionalDependencies in meta packages reference `0.6.5`
- AND a commit is created with message `chore(release): v0.6.5`
- AND a git tag `v0.6.5` is created

#### Scenario: Version sync validation

- GIVEN the bump-version.sh script runs
- WHEN any package.json has a different version than others
- THEN the script fails with an error before making changes
- AND no files are modified

### Requirement: Artifact population is version-agnostic

The `populate-artifacts.sh` script SHALL copy build artifacts without modifying package.json files.

#### Scenario: Populating platform package

- GIVEN artifacts in `artifacts/darwin-arm64-free/`
- WHEN `./scripts/populate-artifacts.sh` is executed
- THEN `lib/*.a` files are copied to `npm/webcodecs-ffmpeg-darwin-arm64/lib/`
- AND `lib/pkgconfig/*.pc` files are copied
- AND `versions.json` is generated with build metadata
- AND `package.json` is NOT modified

---

## MODIFIED Requirements

### Requirement: Release workflow reads committed versions

The GitHub Actions release workflow SHALL NOT inject versions dynamically. It SHALL read the version from committed package.json files.

#### Scenario: Release workflow execution

- GIVEN a version bump commit with tag `v0.7.0`
- WHEN the release workflow runs
- THEN it extracts artifacts
- AND runs `populate-artifacts.sh` (not populate-npm.sh)
- AND publishes packages with versions from committed package.json
- AND the tag matches the package.json version

---

## REMOVED Requirements

### Requirement: Dynamic package.json generation removed

The release workflow SHALL NOT generate package.json files at publish time.

#### Scenario: Legacy populate-npm.sh behavior

- GIVEN the old `populate-npm.sh` script
- WHEN called during release
- THEN it would regenerate all package.json files from templates
- THIS BEHAVIOR IS REMOVED - package.json files are committed to git
