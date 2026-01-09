# Proposal: Split npm Publish Jobs

## Summary

Split the monolithic npm publish step in `release.yml` into separate GitHub Actions jobs to avoid npm registry rate limits (E429).

## Problem

The current release workflow publishes all 11 npm packages sequentially from a single job. Even with delays between publishes, npm's undocumented rate limits trigger E429 errors:

```
npm error code E429
npm error 429 Too Many Requests - PUT https://registry.npmjs.org/@pproenca%2fffmpeg-darwin-arm64
npm error Could not publish, as user undefined: rate limited exceeded
```

Research shows npm's rate limit kicks in after rapid sequential API calls, with no official documentation on thresholds or reset windows.

## Solution

Split publishing into separate jobs:

| Job | Packages | Concurrency |
|-----|----------|-------------|
| `publish-platform` (matrix) | 2 per job (free + non-free) | max-parallel: 2 |
| `publish-dev` | 1 (dev headers) | parallel with platforms |
| `publish-meta` | 2 (ffmpeg, ffmpeg-non-free) | after all platforms |

### Benefits

1. **Natural rate limiting** - Job startup overhead (~30s) spaces out publishes
2. **Granular retries** - Only failed job retries, not all 11 packages
3. **Parallel where safe** - Platform jobs can overlap (max 2 concurrent)
4. **Correct ordering** - Meta packages wait for platform packages to exist

## Scope

- **In scope:** Restructure `release.yml` publish jobs
- **Out of scope:** Changes to npm package structure, populate-npm.sh, CI workflow

## Dependencies

None - this is an isolated change to release workflow.

## Risks

| Risk | Mitigation |
|------|------------|
| run_id not available in downstream jobs | Pass via job outputs |
| Populate script expects all artifacts | Download only needed artifacts per job |
| Meta packages published before platforms | Explicit `needs:` dependency chain |
