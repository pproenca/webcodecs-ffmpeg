# Change: Audit Build System Quality - Regression Prevention Guardrails

## Why

Analysis of the last 50 commits reveals **22 fix/revert/debug commits (44%)** - an unacceptable regression rate. Most fixes address the same root causes repeatedly because the build system lacks guardrails that would catch issues early (at the right layer) rather than late (as cryptic downstream symptoms).

## Root Cause Analysis

### Regression Classes Identified

| Class | Commits | Root Pattern | Detection Gap |
|-------|---------|--------------|---------------|
| **PKG_CONFIG isolation** | 5 | Env vars don't propagate to subprocesses | No isolation verification |
| **Cross-compilation** | 6 | Wrong arch binaries, missing --host flags | No pre-build arch checks |
| **Static linking deps** | 3 | Missing -ldl, -lc++, etc. | No link-time verification |
| **Cache correctness** | 2 | Mutable refs (branches) cause stale builds | No cache key validation |
| **CI race conditions** | 2 | npm E409, workflow timing | No retry patterns |
| **Toolchain version** | 2 | CMake 4.x, NASM incompatibility | No version pinning validation |

### The Symptom vs Root Cause Problem

**Example: x265 "not found" error chain**
```
Symptom: ERROR: x265 not found using pkg-config
├─ First hypothesis: PKG_CONFIG_LIBDIR not set → Fix: add export (wrong)
├─ Second hypothesis: export doesn't propagate → Fix: inline prefix (partial)
├─ Third hypothesis: FFmpeg looks for wrong pkg-config → Fix: --pkg-config flag (partial)
└─ Root cause: -ldl missing from linker flags → Fix: add -ldl (correct)
```

This took **5 commits over 2 days** to diagnose because the error message didn't reflect the actual failure.

## What Changes

### 1. Pre-Build Verification Layer (New)

Add verification BEFORE expensive builds fail:

```makefile
# Run before ffmpeg.stamp, not after
preflight: dirs
    @$(call verify_pkgconfig_isolation)
    @$(call verify_arch_toolchain)
    @$(call verify_static_libs)
```

### 2. Diagnostic Error Messages

Replace cryptic failures with actionable messages:

```makefile
define verify_pkgconfig_isolation
    @if ! PKG_CONFIG_LIBDIR="$(PREFIX)/lib/pkgconfig" pkg-config --exists aom 2>/dev/null; then \
        echo "ERROR: aom.pc not found in $(PREFIX)/lib/pkgconfig"; \
        echo "  - Check: ls $(PREFIX)/lib/pkgconfig/aom.pc"; \
        echo "  - Check: PKG_CONFIG_LIBDIR is set correctly"; \
        exit 1; \
    fi
endef
```

### 3. Explicit Link Dependency Declaration

Codify platform-specific link requirements:

```makefile
# shared/codecs/gpl/x265.mk
X265_EXTRA_LIBS_linux := -ldl -lpthread
X265_EXTRA_LIBS_darwin :=
X265_EXTRA_LIBS := $(X265_EXTRA_LIBS_$(OS))
```

### 4. Cache Key Hardening

Enforce immutable refs in versions.mk:

```makefile
# Validation: reject branch names
define validate_version_ref
    $(if $(filter stable master main,$(1)),\
        $(error $(2) uses mutable ref '$(1)'. Use commit hash instead.))
endef
$(call validate_version_ref,$(X264_VERSION),X264)
```

### 5. Architecture Verification Contract

Verify toolchain produces correct arch BEFORE building all codecs:

```makefile
arch-check: dirs
    @echo "int main() { return 0; }" > $(BUILD_DIR)/arch_test.c
    @$(CC) $(CFLAGS) $(BUILD_DIR)/arch_test.c -o $(BUILD_DIR)/arch_test
    @file $(BUILD_DIR)/arch_test | grep -q "$(ARCH_VERIFY_PATTERN)" || \
        (echo "ERROR: Toolchain produces wrong architecture"; exit 1)
    @rm -f $(BUILD_DIR)/arch_test.c $(BUILD_DIR)/arch_test
```

### 6. Build Contract Verification

Each codec recipe verifies its contract before signaling success:

```makefile
# After build, before .stamp
$(call verify_static_lib,$(PREFIX)/lib/libx265.a,$(ARCH_VERIFY_PATTERN))
$(call verify_pkgconfig,$(PREFIX)/lib/pkgconfig/x265.pc)
```

## Impact

### Files Affected

| Category | Files | Changes |
|----------|-------|---------|
| New shared module | `shared/verify.mk` | New: preflight checks, error formatting |
| Platform Makefiles | `platforms/*/Makefile` (4) | Add preflight target, verification calls |
| Codec recipes | `shared/codecs/*/*.mk` (10) | Add post-build verification |
| Config files | `platforms/*/config.mk` (4) | Add ARCH_VERIFY_PATTERN, EXTRA_LIBS |
| versions.mk | `shared/versions.mk` | Add cache key validation |

### Risk Assessment

- **Breaking risk:** Low - adds verification, doesn't change build logic
- **CI impact:** May add ~10s to builds for preflight checks
- **False positive risk:** Medium - need to tune verification thresholds

### Expected Outcomes

1. **PKG_CONFIG issues** → Caught at preflight, not 45 minutes into build
2. **Wrong architecture** → Caught before any codec builds
3. **Missing link deps** → Caught at codec stamp, with specific message
4. **Stale cache** → Prevented by version validation at `make` parse time

## Evidence from Commit History

### Pattern 1: Iterative Debugging (Bad)
```
7bfe572 debug(linux-arm64): add pkg-config debug output for x265 issue
f9ee302 debug(linux-arm64): use pkg-config wrapper to trace all calls
942cd17 debug(linux-arm64): show config.log on configure failure
62fc534 fix(linux): add -ldl for x265 dynamic loading
```
Four commits to diagnose one issue. With guardrails: preflight would show "x265.pc exists, pkg-config finds it, but link check fails with undefined dlopen".

### Pattern 2: Same Fix Across Platforms (Waste)
```
67d3a61 fix(darwin-x64): add PKG_CONFIG_LIBDIR export
4b9dbfb fix(build): use inline env vars for PKG_CONFIG_LIBDIR isolation
846f927 fix(linux): override pkg-config binary for cross-compilation
```
Each platform hit the same issue at different times. With guardrails: centralized `verify_pkgconfig_isolation` catches this once.

### Pattern 3: Reverts (Friction)
```
ab749e0 feat(ci): add ccache for faster incremental builds
bd6f483 Revert "feat(ci): add ccache for faster incremental builds"
```
Feature added then reverted. With guardrails: preflight verification of ccache integration before merging.

## Non-Goals

- Not refactoring Makefiles for less duplication (separate proposal)
- Not changing build logic or codec selection
- Not adding new platforms or codecs

## Success Criteria

After implementation, regression pattern commits should:
1. **Decrease by 50%** - Fewer symptom-chasing fixes
2. **Resolve in 1 commit** - When issues occur, root cause is identified first
3. **Provide actionable errors** - No more "x265 not found" when -ldl is missing

## Alternatives Considered

1. **Do nothing:** Accept 44% fix rate, document patterns in CLAUDE.md (current state)
2. **Heavy testing framework:** Overkill for build system
3. **CI-only checks:** Too late - fails after 30+ minute builds
4. **Guardrails in Makefile:** Chosen - catches issues at the right layer
