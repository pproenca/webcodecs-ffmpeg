# Design: Build System Guardrails Architecture

## Overview

This design introduces a **layered verification architecture** that catches build issues at the earliest possible point, with actionable error messages that identify root causes rather than symptoms.

## Verification Layers

```
┌─────────────────────────────────────────────────────────────────┐
│                     Layer 0: Parse Time                         │
│  versions.mk validation, required variable checks               │
│  Catches: mutable refs, missing config, invalid versions        │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                   Layer 1: Preflight (make preflight)           │
│  Toolchain arch check, pkg-config isolation, system deps        │
│  Catches: wrong arch toolchain, missing tools, env issues       │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                   Layer 2: Codec Post-Build                     │
│  verify_static_lib, verify_pkgconfig per codec                  │
│  Catches: build failures that silently pass, wrong arch libs    │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                   Layer 3: FFmpeg Pre-Configure                 │
│  Verify all codec .pc files exist and resolve                   │
│  Catches: missing codecs before 30-min FFmpeg build             │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                   Layer 4: make verify (Post-Build)             │
│  Binary execution, architecture, static linkage                 │
│  Catches: runtime issues, dynamic deps, wrong final binary      │
└─────────────────────────────────────────────────────────────────┘
```

## Module: shared/verify.mk

### Design Principles

1. **Fail fast with context** - Every check includes remediation hints
2. **Idempotent** - Safe to run multiple times
3. **Cross-platform** - Works on darwin and linux
4. **Minimal overhead** - Quick checks, no builds

### Core Functions

