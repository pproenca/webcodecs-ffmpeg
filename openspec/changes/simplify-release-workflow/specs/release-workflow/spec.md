# Release Workflow

## MODIFIED Requirements

### Requirement: GitHub Release Creation

The release workflow SHALL create a GitHub release with build artifacts when triggered via workflow_dispatch.

**Changes:** Replace manual `gh release create` + `gh release upload` with `ncipollo/release-action@v1` for atomic release creation.

#### Scenario: New release with artifacts
- **WHEN** release workflow is triggered with bump_type
- **THEN** a git tag is created at the specified commit
- **AND** a GitHub release is created with auto-generated notes
- **AND** all platform tarballs and checksums are attached as release assets

#### Scenario: Re-release existing tag
- **WHEN** release workflow is triggered with existing tag
- **THEN** release assets are updated without creating new tag

### Requirement: Artifact Download

The release workflow SHALL download CI artifacts for packaging and release.

**Changes:** Replace `dawidd6/action-download-artifact@v6` + flatten step with `actions/download-artifact@v4` using `merge-multiple: true`.

#### Scenario: Download from CI workflow
- **WHEN** CI artifacts exist for the release commit
- **THEN** all 8 platform artifacts are downloaded
- **AND** artifacts are merged into single directory without subdirectories

### Requirement: Job Consolidation

The release workflow SHALL minimize job count while maintaining functionality.

**Changes:** Consolidate 5 jobs (prepare, wait-for-ci, check-artifacts, release, publish-npm) into 3 jobs (prepare, check-artifacts, release-and-publish).

#### Scenario: Simplified job structure
- **WHEN** release workflow executes
- **THEN** only 3 jobs run sequentially
- **AND** artifacts are downloaded once (not twice)
- **AND** both GitHub release and npm publish occur in same job

## REMOVED Requirements

### Requirement: CI Polling

**Reason:** Redundant - if CI hasn't completed, artifacts won't exist and check-artifacts fails with clear error.

**Migration:** Users re-run workflow after CI completes instead of automatic waiting.

#### Scenario: Removed wait-for-ci job
- **WHEN** release triggered while CI running
- **THEN** check-artifacts fails with "artifacts not found" error
- **AND** user re-triggers after CI completes
