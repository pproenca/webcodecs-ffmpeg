# Change: Replace npm with pnpm for Package Management

## Why

The current npm + Lerna setup has several limitations:

1. **Slower CI/CD**: npm lacks pnpm's content-addressable storage and efficient dependency resolution
2. **Redundant tooling**: Lerna is used only for `npmClient` configuration; pnpm workspaces provide native monorepo support
3. **No lockfile**: npm workspaces without a lockfile makes builds less reproducible
4. **Rate limit issues**: npm E409 conflicts require manual retry logic (documented in CLAUDE.md)

pnpm offers:
- **Disk efficiency**: Content-addressable storage shares dependencies across projects
- **Faster installs**: 2-3x faster than npm for clean installs
- **Native workspaces**: Built-in monorepo support without Lerna
- **Strict mode**: Better isolation prevents phantom dependencies
- **Provenance support**: Native `--provenance` flag matches current npm usage

## What Changes

### Configuration Files

- **ADD** `npm/pnpm-workspace.yaml` - Workspace definition
- **ADD** `npm/.npmrc` - pnpm-specific settings (registry, access)
- **REMOVE** `npm/lerna.json` - No longer needed
- **MODIFY** `npm/package.json` - Remove workspaces field (moves to pnpm-workspace.yaml)
- **MODIFY** `.mise.toml` - Add pnpm tool

### CI/CD Workflows

- **MODIFY** `.github/workflows/release.yml` - Replace `npm publish` with `pnpm publish`
- **MODIFY** `.github/dependabot.yml` - Change ecosystem from npm to pnpm (if supported)

### Scripts

- **MODIFY** `scripts/populate-npm.sh` - Update workspace config generation
- **MODIFY** `scripts/local-publish.sh` - Replace npm commands with pnpm
- **MODIFY** `scripts/publish-stubs.sh` - Replace npm commands with pnpm

### Documentation

- **MODIFY** `CLAUDE.md` - Update references from npm to pnpm
- **MODIFY** `openspec/project.md` - Update tech stack section

## Impact

- **Affected specs**: None currently exist (this is first spec)
- **Affected code**: npm/, scripts/, .github/workflows/, mise.toml
- **Breaking changes**: None - external consumers still use `npm install @pproenca/ffmpeg`
- **Migration effort**: Low - pnpm is a drop-in replacement for most npm commands
- **Risk**: Low - can rollback by reverting config files

## Compatibility Notes

- Consumers continue using npm/yarn/pnpm to install packages
- Package structure unchanged - only internal tooling migrates
- Provenance attestations work identically with pnpm
- GitHub Actions setup-node works with pnpm registry