```makefile
# =============================================================================
# shared/verify.mk - Build Verification Functions
# =============================================================================
# Provides layered verification to catch issues early with actionable errors.
# Include after common.mk which defines logging functions.
# =============================================================================

# -----------------------------------------------------------------------------
# Layer 0: Parse-Time Validation
# -----------------------------------------------------------------------------

# Validate version refs are immutable (not branch names)
# Usage: $(call validate_immutable_ref,VERSION_VAR,COMPONENT_NAME)
define validate_immutable_ref
$(if $(filter stable master main HEAD,$($(1))),\
    $(error $(2) uses mutable ref '$($(1))'. Pin to commit hash for cache correctness.))
endef

# Ensure required variable is set
# Usage: $(call require_var,VAR_NAME,PURPOSE)
define require_var
$(if $($(1)),,$(error $(1) must be defined. $(2)))
endef

# -----------------------------------------------------------------------------
# Layer 1: Preflight Checks
# -----------------------------------------------------------------------------

# Verify toolchain produces correct architecture
# Usage: $(call verify_arch_toolchain,BUILD_DIR,CC,CFLAGS,EXPECTED_PATTERN)
define verify_arch_toolchain
	@echo "Verifying toolchain architecture..."
	@echo 'int main() { return 0; }' > $(1)/arch_test.c
	@$(2) $(3) -o $(1)/arch_test $(1)/arch_test.c 2>/dev/null || \
		(echo "ERROR: Toolchain compilation failed"; \
		 echo "  CC=$(2)"; \
		 echo "  CFLAGS=$(3)"; \
		 exit 1)
	@file $(1)/arch_test | grep -q "$(4)" || \
		(echo "ERROR: Toolchain produces wrong architecture"; \
		 echo "  Expected: $(4)"; \
		 echo "  Got: $$(file $(1)/arch_test)"; \
		 echo "  Check CC and CFLAGS in config.mk"; \
		 exit 1)
	@rm -f $(1)/arch_test.c $(1)/arch_test
	@echo "  ✓ Toolchain verified: $(4)"
endef

# Verify pkg-config isolation (only finds our libs, not system)
# Usage: $(call verify_pkgconfig_isolation,PKG_CONFIG_LIBDIR)
define verify_pkgconfig_isolation
	@echo "Verifying pkg-config isolation..."
	@if PKG_CONFIG_LIBDIR="$(1)" pkg-config --exists glib-2.0 2>/dev/null; then \
		echo "WARNING: pkg-config finds system libs (glib-2.0)"; \
		echo "  PKG_CONFIG_LIBDIR=$(1)"; \
		echo "  System libs may leak into build"; \
	fi
	@echo "  ✓ pkg-config isolation verified"
endef

# -----------------------------------------------------------------------------
# Layer 2: Codec Post-Build Verification
# -----------------------------------------------------------------------------

# Verify static library exists and has correct architecture
# Usage: $(call verify_static_lib,LIB_PATH,ARCH_PATTERN)
define verify_static_lib
	@if [ ! -f "$(1)" ]; then \
		echo "ERROR: Static library not found: $(1)"; \
		echo "  Build may have failed silently"; \
		exit 1; \
	fi
	@file "$(1)" | grep -q "$(2)" || \
		(echo "ERROR: Library has wrong architecture: $(1)"; \
		 echo "  Expected: $(2)"; \
		 echo "  Got: $$(file $(1))"; \
		 exit 1)
endef

# Verify pkg-config file exists and resolves
# Usage: $(call verify_pkgconfig,PC_PATH,PKG_NAME)
define verify_pkgconfig
	@if [ ! -f "$(1)" ]; then \
		echo "ERROR: pkg-config file not found: $(1)"; \
		echo "  Codec build may have failed or skipped pkg-config generation"; \
		exit 1; \
	fi
	@if ! PKG_CONFIG_LIBDIR="$$(dirname $(1))" pkg-config --exists $(2) 2>/dev/null; then \
		echo "ERROR: pkg-config cannot resolve $(2)"; \
		echo "  File exists: $(1)"; \
		echo "  But pkg-config --exists fails"; \
		echo "  Check .pc file syntax"; \
		exit 1; \
	fi
endef

# -----------------------------------------------------------------------------
# Layer 3: FFmpeg Pre-Configure Verification
# -----------------------------------------------------------------------------

# Verify all required codecs are available before FFmpeg configure
# Usage: $(call verify_codecs_available,PKG_CONFIG_LIBDIR,CODEC_LIST)
define verify_codecs_available
	@echo "Verifying codec availability for FFmpeg..."
	@failed=0; \
	for codec in $(2); do \
		if ! PKG_CONFIG_LIBDIR="$(1)" pkg-config --exists $$codec 2>/dev/null; then \
			echo "  ✗ $$codec not found"; \
			failed=1; \
		else \
			echo "  ✓ $$codec"; \
		fi; \
	done; \
	if [ $$failed -eq 1 ]; then \
		echo ""; \
		echo "ERROR: Some codecs not available for FFmpeg"; \
		echo "  PKG_CONFIG_LIBDIR=$(1)"; \
		echo "  Available .pc files:"; \
		ls -1 $(1)/*.pc 2>/dev/null || echo "    (none)"; \
		exit 1; \
	fi
	@echo "All codecs verified"
endef

# -----------------------------------------------------------------------------
# Layer 4: Final Binary Verification
# -----------------------------------------------------------------------------

# Verify binary architecture
# Usage: $(call verify_binary_arch,BINARY_PATH,ARCH_PATTERN)
define verify_binary_arch
	@file "$(1)" | grep -q "$(2)" || \
		(echo "ERROR: Binary has wrong architecture: $(1)"; \
		 echo "  Expected: $(2)"; \
		 echo "  Got: $$(file $(1))"; \
		 exit 1)
	@echo "  ✓ Architecture verified: $(2)"
endef

# Verify static linkage (platform-specific)
# Usage: $(call verify_static_linkage,BINARY_PATH,PLATFORM)
define verify_static_linkage
	$(if $(filter darwin%,$(2)),\
		@if otool -L "$(1)" | grep -v "System\|usr/lib" | grep -q "\.dylib"; then \
			echo "ERROR: Binary has unexpected dynamic dependencies:"; \
			otool -L "$(1)" | grep -v "System\|usr/lib"; \
			exit 1; \
		fi,\
		@if ldd "$(1)" 2>/dev/null | grep -v "linux-vdso\|ld-linux\|libc\|libm\|libdl\|libpthread\|libstdc++" | grep -q "=>"; then \
			echo "ERROR: Binary has unexpected dynamic dependencies:"; \
			ldd "$(1)" | grep -v "linux-vdso\|ld-linux\|libc\|libm\|libdl\|libpthread\|libstdc++"; \
			exit 1; \
		fi)
	@echo "  ✓ Static linkage verified"
endef
```

## Error Message Design

### Principle: Diagnose, Don't Just Report

**Bad (current behavior):**
```
ERROR: x265 >= 3.0 not found using pkg-config
```

