# Tasks: Simplify Release Workflow

## Task List

### Phase 1: Refactor release.yml

- [x] **Task 1: Remove wait-for-ci job**
  - Delete the entire `wait-for-ci` job
  - Update `check-artifacts` to not depend on `wait-for-ci`
  - Verify: Job dependency graph simplified

- [x] **Task 2: Consolidate release and publish-npm into single job**
  - Merge `release` and `publish-npm` jobs into `release-and-publish`
  - Single artifact download
  - Verify: Only 3 jobs remain (prepare, check-artifacts, release-and-publish)

- [x] **Task 3: Replace gh commands with ncipollo/release-action**
  - Remove manual `gh release create` and `gh release upload`
  - Add `ncipollo/release-action@v1` with:
    - `tag`, `commit` from prepare outputs
    - `artifacts` glob for tarballs and checksums
    - `generateReleaseNotes: true`
  - Keep conditional tag creation logic
  - Verify: GitHub release created with assets

- [x] **Task 4: Simplify artifact download**
  - Keep `dawidd6/action-download-artifact@v6` (required for cross-workflow)
  - Use `name_is_regexp: true` with `ffmpeg-*` pattern
  - Consolidated flatten + verify into single step
  - Verify: Artifacts downloaded correctly

- [x] **Task 5: Update npm publish step**
  - Move npm publish into consolidated job
  - Keep `npm publish --workspaces --provenance --access public`
  - Verify: npm packages published

### Phase 2: Cleanup

- [x] **Task 6: Remove unused env vars**
  - Removed `EXPECTED_ARTIFACTS` env var
  - Using artifact count verification instead
  - Verify: No unused variables

- [x] **Task 7: Update workflow comments**
  - Simplified job comments
  - Removed verbose step names where clear
  - Verify: Comments accurate

### Phase 3: Validation

- [ ] **Task 8: Test with dry-run**
  - Trigger workflow without actual publish (comment out publish step)
  - Verify tag creation, release creation, asset upload
  - Verify: All steps succeed except publish

- [ ] **Task 9: Test full release**
  - Trigger patch release
  - Verify GitHub release has all assets
  - Verify npm packages published
  - Verify: End-to-end success

## Summary

**Before:** 5 jobs, 376 lines
**After:** 3 jobs, 212 lines (~44% reduction)

| Change | Description |
|--------|-------------|
| Removed `wait-for-ci` | Rely on artifact existence check |
| Consolidated jobs | `release` + `publish-npm` → `release-and-publish` |
| `ncipollo/release-action` | Replaces `gh release create` + `gh release upload` |
| Simplified artifact check | Count-based instead of name matching |
