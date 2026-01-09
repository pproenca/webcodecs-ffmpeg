# Design: Simplify Release Workflow

## Current Architecture

```
┌─────────┐    ┌─────────────┐    ┌─────────────────┐    ┌─────────┐    ┌─────────────┐
│ prepare │───▶│ wait-for-ci │───▶│ check-artifacts │───▶│ release │───▶│ publish-npm │
└─────────┘    └─────────────┘    └─────────────────┘    └─────────┘    └─────────────┘
                                                              │                │
                                                              ▼                ▼
                                                         Download          Download
                                                         artifacts         artifacts
                                                              │                │
                                                              ▼                ▼
                                                         gh release       npm publish
```

**Problems:**
- Artifacts downloaded twice
- 5 sequential jobs (slow)
- Complex inter-job data passing
- Manual gh commands are verbose

## Proposed Architecture

```
┌─────────┐    ┌─────────────────┐    ┌─────────────────────┐
│ prepare │───▶│ check-artifacts │───▶│ release-and-publish │
└─────────┘    └─────────────────┘    └─────────────────────┘
                                               │
                                               ▼
                                          Download once
                                               │
                          ┌────────────────────┼────────────────────┐
                          ▼                    ▼                    ▼
                    ncipollo/release     populate-npm.sh      npm publish
                    (tag + assets)
```

**Benefits:**
- Single artifact download
- 3 jobs instead of 5
- `ncipollo/release-action` handles tag creation + asset upload atomically
- Simpler dependency graph

## Key Design Decisions

### 1. Remove wait-for-ci job

**Rationale:** The `check-artifacts` job already verifies artifacts exist. If CI hasn't completed, artifacts won't exist and the job fails with a clear error. Polling adds complexity without benefit.

**Trade-off:** If user triggers release while CI is running, they get an error instead of waiting. This is acceptable - they can re-run after CI completes.

### 2. Use ncipollo/release-action@v1

**sharp-libvips usage:**
```yaml
- uses: ncipollo/release-action@v1
  with:
    artifacts: "npm-workspace.tar.xz"
    artifactContentType: application/x-xz
    bodyFile: release-notes.md
    prerelease: ${{ contains(github.ref, '-rc') }}
    makeLatest: ${{ !contains(github.ref, '-rc') }}
```

**Our adaptation:**
```yaml
- uses: ncipollo/release-action@v1
  with:
    tag: ${{ needs.prepare.outputs.tag }}
    commit: ${{ needs.prepare.outputs.commit }}
    artifacts: "artifacts/*.tar.gz,artifacts/*.sha256"
    generateReleaseNotes: true
```

**Benefits:**
- Atomic tag + release + asset upload
- No separate `gh release create` + `gh release upload`
- Built-in retry logic

### 3. Use actions/download-artifact@v4 with merge-multiple

**Current (dawidd6):**
```yaml
- uses: dawidd6/action-download-artifact@v6
  with:
    workflow: ci.yml
    run_id: ${{ needs.check-artifacts.outputs.run_id }}
    path: artifacts-download

- name: Flatten artifact directories
  run: |
    cd artifacts-download
    for dir in */; do
      mv "$dir"* . 2>/dev/null || true
      rmdir "$dir" 2>/dev/null || true
    done
```

**Proposed (native):**
```yaml
- uses: actions/download-artifact@v4
  with:
    path: artifacts
    merge-multiple: true
    run-id: ${{ needs.check-artifacts.outputs.run_id }}
    github-token: ${{ secrets.GITHUB_TOKEN }}
```

**Note:** `actions/download-artifact@v4` requires `run-id` for cross-workflow downloads, which we have from check-artifacts.

### 4. Keep workflow_dispatch trigger

sharp-libvips uses tag-triggered releases. We keep workflow_dispatch for:
- Manual version bump control
- Re-release capability
- Explicit release timing

## Migration Path

1. Update release.yml with new structure
2. Test with a patch release
3. Remove old jobs after verification

## Risks

| Risk | Mitigation |
|------|------------|
| ncipollo/release-action behavior differs | Test with dry-run first |
| actions/download-artifact cross-workflow limits | Fall back to dawidd6 if needed |
| Race condition without wait-for-ci | Clear error message, user re-runs |
