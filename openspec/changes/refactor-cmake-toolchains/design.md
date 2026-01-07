# Design: CMake Configuration Refactoring

## Architecture Decision Record

### Context

The dev-cmake skill recommends CMake toolchain files for cross-compilation. However, this project has unique characteristics that affect that recommendation:

1. **Not a CMake project** - This is a GNU Make build system that invokes CMake for 3 external codecs (aom, svt-av1, x265)
2. **Native builds** - Linux platforms use Docker containers with native toolchains, not cross-compilation
3. **macOS uses Xcode** - Darwin platforms rely on `xcrun` and Xcode SDK, not standalone toolchains
4. **Make already manages configuration** - Platform config is in `config.mk` files

### Evaluated Approaches

#### Option A: CMake Toolchain Files

Create `shared/cmake/toolchains/{platform}.cmake` for each platform:

```cmake
# shared/cmake/toolchains/darwin-arm64.cmake
set(CMAKE_SYSTEM_NAME Darwin)
set(CMAKE_OSX_ARCHITECTURES arm64)
set(CMAKE_OSX_DEPLOYMENT_TARGET 11.0)
set(CMAKE_C_COMPILER clang)
set(CMAKE_CXX_COMPILER clang++)
```

**Pros:**
- Follows modern CMake patterns
- Single file per platform for CMake config
- Portable to other CMake consumers

**Cons:**
- **Duplicates Make config** - Platform already defined in config.mk (CC, CXX, ARCH, etc.)
- **Breaks ccache integration** - Toolchain file would need to detect ccache
- **SDK path complexity** - `SDKROOT` is runtime-detected, hard to encode in static file
- **Two sources of truth** - Platform definition split between .mk and .cmake

**Verdict:** Rejected - adds complexity without benefit for this use case

#### Option B: Shared Make Configuration (Selected)

Extract common CMAKE_OPTS to `shared/cmake.mk`:

```makefile
# Platform defines CMAKE_PLATFORM_OPTS, shared provides base
CMAKE_OPTS = $(CMAKE_OPTS_BASE) $(CMAKE_PLATFORM_OPTS) $(CMAKE_CCACHE_OPTS)
```

**Pros:**
- **Single source of truth** - Platform config stays in config.mk
- **Natural for Make project** - No context switch between Make and CMake
- **Preserves all existing behavior** - Just reorganizes existing code
- **Minimal risk** - Pure refactoring, no semantic changes

**Cons:**
- Doesn't follow CMake toolchain pattern
- Still passes flags via command line instead of file

**Verdict:** Selected - best fit for Make-based project

#### Option C: CMake Presets

Use `CMakePresets.json` pattern adapted to Make:

**Verdict:** Rejected - CMake presets are for CMake projects, not consumers

## Component Design

### New File: shared/cmake.mk

```
shared/
├── cmake.mk           # NEW: Base CMake configuration
├── common.mk          # Existing: Utility functions
├── versions.mk        # Existing: Version definitions
└── codecs/            # Existing: Codec recipes
```

**Responsibilities:**
1. Define `CMAKE_OPTS_BASE` with flags common to all platforms
2. Compose `CMAKE_OPTS` from base + platform + ccache
3. Provide consistent `-Wno-dev` handling based on DEBUG

**Excluded responsibilities:**
- Codec-specific flags (remain in codec .mk files)
- Platform-specific paths (remain in config.mk)
- Meson configuration (separate pattern)

### Modified Files: platforms/*/config.mk

Each platform config.mk changes from defining full `CMAKE_OPTS` to:
1. Including `$(SHARED_DIR)/cmake.mk`
2. Defining only `CMAKE_PLATFORM_OPTS` with platform-specific flags

### Composition Pattern

```
CMAKE_OPTS = CMAKE_OPTS_BASE + CMAKE_PLATFORM_OPTS + CMAKE_CCACHE_OPTS
             ↓                 ↓                      ↓
         shared/cmake.mk   platforms/*/config.mk   shared/cmake.mk
```

