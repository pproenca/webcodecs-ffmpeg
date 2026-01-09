## Context

This project distributes prebuilt FFmpeg binaries as npm packages. The current setup uses:

1. **npm workspaces** (`npm/package.json` with `workspaces` field)
2. **Lerna** (`npm/lerna.json` with `npmClient: "npm"`)
3. **11 packages** in the workspace (2 meta, 8 platform, 1 dev)

The npm registry is the distribution target - consumers use npm/yarn/pnpm to install. This change only affects internal tooling, not consumers.

## Goals / Non-Goals

**Goals:**
- Replace npm CLI with pnpm for internal operations
- Remove Lerna dependency (pnpm provides native workspace support)
- Maintain identical package publishing behavior
- Preserve provenance attestations

**Non-Goals:**
- Change package structure or naming
- Migrate consumers to pnpm (they choose their package manager)
- Add monorepo features beyond current usage (changesets, version management)

## Decisions

### Decision 1: Remove Lerna

**What:** Delete `npm/lerna.json` and use pnpm native workspaces.

**Why:**
- Lerna is only used for `npmClient` configuration
- pnpm provides `pnpm publish -r` for recursive workspace publishing
- Reduces dependencies and complexity
- Lerna's version management features are unused (project uses independent versioning via `populate-npm.sh`)

**Alternatives considered:**
- Keep Lerna with `npmClient: "pnpm"` - adds unnecessary layer
- Use Changesets for versioning - overkill for this project's simple versioning

### Decision 2: pnpm-workspace.yaml Structure

**What:** Use explicit package list matching current npm workspaces.

```yaml
packages:
  - 'dev'
  - 'ffmpeg'
  - 'ffmpeg-non-free'
  - 'darwin-arm64'
  - 'darwin-arm64-non-free'
  - 'darwin-x64'
  - 'darwin-x64-non-free'
  - 'linux-arm64'
  - 'linux-arm64-non-free'
  - 'linux-x64'
  - 'linux-x64-non-free'
```

**Why:**
- Explicit list matches current npm workspaces exactly
- Avoids glob patterns that might accidentally include build artifacts
- `populate-npm.sh` dynamically creates package directories - explicit list is clearer

**Alternatives considered:**
- Use `packages: ['*']` - risks including unintended directories
- Use `packages: ['dev', 'ffmpeg*', 'darwin-*', 'linux-*']` - less explicit

### Decision 3: .npmrc Configuration

**What:** Create `npm/.npmrc` with minimal settings:

```ini
# Registry and authentication handled by CI environment
# Access control for scoped packages
access=public

# Workspace behavior
link-workspace-packages=false
prefer-workspace-packages=false

# Performance
prefer-offline=true
```

**Why:**
- `access=public` ensures `@pproenca/*` packages are public by default
- `link-workspace-packages=false` because these packages don't depend on each other
- `prefer-offline=true` speeds up CI when dependencies are cached
- Registry/auth left to environment (GitHub Actions setup-node handles this)

### Decision 4: pnpm Version Pinning

**What:** Pin pnpm version in `mise.toml`:

```toml
[tools]
pnpm = "9"  # Major version pin for stability
```

**Why:**
- pnpm 9 is current stable with workspace publishing support
- Major version pin allows minor/patch updates
- mise manages tool versions consistently across development/CI

**Alternatives considered:**
- Pin exact version (e.g., `9.15.0`) - too restrictive
- Use `latest` - risks breaking changes

### Decision 5: CI Publishing Command

**What:** Replace `npm publish --workspaces` with `pnpm publish -r`:

```yaml
# Before
- run: cd npm && npm publish --workspaces --provenance --access public

# After
- run: cd npm && pnpm publish -r --provenance --access public
```

**Why:**
- pnpm's `-r` flag recursively publishes all workspace packages
- `--provenance` flag works identically
- `--access public` is set in `.npmrc` but can be explicit
- No `--workspaces` equivalent needed - pnpm assumes workspace context

### Decision 6: Lockfile Strategy

**What:** Add `pnpm-lock.yaml` to workspace but keep it minimal.

**Why:**
- This workspace has no runtime dependencies (packages are self-contained binaries)
- Lockfile provides reproducibility for any future dev dependencies
- GitHub Actions caching works with lockfile

**Alternatives considered:**
- No lockfile - less reproducible
- Full lockfile - unnecessary for dependency-free packages

## Risks / Trade-offs

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| pnpm publish behaves differently | Low | Medium | Test with `--dry-run` before actual release |
| GitHub Actions cache invalidation | Low | Low | Initial release may be slower; cache rebuilds |
| Team unfamiliar with pnpm | Low | Low | pnpm commands are similar to npm |

## Migration Plan

### Phase 1: Add pnpm Configuration
1. Add pnpm to `mise.toml`
2. Create `npm/pnpm-workspace.yaml`
3. Create `npm/.npmrc`
4. Update `npm/package.json` (remove workspaces field)
5. Delete `npm/lerna.json`

### Phase 2: Update Scripts
1. Update `scripts/populate-npm.sh` to not generate workspaces field
2. Update `scripts/local-publish.sh` to use pnpm
3. Update `scripts/publish-stubs.sh` to use pnpm

### Phase 3: Update CI/CD
1. Update `.github/workflows/release.yml`
2. Update `.github/dependabot.yml` (if pnpm ecosystem supported)

### Phase 4: Documentation
1. Update `CLAUDE.md`
2. Update `openspec/project.md`

### Rollback Plan
1. Revert all files to previous state
2. No data migration needed - npm registry is unaffected
3. Git revert of the PR is sufficient

## Open Questions

1. **Should we use pnpm's corepack integration?**
   - Pro: Ensures correct pnpm version without mise
   - Con: Adds package.json `packageManager` field; mise already handles versioning
   - **Decision:** Skip corepack, use mise for version management

2. **Should publish jobs run in parallel or sequentially?**
   - Current: Sequential with retry for E409
   - pnpm: Same behavior needed to avoid race conditions
   - **Decision:** Keep sequential publishing, pnpm doesn't solve npm registry rate limits

3. **Should we add pnpm to dependabot?**
   - Dependabot has limited pnpm support
   - Project has no runtime dependencies anyway
   - **Decision:** Keep npm ecosystem in dependabot for now; revisit if deps added
