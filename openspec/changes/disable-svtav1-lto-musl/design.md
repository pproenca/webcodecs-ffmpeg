# Design: Disable LTO for SVT-AV1 on musl Builds

## Context

SVT-AV1 v2.3.0 enables LTO by default when built with GCC (via `SVT_AV1_LTO` CMake option). This optimization embeds GCC-specific bytecode into the static library. When consumers link against this library, they need a matching GCC LTO plugin version.

Alpine Linux (musl libc) does not ship the GCC LTO plugin by default, and even when installed, version mismatches between build-time and link-time GCC cause failures.

**Constraints:**
- Must not impact other platforms (darwin, linux-glibc)
- Must preserve SVT-AV1 performance on platforms where LTO works
- Must be maintainable alongside existing platform configuration pattern

## Goals / Non-Goals

**Goals:**
- Enable successful musl builds without requiring LTO plugin
- Maintain single shared SVT-AV1 recipe
- Follow existing platform configuration patterns

**Non-Goals:**
- Disable LTO globally (other codecs/platforms unaffected)
- Add new build system abstractions

## Decisions

### Decision 1: Use codec-specific CMake variable

**What:** Add `SVTAV1_CMAKE_OPTS` variable that platforms can optionally define.

**Why:**
- Follows existing pattern (e.g., `LIBVPX_TARGET`, `X264_HOST`, `AOM_TARGET_CPU`)
- Minimal change to shared recipe
- Platform-specific without creating recipe duplication

**Alternatives considered:**
1. **Global `CMAKE_OPTS` modification** - Too broad, affects all CMake codecs
2. **Platform-specific svt-av1.mk** - Creates duplication, violates DRY
3. **Conditional in shared recipe** - Adds `ifeq` complexity to shared code

### Decision 2: Default to empty (no-op)

**What:** `SVTAV1_CMAKE_OPTS ?=` defaults to empty in shared recipe.

**Why:**
- Platforms that don't define it get default SVT-AV1 behavior (LTO enabled)
- Only musl platform explicitly disables LTO
- No impact on darwin/linux-glibc builds

## Implementation

### File: `platforms/linuxmusl-x64/config.mk`

Add after codec-specific overrides section:
```makefile
# SVT-AV1: Disable LTO on musl (GCC LTO plugin not available by default)
SVTAV1_CMAKE_OPTS := -DSVT_AV1_LTO=OFF
```

### File: `shared/codecs/bsd/svt-av1.mk`

Modify cmake invocation:
```makefile
# Default: empty (LTO enabled on most platforms)
SVTAV1_CMAKE_OPTS ?=

svt-av1.stamp:
    ...
    cd $(SVTAV1_BUILD) && \
        cmake $(SVTAV1_SRC) \
            $(CMAKE_OPTS) \
            $(SVTAV1_CMAKE_OPTS) \
            -DBUILD_SHARED_LIBS=OFF \
            ...
```

## Risks / Trade-offs

| Risk | Impact | Mitigation |
|------|--------|------------|
| Slight performance regression on musl | Low - LTO gains are ~1-5% for encoding | Acceptable for build compatibility |
| Pattern proliferation | Low - Only needed for SVT-AV1 | Document in CLAUDE.md if more codecs need this |

## Migration Plan

No migration needed - this is a build system fix that doesn't affect API or package structure.

**Rollback:** Remove `SVTAV1_CMAKE_OPTS` from config.mk and revert svt-av1.mk changes.

## Open Questions

None - implementation is straightforward.
