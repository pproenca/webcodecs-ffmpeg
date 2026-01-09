# Tasks: Rename npm packages to webcodecs-ffmpeg namespace

## 1. Update package.json files

### Platform packages (8 packages)
- [x] 1.1 Rename `npm/darwin-arm64/package.json` → `@pproenca/webcodecs-ffmpeg-darwin-arm64`
- [x] 1.2 Rename `npm/darwin-arm64-non-free/package.json` → `@pproenca/webcodecs-ffmpeg-darwin-arm64-non-free`
- [x] 1.3 Rename `npm/darwin-x64/package.json` → `@pproenca/webcodecs-ffmpeg-darwin-x64`
- [x] 1.4 Rename `npm/darwin-x64-non-free/package.json` → `@pproenca/webcodecs-ffmpeg-darwin-x64-non-free`
- [x] 1.5 Rename `npm/linux-arm64/package.json` → `@pproenca/webcodecs-ffmpeg-linux-arm64`
- [x] 1.6 Rename `npm/linux-arm64-non-free/package.json` → `@pproenca/webcodecs-ffmpeg-linux-arm64-non-free`
- [x] 1.7 Rename `npm/linux-x64/package.json` → `@pproenca/webcodecs-ffmpeg-linux-x64`
- [x] 1.8 Rename `npm/linux-x64-non-free/package.json` → `@pproenca/webcodecs-ffmpeg-linux-x64-non-free`

### Meta packages (2 packages)
- [x] 1.9 Rename `npm/ffmpeg/package.json` → `@pproenca/webcodecs-ffmpeg`
  - Update optionalDependencies to reference new platform package names
- [x] 1.10 Rename `npm/ffmpeg-non-free/package.json` → `@pproenca/webcodecs-ffmpeg-non-free`
  - Update optionalDependencies to reference new platform package names

### Dev package
- [x] 1.11 Rename `npm/dev/package.json` → `@pproenca/webcodecs-ffmpeg-dev`

## 2. Rename package directories

- [x] 2.1 Rename `npm/ffmpeg/` → `npm/webcodecs-ffmpeg/`
- [x] 2.2 Rename `npm/ffmpeg-non-free/` → `npm/webcodecs-ffmpeg-non-free/`
- [x] 2.3 Rename `npm/darwin-arm64/` → `npm/webcodecs-ffmpeg-darwin-arm64/`
- [x] 2.4 Rename `npm/darwin-arm64-non-free/` → `npm/webcodecs-ffmpeg-darwin-arm64-non-free/`
- [x] 2.5 Rename `npm/darwin-x64/` → `npm/webcodecs-ffmpeg-darwin-x64/`
- [x] 2.6 Rename `npm/darwin-x64-non-free/` → `npm/webcodecs-ffmpeg-darwin-x64-non-free/`
- [x] 2.7 Rename `npm/linux-arm64/` → `npm/webcodecs-ffmpeg-linux-arm64/`
- [x] 2.8 Rename `npm/linux-arm64-non-free/` → `npm/webcodecs-ffmpeg-linux-arm64-non-free/`
- [x] 2.9 Rename `npm/linux-x64/` → `npm/webcodecs-ffmpeg-linux-x64/`
- [x] 2.10 Rename `npm/linux-x64-non-free/` → `npm/webcodecs-ffmpeg-linux-x64-non-free/`

## 3. Update pnpm workspace

- [x] 3.1 Update `npm/pnpm-workspace.yaml` with new directory names

## 4. Update CI/CD workflows

- [x] 4.1 No changes needed in `.github/workflows/release.yml` - no package name hardcoded
- [x] 4.2 No changes needed in `.github/workflows/_build.yml` - no package name hardcoded
- [x] 4.3 No changes needed in `scripts/local-publish.sh` - uses dynamic names from workspace

## 5. Update documentation

- [x] 5.1 Update `openspec/project.md` - package references
- [x] 5.2 `CLAUDE.md` - no package name references to update
- [x] 5.3 Update `README.md` - installation instructions and package names

## 6. Update build scripts

- [x] 6.1 Update `scripts/populate-npm.sh` - all package name generation updated
- [x] 6.2 Update `scripts/publish-stubs.sh` - all package name references updated
- [x] 6.3 Update `npm/webcodecs-ffmpeg/install.js` - package name in getPackageName()
- [x] 6.4 Update `npm/webcodecs-ffmpeg-non-free/install.js` - package name in getPackageName()
- [x] 6.5 Update `npm/webcodecs-ffmpeg/resolve.js` - package name references
- [x] 6.6 Update `npm/webcodecs-ffmpeg-non-free/resolve.js` - package name references
- [x] 6.7 Update `npm/dev/gyp-config.js` - usage example in comment

## 7. Verification

- [x] 7.1 Run `pnpm install` to verify workspace configuration
- [x] 7.2 Run `pnpm list -r` to verify all packages recognized (12 packages)
- [ ] 7.3 Dry-run publish to verify package names: `pnpm publish -r --dry-run` (skipped - requires npm auth)

## 8. npm Registry (post-merge)

- [x] 8.1 ~~Deprecate old package names~~ - Not needed, old packages already deleted
- [ ] 8.2 Publish new packages with `pnpm publish -r`

## Dependencies

- Tasks 1.x must complete before 2.x (update package.json before renaming directories)
- Task 3.1 depends on 2.x completion
- Tasks 4.x, 5.x, 6.x can run in parallel after 2.x
- Task 7.x requires all previous tasks
- Task 8.x is post-merge, manual step
