# Design: Split npm Publish Jobs

## Architecture

### Current State

```
publish (single job)
├── Download all 8 artifacts
├── Extract and populate all npm packages
└── Sequential publish: 11 packages with sleep(10)
```

### Target State

```
release
├── Create tag and GitHub Release
├── Upload release assets
└── Output: run_id for downstream jobs

publish-platform (matrix × 4, max-parallel: 2)
├── Download 2 artifacts (platform free + non-free)
├── Extract and populate platform packages
└── Publish 2 packages with sleep(5) between

publish-dev (parallel)
├── Download 1 artifact (any, for headers)
├── Populate dev package
└── Publish 1 package

publish-meta (sequential, after all above)
├── Checkout only (no artifacts needed)
├── Generate meta package.json with version
└── Publish 2 packages with sleep(5) between
```

## Job Dependencies

```
prepare → wait-for-ci → check-artifacts → release
                                             │
                    ┌────────────────────────┼────────────────────────┐
                    ↓                        ↓                        ↓
             publish-platform          publish-platform          publish-dev
             (darwin-arm64)            (darwin-x64)
                    ↓                        ↓
             publish-platform          publish-platform
             (linux-arm64)             (linux-x64)
                    └────────────────────────┼────────────────────────┘
                                             ↓
                                       publish-meta
```

## Key Design Decisions

### 1. Matrix with max-parallel: 2

Only 2 platform jobs run concurrently. This:
- Keeps total concurrent npm API calls low
- Still provides parallelism benefit
- Natural ~30s gap between job batches

### 2. Separate run_id Output

The `check-artifacts` job finds the CI run ID. This must be passed through `release` job outputs so downstream publish jobs can download artifacts.

```yaml
release:
  outputs:
    run_id: ${{ needs.check-artifacts.outputs.run_id }}
```

### 3. Minimal Artifact Downloads

Each publish job downloads only the artifacts it needs:
- Platform job: 2 tarballs (free + non-free for that platform)
- Dev job: 1 tarball (any platform, just needs headers)
- Meta job: None (generates package.json from template)

### 4. fail-fast: false

If darwin-arm64 fails, linux jobs should continue. This allows partial releases and easier debugging.

### 5. Provenance Attestations

Each job publishes with `--provenance`. npm links provenance to the GitHub Actions run, so multiple jobs publishing from the same workflow run will have valid attestations.

## Alternative Considered

**One job per package (11 jobs):** Rejected as excessive. Job overhead would dominate, and dependency graph becomes complex.

## Migration

This is a drop-in replacement. The release workflow behavior is identical from the user's perspective - they still run "Release" workflow and get packages published.
