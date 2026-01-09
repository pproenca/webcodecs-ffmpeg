# Change: Consolidate License Tiers to Free/Non-Free

## Why

The current three-tier licensing model (BSD, LGPL, GPL) creates unnecessary complexity for users who just want to know: "Can I use this in my proprietary software without source disclosure?" The Ubuntu/Debian model of "free" vs "non-free" (or "restricted") is more intuitive and reflects how users actually think about licensing.

## What Changes

- **BREAKING**: Rename `LICENSE=bsd|lgpl|gpl` to `LICENSE=free|non-free`
- **BREAKING**: Consolidate npm packages from 3 tiers to 2 tiers:
  - `@pproenca/ffmpeg` (free) → BSD + LGPL codecs (no suffix, default)
  - `@pproenca/ffmpeg-non-free` → BSD + LGPL + GPL codecs (x264/x265)
- Remove separate `-lgpl` packages (merged into base/free package)
- Update CI matrix from 3 licenses to 2

## Research Findings

### License Compatibility Analysis

| License | FFmpeg Build Flag | Source Disclosure | Proprietary-Safe |
|---------|-------------------|-------------------|------------------|
| BSD-3-Clause | (none) | No | Yes |
| LGPL-2.1+ | (none) | Only FFmpeg source | Yes (with conditions) |
| GPL-2.0+ | `--enable-gpl` | **All linked source** | **No** |

**Key insight**: The real dividing line is GPL's "viral" copyleft, not BSD vs LGPL. LGPL allows proprietary use with reasonable conditions (distribute FFmpeg source, allow relinking). GPL requires disclosing **all** application source code.

### How Ubuntu/Debian Does It

- **main**: Free software (DFSG-compliant) - includes LGPL
- **non-free**: Not DFSG-compliant (patent issues, GPL conflicts)
- **restricted** (Ubuntu): Proprietary drivers, patent-encumbered codecs

Ubuntu's `ffmpeg` package in main is LGPL by default. GPL codecs (x264) are in `libx264-dev` and require explicit installation.

### Proposed Grouping

| New Tier | Codecs | License | Use Case |
|----------|--------|---------|----------|
| `free` (default) | libvpx, aom, dav1d, svt-av1, opus, ogg, vorbis, lame | LGPL-2.1+ | Commercial/proprietary apps (with LGPL compliance) |
| `non-free` | Above + x264, x265 | GPL-2.0+ | Open source projects, personal use |

**Why "non-free" and not "gpl"?**
- Aligns with Debian/Ubuntu terminology users already know
- "GPL" sounds free but actually restricts commercial use
- "Non-free" clearly signals: "check the license before commercial use"

## Impact

- Affected specs: None (no existing specs)
- Affected code:
  - `shared/codecs/codec.mk` - LICENSE variable values
  - `platforms/*/Makefile` - LICENSE handling
  - `platforms/*/build.sh` - LICENSE validation
  - `.github/workflows/_build.yml` - matrix licenses
  - `scripts/populate-npm.sh` - package generation
  - `npm/*/package.json` - package names and descriptions
  - `docker/build.sh` - LICENSE handling

## Alternatives Considered

### 1. Keep Three Tiers (Status Quo)
- Pro: Precise license information
- Con: Confusing for users; LGPL package rarely needed standalone

### 2. Use "proprietary-safe" / "open-source-only"
- Pro: Very clear meaning
- Con: Non-standard terminology, verbose

### 3. Use "permissive" / "copyleft"
- Pro: Technically accurate
- Con: LGPL is also copyleft; requires license expertise

### 4. Keep BSD as separate tier
- Pro: Maximum flexibility
- Con: No practical use case; BSD and LGPL are both commercial-safe

## Migration Path

1. Support both old (`bsd|lgpl|gpl`) and new (`free|non-free`) values temporarily
2. Map old to new: `bsd|lgpl` → `free`, `gpl` → `non-free`
3. Deprecation warning for old values
4. Remove old values in next major version
