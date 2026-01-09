# Proposal: Commit package.json versions like sharp-libvips

## Summary

Switch from dynamic version injection at release time to committed package.json files as the source of truth for versions, following the sharp-libvips pattern.

## Motivation

**Current approach:**
- `bump-version.sh` creates a git tag only (no file modifications)
- `populate-npm.sh` regenerates ALL package.json files at release time using `FFMPEG_VERSION` env var
- Package.json files in git are snapshots that get overwritten at publish

**Problems:**
1. Git history doesn't reflect version changes - versions are injected at CI time
2. `git blame` on package.json shows the last populate-npm.sh run, not actual version bumps
3. Local development uses stale versions until next release
4. Harder to audit what version was published from which commit

**sharp-libvips approach:**
- package.json files committed to git ARE the source of truth
- Version bumps modify package.json files and commit them
- CI reads versions from committed files, doesn't inject them
- Clear git history of version changes

## Scope

- Modify `scripts/bump-version.sh` to update package.json files
- Modify `scripts/populate-npm.sh` to only handle build artifacts (lib/, include/)
- Update release workflow to read version from package.json
- Remove dynamic package.json generation

## Non-Goals

- Changing directory structure (already renamed in previous change)
- Changing package names (already done)
- Switching from pnpm to npm (pnpm workspaces work fine)

## Design

### Version Source of Truth

The meta package `npm/webcodecs-ffmpeg/package.json` becomes the single source of truth for the version. All other packages must have the same version.

### bump-version.sh Changes

```bash
# Before: Creates git tag only
git tag "v${new}"

# After: Updates all package.json, commits, creates tag
pnpm --filter "./npm/*" exec -- npm version "${new}" --no-git-tag-version
git add npm/*/package.json
git commit -m "chore(release): ${new}"
git tag "v${new}"
```

### populate-npm.sh Changes

The script becomes `populate-artifacts.sh` and ONLY:
1. Copies `lib/*.a` files from artifacts to npm packages
2. Copies `lib/pkgconfig/*.pc` files
3. Copies `include/` to dev package
4. Generates `versions.json` (build metadata, not package version)
5. Does NOT touch package.json files

### Release Workflow Changes

```yaml
# Before
env:
  FFMPEG_VERSION: ${{ needs.prepare.outputs.tag }}
run: |
  export FFMPEG_VERSION="${FFMPEG_VERSION#v}"
  ./scripts/populate-npm.sh

# After
run: |
  ./scripts/populate-artifacts.sh
  # Version is already in committed package.json files
```

## Risks

1. **Version drift**: Packages could get out of sync if edited manually
   - Mitigation: `bump-version.sh` updates all packages atomically

2. **Forgotten version bump**: Developer pushes changes but forgets to bump
   - Mitigation: Release workflow can validate version doesn't already exist on npm

## Dependencies

- Requires package.json files to be committed (already done)
- No build system changes needed

## Alternatives Considered

1. **Keep current approach**: Dynamic injection works, but lacks git auditability
2. **Use lerna/changesets**: Overkill for a single-version monorepo
3. **versions.json as source**: Adds indirection, package.json is more standard
