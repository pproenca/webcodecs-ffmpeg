# Proposal: refactor-cmake-toolchains

## Summary

Refactor CMAKE_OPTS configuration to follow modern CMake patterns, eliminating duplication across 10 platform config.mk files and improving maintainability.

## Problem Statement

Currently, each platform's `config.mk` file defines `CMAKE_OPTS` with 7-11 flags, most of which are identical across platforms:

**Duplicated flags (all 10 platforms):**
- `-DCMAKE_INSTALL_PREFIX=$(PREFIX)`
- `-DCMAKE_PREFIX_PATH=$(PREFIX)`
- `-DCMAKE_BUILD_TYPE=Release`
- `-DCMAKE_C_COMPILER=$(CC)`
- `-DCMAKE_CXX_COMPILER=$(CXX)`

**Inconsistencies discovered:**
- Some platforms include `-DBUILD_SHARED_LIBS=OFF`, others leave it to codec recipes
- Some platforms include `-DCMAKE_C_FLAGS` directly, others rely on env vars
- `-Wno-dev` handling varies (conditional vs unconditional vs missing)
- ccache integration duplicated in darwin-arm64 and darwin-x64

**Impact:**
- ~60 lines of duplicated CMake configuration across 10 files
- Changes require updating all platforms (error-prone)
- Inconsistencies cause subtle build differences

## Proposed Solution

Extract common CMake configuration to `shared/cmake.mk`:

1. **Base CMAKE_OPTS** - flags common to all platforms
2. **Platform appends** - each config.mk only adds platform-specific flags
3. **Codec-specific flags** - remain in codec .mk files where they belong

### Before (darwin-arm64/config.mk)
```makefile
CMAKE_OPTS := \
    -DCMAKE_OSX_ARCHITECTURES=arm64 \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=$(MACOSX_DEPLOYMENT_TARGET) \
    -DCMAKE_INSTALL_PREFIX=$(PREFIX) \
    -DCMAKE_PREFIX_PATH=$(PREFIX) \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_C_COMPILER=$(CC) \
    -DCMAKE_CXX_COMPILER=$(CXX) \
    $(if $(DEBUG),,-Wno-dev)
```

### After (darwin-arm64/config.mk)
```makefile
include $(SHARED_DIR)/cmake.mk

CMAKE_PLATFORM_OPTS := \
    -DCMAKE_OSX_ARCHITECTURES=arm64 \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=$(MACOSX_DEPLOYMENT_TARGET)
```

### New shared/cmake.mk
```makefile
# Base CMake configuration - included by all platforms
CMAKE_OPTS_BASE := \
    -DCMAKE_INSTALL_PREFIX=$(PREFIX) \
    -DCMAKE_PREFIX_PATH=$(PREFIX) \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_C_COMPILER=$(CC) \
    -DCMAKE_CXX_COMPILER=$(CXX) \
    -DBUILD_SHARED_LIBS=OFF \
    $(if $(DEBUG),,-Wno-dev)

# Compose final CMAKE_OPTS (platform appends CMAKE_PLATFORM_OPTS)
CMAKE_OPTS = $(CMAKE_OPTS_BASE) $(CMAKE_PLATFORM_OPTS) $(CMAKE_CCACHE_OPTS)
```

## Scope

- **In scope:** CMAKE_OPTS centralization, consistency fixes
- **Out of scope:** CMake toolchain files (evaluated but rejected - see design.md)
- **Out of scope:** Meson configuration (separate concern, different patterns)

## Benefits

1. **Reduced duplication:** ~60 lines → ~15 lines across all platforms
2. **Single point of change:** Add/modify common flags in one place
3. **Explicit platform-specific flags:** Each platform only declares what's unique
4. **Consistent behavior:** All platforms get same base configuration

## Risks

| Risk | Mitigation |
|------|------------|
| Build regression | CI builds all 10 platforms before merge |
| Include order issues | Clear documentation, test all platforms |
| ccache integration breaks | Handle in shared/cmake.mk with platform detection |

## Success Criteria

- [ ] All 30 CI jobs pass (10 platforms × 3 licenses)
- [ ] No build output changes (same binaries)
- [ ] config.mk files reduced by >50% for CMAKE_OPTS
- [ ] Single location for base CMake configuration
