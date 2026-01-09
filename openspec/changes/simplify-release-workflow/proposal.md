# Simplify Release Workflow

## Summary

Simplify `release.yml` to match the proven pattern from [sharp-libvips](https://github.com/lovell/sharp-libvips/blob/main/.github/workflows/ci.yml), reducing complexity and improving maintainability.

## Motivation

Current release workflow has 5 jobs with complex artifact handling:
- `prepare` - version calculation
- `wait-for-ci` - poll for CI completion
- `check-artifacts` - verify artifacts exist
- `release` - create tag, GitHub release, upload assets
- `publish-npm` - download again, extract, populate, publish

**Pain points:**
1. Artifacts downloaded twice (release job + npm job)
2. Manual `gh release create` + `gh release upload` is verbose
3. `dawidd6/action-download-artifact@v6` requires flatten step
4. 5 jobs with complex dependencies

**sharp-libvips pattern:**
- Single job for release + npm publish
- `ncipollo/release-action@v1` for GitHub releases
- `actions/download-artifact@v4` with `merge-multiple: true`
- ~50 lines vs ~200 lines for release logic

## Proposed Changes

1. **Consolidate to 3 jobs:** prepare → release-and-publish (combines release + npm)
2. **Use `ncipollo/release-action@v1`** for cleaner GitHub release creation
3. **Use `actions/download-artifact@v4`** with `merge-multiple: true` (no flatten needed)
4. **Remove `wait-for-ci` job** - rely on artifact existence check
5. **Single artifact download** - download once, use for both release assets and npm

## Out of Scope

- Changing from workflow_dispatch to tag-triggered (keep manual control)
- Modifying CI workflow or build process
- Changing artifact naming or structure

## Success Criteria

- Release workflow reduced from 5 jobs to 3
- Same functionality: tag, GitHub release, npm publish
- Workflow file ~50% smaller
