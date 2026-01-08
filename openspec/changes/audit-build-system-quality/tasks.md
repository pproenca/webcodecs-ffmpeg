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
- [ ] File parses without error: `make -f shared/verify.mk -n`
- [ ] Functions documented with usage examples

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
- [ ] Each config.mk defines ARCH_VERIFY_PATTERN
- [ ] Pattern matches `file` output on each platform

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
| darwin-* | `-lpthread -lm` |
| linux-* | `-lpthread -lm -lstdc++ -ldl` |

**Note:** Currently hardcoded in each Makefile's ffmpeg.stamp target. Centralize in config.mk.

**Acceptance:**
- [ ] FFMPEG_EXTRA_LIBS defined in each config.mk
- [ ] ffmpeg.stamp uses $(FFMPEG_EXTRA_LIBS) variable

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

# Make codecs depend on preflight
codecs: preflight $(addsuffix .stamp,$(ACTIVE_CODECS))
```

**Acceptance:**
- [ ] `make preflight` runs arch check on all platforms
- [ ] `make codecs` runs preflight first
- [ ] Fails fast with clear error if wrong arch

---

### Task 2.2: Add Parse-Time Version Validation

**Files:**
- Modify: `shared/versions.mk`

**Implementation:**
```makefile
# At end of versions.mk
include $(dir $(lastword $(MAKEFILE_LIST)))/verify.mk

# Validate no mutable refs
$(call validate_immutable_ref,X264_VERSION,x264)
# ... other git-cloned deps
```

**Acceptance:**
- [ ] `make -n` fails if X264_VERSION is "stable"
- [ ] Error message explains how to fix

---

## Phase 3: Codec Post-Build Verification

### Task 3.1: Add verify_static_lib to Codec Recipes

**Files:**
- Modify: `shared/codecs/bsd/aom.mk`
- Modify: `shared/codecs/bsd/dav1d.mk`
- Modify: `shared/codecs/bsd/libvpx.mk`
- Modify: `shared/codecs/bsd/ogg.mk`
- Modify: `shared/codecs/bsd/opus.mk`
- Modify: `shared/codecs/bsd/svt-av1.mk`
- Modify: `shared/codecs/bsd/vorbis.mk`
- Modify: `shared/codecs/lgpl/lame.mk`
- Modify: `shared/codecs/gpl/x264.mk`
- Modify: `shared/codecs/gpl/x265.mk`

**Implementation:**
Add before `@touch $(STAMPS_DIR)/$@`:
```makefile
$(call verify_static_lib,$(PREFIX)/lib/lib<name>.a,$(ARCH_VERIFY_PATTERN))
```

**Acceptance:**
- [ ] Each codec verifies its .a file exists
- [ ] Each codec verifies .a has correct architecture
- [ ] Verification runs on all platforms

---

### Task 3.2: Add verify_pkgconfig to Codec Recipes

**Files:** Same as Task 3.1

**Implementation:**
Add before `@touch $(STAMPS_DIR)/$@`:
```makefile
$(call verify_pkgconfig,$(PREFIX)/lib/pkgconfig/<name>.pc,<pkgname>)
```

**Mapping:**
| Codec | Library | pkg-config name |
|-------|---------|-----------------|
| aom | libaom.a | aom |
| dav1d | libdav1d.a | dav1d |
| libvpx | libvpx.a | vpx |
| ogg | libogg.a | ogg |
| opus | libopus.a | opus |
| svt-av1 | libSvtAv1Enc.a | SvtAv1Enc |
| vorbis | libvorbis.a | vorbis |
| lame | libmp3lame.a | mp3lame |
| x264 | libx264.a | x264 |
| x265 | libx265.a | x265 |

**Acceptance:**
- [ ] Each codec verifies its .pc file exists
- [ ] Each codec verifies pkg-config can resolve it
- [ ] Missing .pc files cause immediate failure with clear message

---

## Phase 4: FFmpeg Pre-Configure

### Task 4.1: Add CODEC_PKGCONFIG_NAMES Variable

**Files:**
- Modify: `platforms/darwin-arm64/Makefile`
- Modify: `platforms/darwin-x64/Makefile`
- Modify: `platforms/linux-arm64/Makefile`
- Modify: `platforms/linux-x64/Makefile`

**Implementation:**
```makefile
# List of pkg-config names for active codecs
CODEC_PKGCONFIG_NAMES_bsd := vpx aom dav1d SvtAv1Enc opus ogg vorbis
CODEC_PKGCONFIG_NAMES_lgpl := $(CODEC_PKGCONFIG_NAMES_bsd) mp3lame
CODEC_PKGCONFIG_NAMES_gpl := $(CODEC_PKGCONFIG_NAMES_lgpl) x264 x265

CODEC_PKGCONFIG_NAMES := $(CODEC_PKGCONFIG_NAMES_$(LICENSE))
```

**Acceptance:**
- [ ] Variable defined for each license tier
- [ ] `make LICENSE=gpl codecs-info` shows correct list

---

### Task 4.2: Add Pre-Configure Codec Verification

**Files:**
- Modify: `platforms/darwin-arm64/Makefile`
- Modify: `platforms/darwin-x64/Makefile`
- Modify: `platforms/linux-arm64/Makefile`
- Modify: `platforms/linux-x64/Makefile`

**Implementation:**
Add to ffmpeg.stamp before configure:
```makefile
ffmpeg.stamp: dirs $(addsuffix .stamp,$(ACTIVE_CODECS))
	$(call verify_codecs_available,$(PREFIX)/lib/pkgconfig,$(CODEC_PKGCONFIG_NAMES))
	# ... existing configure and build ...
```

**Acceptance:**
- [ ] FFmpeg build fails fast if any codec missing
- [ ] Error message lists which codecs missing
- [ ] Lists available .pc files for debugging

---

## Phase 5: CI Integration

### Task 5.1: Run Full Platform Verification

**Action:** Test guardrails on all platforms

**Commands:**
```bash
# Local test (darwin)
make -C platforms/darwin-arm64 preflight
make -C platforms/darwin-x64 preflight

# CI test (all platforms)
# Push branch, verify CI passes
```

**Acceptance:**
- [ ] All platforms pass preflight
- [ ] All platforms pass codec verification
- [ ] All platforms pass FFmpeg pre-configure check
- [ ] Full CI matrix passes

---

### Task 5.2: Document Guardrails in CLAUDE.md

**Files:**
- Modify: `CLAUDE.md`

**Implementation:**
Add section documenting:
1. Verification layers and when they run
2. How to debug failures
3. How to add new codecs with verification

**Acceptance:**
- [ ] Documentation explains each verification layer
- [ ] Examples of common errors and fixes included

---

## Summary

| Phase | Tasks | Files Modified | Risk |
|-------|-------|----------------|------|
| 1. Foundation | 1.1-1.3 | 5 | Low (additive) |
| 2. Preflight | 2.1-2.2 | 5 | Low (new target) |
| 3. Codec Verification | 3.1-3.2 | 10 | Low (before stamp) |
| 4. FFmpeg Pre-Configure | 4.1-4.2 | 4 | Low (before build) |
| 5. CI Integration | 5.1-5.2 | 2 | Low (validation) |

**Total:** 26 files modified/created

**Estimated effort:** Each phase can be done independently and tested.

## Rollback Plan

If guardrails cause false positives:
1. Remove preflight from codecs dependency (revert Task 2.1)
2. Keep verification functions available for manual debugging
3. Tune verification thresholds based on real failures
