# Tasks: refactor-cmake-toolchains

## Task 1: Create shared/cmake.mk

**Files:**
- Create: `shared/cmake.mk`

**Implementation:**

```makefile
# =============================================================================
# Shared CMake Configuration
# =============================================================================
# Base CMake options included by all platforms.
# Platforms append CMAKE_PLATFORM_OPTS for platform-specific flags.
# =============================================================================

# Base CMake options common to all platforms
CMAKE_OPTS_BASE := \
    -DCMAKE_INSTALL_PREFIX=$(PREFIX) \
    -DCMAKE_PREFIX_PATH=$(PREFIX) \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_C_COMPILER=$(CC) \
    -DCMAKE_CXX_COMPILER=$(CXX) \
    -DBUILD_SHARED_LIBS=OFF \
    $(if $(DEBUG),,-Wno-dev)

# Ccache integration (if available)
# Note: CCACHE detection happens in config.mk, we only set cmake flags here
ifdef CCACHE
CMAKE_CCACHE_OPTS := \
    -DCMAKE_C_COMPILER_LAUNCHER=ccache \
    -DCMAKE_CXX_COMPILER_LAUNCHER=ccache
endif

# Compose final CMAKE_OPTS
# Platforms define CMAKE_PLATFORM_OPTS before including this file
CMAKE_OPTS = $(CMAKE_OPTS_BASE) $(CMAKE_PLATFORM_OPTS) $(CMAKE_CCACHE_OPTS)
```

**Verification:**
- [ ] File syntax valid: `make -n -f shared/cmake.mk`
- [ ] Variables expand correctly when included

---

## Task 2: Update darwin-arm64/config.mk

**Files:**
- Modify: `platforms/darwin-arm64/config.mk:63-71` (CMAKE_OPTS section)
- Modify: `platforms/darwin-arm64/config.mk:86-89` (ccache CMAKE addition)

**Changes:**

Remove the full CMAKE_OPTS definition and ccache CMAKE_OPTS addition.
Replace with CMAKE_PLATFORM_OPTS:

```makefile
# CMake platform-specific configuration
CMAKE_PLATFORM_OPTS := \
    -DCMAKE_OSX_ARCHITECTURES=arm64 \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=$(MACOSX_DEPLOYMENT_TARGET)
```

**Verification:**
- [ ] `make -n codecs` shows same cmake invocations as before

---

## Task 3: Update darwin-x64/config.mk

**Files:**
- Modify: `platforms/darwin-x64/config.mk:62-70` (CMAKE_OPTS section)
- Modify: `platforms/darwin-x64/config.mk:85-88` (ccache CMAKE addition)

**Changes:**

```makefile
# CMake platform-specific configuration
CMAKE_PLATFORM_OPTS := \
    -DCMAKE_OSX_ARCHITECTURES=x86_64 \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=$(MACOSX_DEPLOYMENT_TARGET)
```

**Verification:**
- [ ] `make -n codecs` shows same cmake invocations as before

---

## Task 4: Update linux-x64/config.mk

**Files:**
- Modify: `platforms/linux-x64/config.mk:47-56` (CMAKE_OPTS section)
- Modify: `platforms/linux-x64/config.mk:71-74` (ccache CMAKE addition)

**Changes:**

```makefile
# CMake platform-specific configuration
CMAKE_PLATFORM_OPTS := \
    -DCMAKE_SYSTEM_NAME=Linux \
    -DCMAKE_SYSTEM_PROCESSOR=x86_64
```

**Verification:**
- [ ] `make -n codecs` shows same cmake invocations as before

---

## Task 5: Update remaining Linux glibc platforms

**Files:**
- Modify: `platforms/linux-arm64v8/config.mk`
- Modify: `platforms/linux-armv6/config.mk`
- Modify: `platforms/linux-ppc64le/config.mk`
- Modify: `platforms/linux-riscv64/config.mk`

**Changes:** Same pattern as linux-x64, adjust ARCH values:
- linux-arm64v8: `aarch64`
- linux-armv6: `armv6l` (or similar)
- linux-ppc64le: `ppc64le`
- linux-riscv64: `riscv64`

**Note:** These run in Docker, verification happens in CI.

---

## Task 6: Update linux-s390x/config.mk

**Files:**
- Modify: `platforms/linux-s390x/config.mk:34-45`

**Changes:**

This platform passes CFLAGS/CXXFLAGS directly to CMake:

```makefile
# CMake platform-specific configuration
CMAKE_PLATFORM_OPTS := \
    -DCMAKE_SYSTEM_NAME=Linux \
    -DCMAKE_SYSTEM_PROCESSOR=s390x \
    -DCMAKE_C_FLAGS="$(CFLAGS)" \
    -DCMAKE_CXX_FLAGS="$(CXXFLAGS)"
```

**Verification:**
- [ ] Docker build succeeds in CI

---

## Task 7: Update Linux musl platforms

**Files:**
- Modify: `platforms/linuxmusl-x64/config.mk:24-33`
- Modify: `platforms/linuxmusl-arm64v8/config.mk`

**Changes:**

```makefile
# CMake platform-specific configuration
CMAKE_PLATFORM_OPTS := \
    -DCMAKE_SYSTEM_NAME=Linux \
    -DCMAKE_SYSTEM_PROCESSOR=$(ARCH) \
    -DCMAKE_C_FLAGS="$(CFLAGS)" \
    -DCMAKE_CXX_FLAGS="$(CXXFLAGS)"
```

**Verification:**
- [ ] Docker build succeeds in CI

---

## Task 8: Update platform Makefiles to include cmake.mk

**Files:**
- Modify: `platforms/darwin-arm64/Makefile`
- Modify: `platforms/darwin-x64/Makefile`
- Modify: `platforms/linux-x64/Makefile`
- (and all other platform Makefiles)

**Changes:**

Add include after config.mk:

```makefile
include config.mk
include $(SHARED_DIR)/cmake.mk
```

**Verification:**
- [ ] `make -n` works on each platform

---

## Task 9: Remove duplicate -DBUILD_SHARED_LIBS from codec recipes

**Files:**
- Review: `shared/codecs/bsd/aom.mk:21`
- Review: `shared/codecs/bsd/svt-av1.mk`
- Review: `shared/codecs/gpl/x265.mk`

**Changes:**

Since `-DBUILD_SHARED_LIBS=OFF` is now in CMAKE_OPTS_BASE, check if codecs duplicate it.
Remove if duplicated.

**Note:** aom.mk line 21 has `-DBUILD_SHARED_LIBS=OFF` - remove it.

**Verification:**
- [ ] cmake invocations don't have duplicate -DBUILD_SHARED_LIBS

---

## Task 10: CI Validation

**Verification:**
- [ ] Push branch, all 30 CI jobs pass
- [ ] Compare build logs to baseline for cmake invocation consistency
- [ ] All codec static libraries verified by make verify

---

## Parallel Execution Groups

| Group | Tasks | Rationale |
|-------|-------|-----------|
| Group 1 | 1 | Foundation - must complete first |
| Group 2 | 2, 3, 4, 5, 6, 7 | Platform configs (independent) |
| Group 3 | 8 | Makefile includes (after configs) |
| Group 4 | 9 | Codec cleanup (after includes work) |
| Group 5 | 10 | Final validation |

**Estimated effort:** Small - pure refactoring, no behavioral changes
