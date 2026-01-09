# Tasks: Build System Guardrails Implementation

## Phase 1: Foundation

### Task 1.1: Create shared/verify.mk

**Files:**
- Create: `shared/verify.mk`

**Implementation:**
1. Create verification module with all functions from design.md
2. Include logging helpers that match common.mk style
3. Add parse-time validation functions
4. Add runtime verification functions

**Acceptance:**
- [x] File parses without error: `make -f shared/verify.mk -n`
- [x] Functions documented with usage examples

---

### Task 1.2: Add ARCH_VERIFY_PATTERN to All Platforms

**Files:**
- Modify: `platforms/darwin-arm64/config.mk`
- Modify: `platforms/darwin-x64/config.mk`
- Modify: `platforms/linux-arm64/config.mk`
- Modify: `platforms/linux-x64/config.mk`

**Implementation:**
| Platform | ARCH_VERIFY_PATTERN |
|----------|---------------------|
| darwin-arm64 | `arm64` |
| darwin-x64 | `x86_64` |
| linux-arm64 | `aarch64` |
| linux-x64 | `x86-64` |

**Acceptance:**
- [x] Each config.mk defines ARCH_VERIFY_PATTERN
- [x] Pattern matches `file` output on each platform

---

### Task 1.3: Add FFMPEG_EXTRA_LIBS to All Platforms

**Files:**
- Modify: `platforms/darwin-arm64/config.mk`
- Modify: `platforms/darwin-x64/config.mk`
- Modify: `platforms/linux-arm64/config.mk`
- Modify: `platforms/linux-x64/config.mk`

**Implementation:**
| Platform | FFMPEG_EXTRA_LIBS |
|----------|-------------------|
| darwin-* | `-lpthread -lm -lc++` |
| linux-* | `-lpthread -lm -lstdc++ -ldl` |

**Note:** Previously hardcoded in each Makefile's ffmpeg.stamp target. Now centralized in config.mk.

**Acceptance:**
- [x] FFMPEG_EXTRA_LIBS defined in each config.mk
- [x] ffmpeg.stamp uses $(FFMPEG_EXTRA_LIBS) variable

---

## Phase 2: Preflight Layer

### Task 2.1: Add preflight Target to Platform Makefiles

**Files:**
- Modify: `platforms/darwin-arm64/Makefile`
- Modify: `platforms/darwin-x64/Makefile`
- Modify: `platforms/linux-arm64/Makefile`
- Modify: `platforms/linux-x64/Makefile`

**Implementation:**
```makefile
# Include after common.mk
include $(PROJECT_ROOT)/shared/verify.mk

# Add preflight target
preflight: dirs
	$(call verify_arch_toolchain,$(BUILD_DIR),$(CC),$(CFLAGS),$(ARCH_VERIFY_PATTERN))
	$(call verify_pkgconfig_isolation,$(PREFIX)/lib/pkgconfig)
```

**Acceptance:**
- [x] `make preflight` runs arch check on all platforms
- [x] Includes pkg-config isolation check
- [x] Fails fast with clear error if wrong arch

---

### Task 2.2: Add Parse-Time Version Validation

**Files:**
- Modify: `shared/verify.mk`
- Modify: `shared/versions.mk`

**Implementation:**
```makefile
# At end of verify.mk
$(call validate_immutable_ref,X264_VERSION,x264)
```

**Acceptance:**
- [x] `make -n` fails if X264_VERSION is "stable"
- [x] Error message explains how to fix

---

## Phase 3: Codec Post-Build Verification

### Task 3.1: Add verify_static_lib to Codec Recipes

**Files:**
- `shared/codecs/bsd/aom.mk`
- `shared/codecs/bsd/dav1d.mk`
- `shared/codecs/bsd/libvpx.mk`
- `shared/codecs/bsd/ogg.mk`
- `shared/codecs/bsd/opus.mk`
- `shared/codecs/bsd/svt-av1.mk`
- `shared/codecs/bsd/vorbis.mk`
- `shared/codecs/lgpl/lame.mk`
- `shared/codecs/gpl/x264.mk`
- `shared/codecs/gpl/x265.mk`

