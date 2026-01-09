# Tasks: Consolidate License Tiers

## 1. Build System Core Changes

- [x] 1.1 Update `shared/codecs/codec.mk`:
  - Add `free|non-free` as valid LICENSE values
  - Map: `free` → BSD + LGPL codecs, `non-free` → all codecs
  - Add backwards compat: `bsd|lgpl` → `free`, `gpl` → `non-free`
  - Add deprecation warning for old values

- [x] 1.2 Update `shared/common.mk`:
  - Deprecation warnings handled in codec.mk using Make's `$(warning ...)`

- [x] 1.3 Update platform Makefiles (`platforms/*/Makefile`):
  - Update LICENSE handling to support new values
  - Update help text
  - Update ARTIFACTS_DIR naming

## 2. Build Scripts

- [x] 2.1 Update `platforms/darwin-arm64/build.sh`:
  - Accept `free|non-free` LICENSE values
  - Add backwards compat with deprecation warning

- [x] 2.2 Update `platforms/darwin-x64/build.sh`:
  - Same changes as darwin-arm64

- [x] 2.3 Update `platforms/linux-x64/build.sh`:
  - Same changes as darwin-arm64

- [x] 2.4 Update `platforms/linux-arm64/build.sh`:
  - Same changes as darwin-arm64

- [x] 2.5 Update `docker/build.sh`:
  - Accept new LICENSE values
  - Update artifact directory naming

## 3. CI/CD Workflows

- [x] 3.1 Update `.github/workflows/_build.yml`:
  - Change matrix from `[bsd, lgpl, gpl]` to `[free, non-free]`
  - Update artifact naming

- [x] 3.2 Update `.github/workflows/ci.yml`:
  - No changes needed (uses _build.yml)

- [x] 3.3 Update `.github/workflows/release.yml`:
  - Update artifact download patterns
  - Update npm package publishing for new names

- [x] 3.4 Update `.github/workflows/lint.yml`:
  - No changes needed (verified)

## 4. npm Package Structure

- [x] 4.1 Reorganize `npm/` directory:
  - Remove `ffmpeg-lgpl/` (merged into base)
  - Rename `ffmpeg-gpl/` → `ffmpeg-non-free/`
  - Remove platform `-lgpl` directories
  - Rename platform `-gpl` directories to `-non-free`

- [x] 4.2 Update `npm/ffmpeg/package.json`:
  - Update description to mention LGPL inclusion
  - Update license to "LGPL-2.1-or-later"

- [x] 4.3 Create `npm/ffmpeg-non-free/package.json`:
  - Update name from `ffmpeg-gpl`
  - Update description
  - License: "GPL-2.0-or-later"

- [x] 4.4 Update platform package.json files:
  - Generated dynamically by populate-npm.sh

- [x] 4.5 Update `scripts/populate-npm.sh`:
  - Update LICENSE_MAP for new tiers
  - Update package name generation
  - Update LICENSE file copying

## 5. Documentation

- [x] 5.1 Update `README.md`:
  - Update package naming section
  - Update license tier explanation
  - Update platform support status

- [x] 5.2 Update `CLAUDE.md`:
  - Update license categories table
  - Update CI/CD workflow description

- [x] 5.3 Update `openspec/project.md`:
  - No project.md file found that needs updates

## 6. Deprecation Notices

- [x] 6.1 ~~Create deprecation npm packages~~ - Not needed (no existing users)

## 7. Testing & Validation

- [ ] 7.1 Test backwards compatibility:
  - Verify `LICENSE=bsd` still works
  - Verify `LICENSE=lgpl` still works
  - Verify `LICENSE=gpl` still works
  - Confirm deprecation warnings appear

- [ ] 7.2 Test new values:
  - Verify `LICENSE=free` builds correct codecs
  - Verify `LICENSE=non-free` builds all codecs

- [ ] 7.3 Test CI matrix:
  - Verify 2-license matrix builds correctly
  - Verify artifacts have correct names

- [ ] 7.4 Test npm packages:
  - Verify new package names work
  - Verify platform detection works
