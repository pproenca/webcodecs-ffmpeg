# Tasks: Split npm Publish Jobs

## Task List

### 1. Refactor `release` job to separate GitHub Release from npm publish
- [x] Rename `publish` job to `release`
- [x] Remove npm publish steps from `release` job
- [x] Add `run_id` to job outputs for downstream jobs
- [x] Keep: tag creation, GitHub Release, artifact attestation, asset upload

**Validation:** `openspec validate split-npm-publish-jobs` ✓

### 2. Add `publish-platform` matrix job
- [x] Create job with matrix: `[darwin-arm64, darwin-x64, linux-arm64, linux-x64]`
- [x] Set `max-parallel: 2` and `fail-fast: false`
- [x] Add `needs: [prepare, check-artifacts, release]`
- [x] Download only platform-specific artifacts (free + non-free)
- [x] Extract artifacts to correct directory structure
- [x] Run `populate-npm.sh` to generate package files
- [x] Publish free package, sleep 5s, publish non-free package

**Validation:** actionlint passes ✓

### 3. Add `publish-dev` job
- [x] Create standalone job (no matrix)
- [x] Add `needs: [prepare, check-artifacts, release]`
- [x] Download single artifact (darwin-arm64-free) for headers
- [x] Extract and run `populate-npm.sh`
- [x] Publish dev package only

**Validation:** actionlint passes ✓

### 4. Add `publish-meta` job
- [x] Create job with `needs: [prepare, publish-platform, publish-dev]`
- [x] Checkout repo only (no artifact download needed)
- [x] Run `populate-npm.sh` to generate meta package.json
- [x] Publish ffmpeg, sleep 5s, publish ffmpeg-non-free

**Validation:** actionlint passes ✓

### 5. Test full release workflow
- [ ] Trigger release workflow on test branch
- [ ] Verify all 6 publish jobs complete successfully
- [ ] Verify all 11 packages appear on npm registry
- [ ] Verify no E429 rate limit errors

**Validation:** All packages at correct version on npmjs.com

### 6. Clean up and commit
- [x] Remove unused retry action (nick-invision/retry) if no longer needed
- [x] Update CLAUDE.md if release workflow documentation affected (N/A - no doc changes needed)
- [x] Commit with message: `fix(release): split npm publish into separate jobs to avoid rate limits`

**Validation:** `actionlint` passes ✓

## Dependencies

```
Task 1 (refactor release)
    ↓
Tasks 2, 3 (platform + dev jobs) [parallel]
    ↓
Task 4 (meta job)
    ↓
Task 5 (integration test)
    ↓
Task 6 (cleanup)
```

## Notes

- Tasks 2 and 3 can be implemented in parallel
- Task 5 requires all previous tasks complete
- If rate limits still occur, increase `max-parallel` delay or add explicit sleeps
