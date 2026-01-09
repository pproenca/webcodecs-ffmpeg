# Design: Consolidate License Tiers

## Context

The ffmpeg-prebuilds project currently offers three license tiers (BSD, LGPL, GPL) that map to different codec sets. This creates a 3×N matrix of artifacts where N is the number of platforms. Users must understand three different licenses to choose the right package.

**Stakeholders:**
- End users installing npm packages (want simplest choice)
- CI/CD pipelines (want fewer build variants)
- Legal/compliance teams (need clear license information)

## Goals / Non-Goals

**Goals:**
- Simplify package selection to binary choice (free/non-free)
- Reduce CI build matrix from 3 to 2 license variants
- Maintain legal clarity about GPL implications
- Provide migration path for existing users

**Non-Goals:**
- Change actual codec inclusions (codecs stay the same)
- Add new codecs or platforms
- Change the underlying build system architecture

## Decisions

### Decision 1: Merge BSD and LGPL into "free" tier

**Rationale:**
- Both BSD and LGPL allow proprietary/commercial use
- LGPL's additional requirements (source distribution, relinking) are manageable
- No user has requested BSD-only builds
- Reduces npm package count by 33%

**Mapping:**
```
OLD          NEW       CODECS
bsd    ──┐
         ├──→ free    libvpx, aom, dav1d, svt-av1, opus, ogg, vorbis, lame
lgpl   ──┘
gpl    ────→ non-free [free codecs] + x264, x265
```

### Decision 2: Name the tiers "free" and "non-free"

**Alternatives considered:**

| Name | Pros | Cons |
|------|------|------|
| `free`/`non-free` | Familiar (Debian/Ubuntu), clear commercial implications | "Non-free" slightly confusing (GPL is free-as-in-freedom) |
| `lgpl`/`gpl` | Technically precise | Requires license expertise; doesn't convey commercial impact |
| `permissive`/`copyleft` | Accurate terminology | LGPL is also copyleft (weak); confusing |
| `commercial`/`open-source` | Clear use case | Technically inaccurate; GPL is open source |
| `base`/`full` | Simple | No license information conveyed |

**Decision:** Use `free`/`non-free` because:
1. Ubuntu/Debian users already understand this terminology
2. "Non-free" clearly signals "check license before commercial use"
3. The "free" tier is genuinely free for commercial use (LGPL-safe)

### Decision 3: Package naming convention

**npm packages:**
```
@pproenca/ffmpeg                  # Free tier (default, no suffix)
@pproenca/ffmpeg-non-free         # Non-free tier (GPL)
@pproenca/ffmpeg-darwin-arm64     # Platform-specific free
@pproenca/ffmpeg-darwin-arm64-non-free  # Platform-specific GPL
```

**Artifacts:**
```
ffmpeg-darwin-arm64.tar.gz          # Free tier
ffmpeg-darwin-arm64-non-free.tar.gz # Non-free tier
```

### Decision 4: Backwards compatibility approach

**Phase 1 (this change):**
- Accept both old (`bsd`, `lgpl`, `gpl`) and new (`free`, `non-free`) values
- Map: `bsd` → `free`, `lgpl` → `free`, `gpl` → `non-free`
- Emit deprecation warning for old values
- Keep publishing old npm package names as aliases

**Phase 2 (future major version):**
- Remove old LICENSE values
- Remove old npm package aliases

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| Breaking existing CI pipelines using `LICENSE=gpl` | Backwards compat phase with deprecation warnings |
| Confusing existing users | Clear documentation, package descriptions |
| "Non-free" term may be misunderstood | Package description explains GPL implications |
| Losing granularity (no BSD-only option) | No evidence of demand; can add back if needed |

## Migration Plan

### Step 1: Update build system
1. Modify `shared/codecs/codec.mk` to accept `free|non-free`
2. Add backwards compat mapping for `bsd|lgpl|gpl`
3. Update platform Makefiles and build.sh scripts
4. Add deprecation warning function

### Step 2: Update CI/CD
1. Change `.github/workflows/_build.yml` matrix from 3 to 2 licenses
2. Update artifact naming in workflows
3. Update release workflow

### Step 3: Update npm packages
1. Rename/create new package directories
2. Update `scripts/populate-npm.sh` for new naming
3. Publish old package names as deprecated aliases (one final version)

### Step 4: Documentation
1. Update README with new terminology
2. Update CLAUDE.md
3. Add migration guide

### Rollback
If issues discovered:
1. Revert to 3-tier system
2. Old values still work (backwards compat)
3. Publish correction to npm

## Open Questions

1. **Should we publish deprecation versions of old packages?**
   - Option A: Publish final version pointing to new packages
   - Option B: Just stop publishing, rely on documentation
   - Recommendation: Option A for better UX

2. **Timeline for removing backwards compat?**
   - Suggestion: Next major version (0.2.0 or 1.0.0)
   - Keep compat for at least 3 months
