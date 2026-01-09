# Tasks: Commit package.json versions like sharp-libvips

## 1. Update bump-version.sh

- [x] 1.1 Read current version from `npm/webcodecs-ffmpeg/package.json` instead of git tags
- [x] 1.2 Calculate new version based on bump type (major/minor/patch)
- [x] 1.3 Update all package.json files in npm/ workspace using node
- [x] 1.4 Update optionalDependencies versions in meta packages
- [x] 1.5 Stage all package.json changes with `git add`
- [x] 1.6 Create commit with message `chore(release): v{version}`
- [x] 1.7 Create git tag `v{version}`
- [x] 1.8 Print instructions for push and release

## 2. Create populate-artifacts.sh (extract from populate-npm.sh)

- [x] 2.1 Create new script `scripts/populate-artifacts.sh`
- [x] 2.2 Copy artifact handling from populate-npm.sh:
  - Copy `lib/*.a` to platform packages
  - Copy `lib/pkgconfig/*.pc` to platform packages
  - Copy `include/` to dev package
  - Generate `lib/index.js` and `lib/pkgconfig/index.js`
- [x] 2.3 Generate `versions.json` with build metadata only (not package version)
- [x] 2.4 Remove all `generate_*_package_json` functions (not needed)
- [x] 2.5 Remove meta package generation (install.js, resolve.js already committed)

## 3. Update release workflow

- [x] 3.1 Remove `FFMPEG_VERSION` environment variable injection
- [x] 3.2 Change `./scripts/populate-npm.sh` to `./scripts/populate-artifacts.sh`
- [x] 3.3 Add version validation step: verify package version doesn't exist on npm
- [x] 3.4 Read version from package.json for tag creation (instead of calculating)
- [x] 3.5 Change workflow input from bump_type to tag (tag must be created by bump-version.sh first)

## 4. Clean up populate-npm.sh

- [x] 4.1 Keep for local development/testing (regenerates everything)
- [x] 4.2 Add deprecation notice pointing to bump-version.sh + populate-artifacts.sh

## 5. Documentation

- [x] 5.1 Update CLAUDE.md release flow documentation
- [x] 5.2 Update openspec/project.md release workflow section

## 6. Verification

- [x] 6.1 Test bump-version.sh locally with `--dry-run` flag
- [x] 6.2 Verify all package.json versions are in sync (all 11 packages at 0.6.4)
- [x] 6.3 Run shellcheck on new scripts
- [x] 6.4 Verify pnpm workspace still works (`pnpm install`, `pnpm list -r`)

## Dependencies

- Tasks 1.x and 2.x can run in parallel
- Task 3.x depends on 2.x completion
- Task 4.x depends on 2.x completion
- Tasks 5.x and 6.x depend on all previous tasks