### Variable Naming Convention

| Variable | Defined In | Purpose |
|----------|------------|---------|
| `CMAKE_OPTS_BASE` | shared/cmake.mk | Common flags |
| `CMAKE_PLATFORM_OPTS` | platforms/*/config.mk | Platform-specific flags |
| `CMAKE_CCACHE_OPTS` | shared/cmake.mk | Ccache launcher flags |
| `CMAKE_OPTS` | shared/cmake.mk (composed) | Final flags passed to cmake |

### Include Order

```makefile
# In platforms/*/Makefile:
include $(SHARED_DIR)/versions.mk
include config.mk                    # Sets CC, CXX, CMAKE_PLATFORM_OPTS
include $(SHARED_DIR)/cmake.mk       # Composes CMAKE_OPTS
include $(SHARED_DIR)/common.mk
include $(SHARED_DIR)/platform.mk
```

Note: `cmake.mk` must be included AFTER `config.mk` because it uses `$(CC)`, `$(CXX)`, `$(PREFIX)` defined there.

## Platform-Specific Flags Analysis

### Darwin platforms (darwin-arm64, darwin-x64)

```makefile
CMAKE_PLATFORM_OPTS := \
    -DCMAKE_OSX_ARCHITECTURES=$(ARCH) \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=$(MACOSX_DEPLOYMENT_TARGET)
```

### Linux glibc platforms (linux-x64, linux-arm64v8, etc.)

```makefile
CMAKE_PLATFORM_OPTS := \
    -DCMAKE_SYSTEM_NAME=Linux \
    -DCMAKE_SYSTEM_PROCESSOR=$(ARCH)
```

### Linux musl platforms (linuxmusl-x64, linuxmusl-arm64v8)

Same as glibc, but some also pass CMAKE_C_FLAGS/CMAKE_CXX_FLAGS:

```makefile
CMAKE_PLATFORM_OPTS := \
    -DCMAKE_SYSTEM_NAME=Linux \
    -DCMAKE_SYSTEM_PROCESSOR=$(ARCH) \
    -DCMAKE_C_FLAGS="$(CFLAGS)" \
    -DCMAKE_CXX_FLAGS="$(CXXFLAGS)"
```

### s390x platform (special case)

Uses different architecture flags and passes CFLAGS directly:

```makefile
CMAKE_PLATFORM_OPTS := \
    -DCMAKE_SYSTEM_NAME=Linux \
    -DCMAKE_SYSTEM_PROCESSOR=$(ARCH) \
    -DCMAKE_C_FLAGS="$(CFLAGS)" \
    -DCMAKE_CXX_FLAGS="$(CXXFLAGS)"
```

## Consistency Fixes

### Issue: BUILD_SHARED_LIBS placement

**Current state:** Some platforms include `-DBUILD_SHARED_LIBS=OFF` in CMAKE_OPTS, codec recipes also set it.

**Fix:** Move to `CMAKE_OPTS_BASE` - all codecs need static libs. Remove from codec recipes that duplicate it.

### Issue: -Wno-dev handling

**Current state:**
- darwin-arm64: `$(if $(DEBUG),,-Wno-dev)`
- linux-s390x: `$(if $(DEBUG),,-Wno-dev)`
- linuxmusl-x64: Not included
- Others: Vary

**Fix:** Handle consistently in `CMAKE_OPTS_BASE` with conditional.

### Issue: CMAKE_PREFIX_PATH

**Current state:** Most platforms include it, linuxmusl-x64 does not.

**Fix:** Include in `CMAKE_OPTS_BASE` - needed for finding installed codec libs.

## Testing Strategy

1. **Before refactoring:** Capture cmake invocation output for each codec on each platform
2. **After refactoring:** Verify identical cmake invocation
3. **CI validation:** All 30 matrix jobs must pass