**Good (proposed):**
```
ERROR: FFmpeg configure failed to find x265

  Diagnosis:
    ✓ x265.pc exists at /build/prefix/lib/pkgconfig/x265.pc
    ✓ pkg-config finds x265
    ✗ Link test failed: undefined reference to 'dlopen'

  Root cause: x265 uses dlopen() but -ldl is not in link flags

  Fix: Add -ldl to EXTRA_LIBS in platforms/<platform>/config.mk
       Or: --extra-libs="-ldl" in FFmpeg configure
```

### Error Message Template

```
ERROR: [What failed]

  Diagnosis:
    [✓/✗] [Check 1]
    [✓/✗] [Check 2]
    ...

  Root cause: [Actual problem]

  Fix: [Specific remediation]
```

## Integration Points

### In Platform Makefile

```makefile
# Add preflight dependency to codecs
codecs: preflight $(addsuffix .stamp,$(ACTIVE_CODECS))

# Add preflight target
preflight: dirs
	$(call verify_arch_toolchain,$(BUILD_DIR),$(CC),$(CFLAGS),$(ARCH_VERIFY_PATTERN))
	$(call verify_pkgconfig_isolation,$(PREFIX)/lib/pkgconfig)

# Add codec verification before FFmpeg
ffmpeg.stamp: dirs $(addsuffix .stamp,$(ACTIVE_CODECS))
	$(call verify_codecs_available,$(PREFIX)/lib/pkgconfig,$(CODEC_PKGCONFIG_NAMES))
	# ... existing FFmpeg build ...
```

### In Codec Recipe

```makefile
# Example: shared/codecs/gpl/x265.mk
x265.stamp: dirs
	# ... existing build steps ...
	$(call verify_static_lib,$(PREFIX)/lib/libx265.a,$(ARCH_VERIFY_PATTERN))
	$(call verify_pkgconfig,$(PREFIX)/lib/pkgconfig/x265.pc,x265)
	@touch $(STAMPS_DIR)/$@
```

## Platform-Specific Considerations

### Linux: -ldl Requirement

```makefile
# platforms/linux-*/config.mk
FFMPEG_EXTRA_LIBS := -lpthread -lm -lstdc++ -ldl

# Why: x265 uses dlopen() for plugin loading
# Evidence: commit 62fc534, 4c2f9bf
```

### Darwin: No -ldl Needed

```makefile
# platforms/darwin-*/config.mk
FFMPEG_EXTRA_LIBS := -lpthread -lm

# Why: macOS includes dlopen in libSystem
```

### Cross-Compilation: Architecture Contracts

```makefile
# platforms/linux-arm64/config.mk
ARCH_VERIFY_PATTERN := aarch64
HOST_TRIPLET := aarch64-linux-gnu

# Pre-build: verify CC produces aarch64
# Post-build: verify each .a is aarch64
```

## Cache Key Strategy

### Problem

Branch names like `stable` are mutable:
- Day 1: `git clone -b stable` gets commit A
- Day 7: Same command gets commit B (new upstream)
- CI cache key unchanged → stale source used

### Solution

```makefile
# shared/versions.mk
# REQUIRED: Use immutable refs (commit hashes, version tags)
X264_VERSION := b35605ace3ddf7c1a5d67a2eb553f034aef41d55  # Not "stable"

# Parse-time validation (in shared/verify.mk)
$(call validate_immutable_ref,X264_VERSION,x264)
```

## Rollout Strategy

### Phase 1: Non-Breaking Additions

1. Add `shared/verify.mk` with all functions
2. Add `preflight` target (optional, not in dependency chain)
3. Test manually: `make preflight`

### Phase 2: Integration

1. Add `preflight` to codec dependency chain
2. Add post-build verification to each codec recipe
3. CI validates all platforms

### Phase 3: Enhanced Diagnostics

1. Improve error messages based on real failures
2. Add more specific checks for common issues
3. Document common failures and fixes

## Metrics

Track these to measure guardrail effectiveness:

| Metric | Before | Target |
|--------|--------|--------|
| Fix commits per feature | ~3 | ~1 |
| Debug commits | ~10% | <2% |
| Reverts | ~4% | <1% |
| Time to diagnose issue | Hours | Minutes |

## Open Questions

1. **Preflight overhead:** Should preflight run on every build or only CI?
   - Proposal: Always run, but cache results

2. **False positives:** How to handle legitimate warnings?
   - Proposal: Use WARNING level, not ERROR

3. **Verbose mode:** Should guardrails be silent on success?
   - Proposal: Default quiet, DEBUG=1 for verbose
