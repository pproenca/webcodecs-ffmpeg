# Tasks: Replace npm with pnpm

## 1. Add pnpm Configuration

- [x] 1.1 Add pnpm to `.mise.toml` tools section with version pin `pnpm = "9"`
- [x] 1.2 Run `mise install` to verify pnpm installs correctly
- [x] 1.3 Create `npm/pnpm-workspace.yaml` with explicit package list
- [x] 1.4 Create `npm/.npmrc` with `access=public`, `link-workspace-packages=false`, `prefer-offline=true`
- [x] 1.5 Remove `workspaces` field from `npm/package.json` (keep `private: true`)
- [x] 1.6 Delete `npm/lerna.json`
- [x] 1.7 Run `cd npm && pnpm install` to generate `pnpm-lock.yaml`
- [x] 1.8 Verify workspace setup: `cd npm && pnpm list -r` should list all 11 packages

## 2. Update Scripts

- [x] 2.1 Modify `scripts/populate-npm.sh`:
  - Update the `npm/package.json` generation block to only include `{ "private": true }`
  - Remove the `workspaces` array (now in pnpm-workspace.yaml)
- [x] 2.2 Modify `scripts/local-publish.sh`:
  - Line 222: Change `npm publish --workspaces --access public` to `pnpm publish -r --access public`
  - Update usage/help text to mention pnpm
- [x] 2.3 Modify `scripts/publish-stubs.sh`:
  - Line 64: Change `npm publish --workspace "$platform"` to `pnpm publish --filter "@pproenca/ffmpeg-${platform}"`
  - Line 87: Change `npm publish --workspace dev` to `pnpm publish --filter "@pproenca/ffmpeg-dev"`
  - Line 118: Change `npm publish --workspace "$name"` to `pnpm publish --filter "@pproenca/${name}"`
  - Update all `sleep 5` to remain (rate limit protection still needed)

## 3. Update CI/CD Workflows

- [x] 3.1 Modify `.github/workflows/release.yml`:
  - After `actions/setup-node@v4`, add step to install pnpm:
    ```yaml
    - uses: pnpm/action-setup@v4
      with:
        version: 9
    ```
  - Line 210: Change `npm publish --workspaces --provenance --access public` to `pnpm publish -r --provenance --access public`
- [x] 3.2 Review `.github/dependabot.yml`:
  - Keep `package-ecosystem: "npm"` as dependabot pnpm support is limited
  - Add comment explaining this is for npm registry, not npm CLI

## 4. Update Documentation

- [x] 4.1 Modify `CLAUDE.md`:
  - Update "Tech Stack" or similar sections to mention pnpm
  - Remove "npm E409 conflicts require sequential publishing" note (still applies but now uses pnpm)
  - Add note about pnpm being the internal package manager
- [x] 4.2 Modify `openspec/project.md`:
  - Update "Distribution:" from "npm" to "pnpm (publishing to npm registry)"
  - Update "Development Tools:" to include pnpm
  - Update any npm command examples to use pnpm equivalents

## 5. Verification

- [x] 5.1 Test local publish dry-run: `cd npm && pnpm publish -r --dry-run`
- [x] 5.2 Verify all 11 packages are detected: `cd npm && pnpm list -r --json | jq 'length'` should return 11
- [x] 5.3 Run lint checks: `mise run lint`
- [x] 5.4 Test `scripts/populate-npm.sh` with mock artifacts:
  - Create minimal mock artifact structure
  - Run populate script
  - Verify generated `npm/package.json` has only `{ "private": true }`
- [x] 5.5 Verify pnpm-workspace.yaml lists all packages correctly

## 6. Clean Up

- [x] 6.1 Remove any npm-only files that are no longer needed
- [x] 6.2 Ensure `.gitignore` includes `node_modules/` and `pnpm-lock.yaml` appropriately
- [ ] 6.3 Commit all changes with message: `refactor(npm): migrate from npm to pnpm for package management`

## Dependencies

- Tasks in Phase 1 (1.x) must complete before Phase 2 (2.x)
- Phase 2 and Phase 3 can run in parallel
- Phase 4 can run in parallel with Phase 2 and 3
- Phase 5 requires all previous phases
- Phase 6 is final cleanup

## Parallelizable Groups

| Group | Tasks | Rationale |
|-------|-------|-----------|
| Group A | 1.1-1.8 | Sequential - each builds on previous |
| Group B | 2.1, 2.2, 2.3 | Parallel - independent scripts |
| Group C | 3.1, 3.2 | Parallel - independent files |
| Group D | 4.1, 4.2 | Parallel - independent docs |
| Group E | 5.1-5.5 | Sequential - verification order matters |
| Group F | 6.1-6.3 | Sequential - cleanup after verification |