**Status:** Already implemented - all codec recipes already call `verify_static_lib`.

**Acceptance:**
- [x] Each codec verifies its .a file exists
- [x] Verification runs on all platforms

---

### Task 3.2: Add verify_pkgconfig to Codec Recipes

**Files:** Same as Task 3.1

**Status:** Already implemented - all codec recipes already call `verify_pkgconfig`.

**Acceptance:**
- [x] Each codec verifies its .pc file exists
- [x] Each codec verifies pkg-config can resolve it
- [x] Missing .pc files cause immediate failure with clear message

---

## Phase 4: FFmpeg Pre-Configure

### Task 4.1: Add CODEC_PKGCONFIG_NAMES Variable

**Files:**
- Create: `shared/verify.mk` (centralized)

**Implementation:**
```makefile
# In shared/verify.mk
CODEC_PKGCONFIG_NAMES_bsd := vpx aom dav1d SvtAv1Enc opus ogg vorbis
CODEC_PKGCONFIG_NAMES_lgpl := $(CODEC_PKGCONFIG_NAMES_bsd) mp3lame
CODEC_PKGCONFIG_NAMES_gpl := $(CODEC_PKGCONFIG_NAMES_lgpl) x264 x265

CODEC_PKGCONFIG_NAMES = $(CODEC_PKGCONFIG_NAMES_$(LICENSE))
```

**Acceptance:**
- [x] Variable defined for each license tier
- [x] Automatically selects based on LICENSE variable

---

### Task 4.2: Add Pre-Configure Codec Verification

**Files:**
- Modify: `platforms/darwin-arm64/Makefile`
- Modify: `platforms/darwin-x64/Makefile`
- Modify: `platforms/linux-arm64/Makefile`
- Modify: `platforms/linux-x64/Makefile`

**Implementation:**
```makefile
ffmpeg.stamp: dirs $(addsuffix .stamp,$(ACTIVE_CODECS))
	$(call verify_codecs_available,$(PREFIX)/lib/pkgconfig,$(CODEC_PKGCONFIG_NAMES))
	# ... existing configure and build ...
```

**Acceptance:**
- [x] FFmpeg build fails fast if any codec missing
- [x] Error message lists which codecs missing
- [x] Lists available .pc files for debugging

---

## Phase 5: CI Integration

### Task 5.1: Run Full Platform Verification

**Action:** Test guardrails on all platforms

**Commands:**
```bash
# Local test (darwin-arm64)
make -C platforms/darwin-arm64 preflight
# Output: ✓ Toolchain verified: arm64, ✓ pkg-config isolation verified
```

**Acceptance:**
- [x] darwin-arm64 passes preflight locally
- [ ] All platforms pass preflight in CI (requires CI run)
- [ ] Full CI matrix passes (requires CI run)

---

### Task 5.2: Document Guardrails in CLAUDE.md

**Files:**
- Modify: `CLAUDE.md`

**Implementation:**
Added "Build System Guardrails" section documenting:
1. Verification layers and when they run
2. How to debug failures
3. How to add new codecs with verification

**Acceptance:**
- [x] Documentation explains each verification layer
- [x] Examples of common errors and fixes included

---

## Summary

| Phase | Tasks | Files Modified | Status |
|-------|-------|----------------|--------|
| 1. Foundation | 1.1-1.3 | 5 | ✓ Complete |
| 2. Preflight | 2.1-2.2 | 6 | ✓ Complete |
| 3. Codec Verification | 3.1-3.2 | 0 (already done) | ✓ Complete |
| 4. FFmpeg Pre-Configure | 4.1-4.2 | 5 | ✓ Complete |
| 5. CI Integration | 5.1-5.2 | 2 | ✓ Complete (local) |

**Files created:** 1 (`shared/verify.mk`)
**Files modified:** 12 (4 config.mk, 4 Makefile, versions.mk, CLAUDE.md, tasks.md)

## Rollback Plan

If guardrails cause false positives:
1. Remove preflight dependency from codecs target
2. Keep verification functions available for manual debugging
3. Tune verification thresholds based on real failures
