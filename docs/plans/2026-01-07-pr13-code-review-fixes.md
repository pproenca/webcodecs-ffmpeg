# PR #13 Code Review Fixes Implementation Plan

> **Execution:** Use `/dev-workflow:execute-plan docs/plans/2026-01-07-pr13-code-review-fixes.md` to implement task-by-task.

**Goal:** Address all critical and important issues from the PR #13 code review to ensure CI builds succeed and produce correct artifacts.

**Architecture:** Fix variable naming inconsistencies (LICENSE_TIER → LICENSE), remove Docker USER permissions that break volume mounts, and standardize patterns across all 6 affected platforms. Changes are mechanical transformations following the linux-x64/linux-arm64v8 reference implementations.

**Tech Stack:** Bash, Makefiles, Dockerfiles, GitHub Actions YAML

---

## Summary of Issues

| Priority | Issue | Affected Files |
|----------|-------|----------------|
| CRITICAL | LICENSE_TIER variable mismatch | 6 build.sh files |
| CRITICAL | USER builder permission conflict | 6 Dockerfiles |
| IMPORTANT | Missing PKG_CONFIG_LIBDIR export | 6 config.mk files |
| IMPORTANT | codec.mk inconsistent structure | 6 codec.mk files |

## Task Groups

| Task Group | Tasks | Rationale |
|------------|-------|-----------|
| Group 1 | 1, 2, 3 | Independent platforms: linuxmusl-x64, linux-armv6, linux-ppc64le |
| Group 2 | 4, 5, 6 | Independent platforms: linux-riscv64, linux-s390x, linuxmusl-arm64v8 |
| Group 3 | 7 | Code Review |

---

### Task 1: Fix linuxmusl-x64 LICENSE variable and Dockerfile

**Files:**
- Modify: `platforms/linuxmusl-x64/build.sh`
- Modify: `platforms/linuxmusl-x64/Dockerfile`
- Modify: `platforms/linuxmusl-x64/config.mk`
- Modify: `platforms/linuxmusl-x64/codecs/codec.mk`

**Step 1: Update build.sh to use LICENSE instead of LICENSE_TIER** (3 min)

Replace all occurrences of `LICENSE_TIER` with `LICENSE` in `platforms/linuxmusl-x64/build.sh`:

```bash
# Line 22: Update comment
#   LICENSE               Same as --license option

# Line 29: Update example
#   LICENSE=bsd ./build.sh        # BSD-only build

# Line 39: Change variable name
LICENSE="${LICENSE:-gpl}"

# Line 95-102: Update usage() function
  LICENSE               Same as --license option
  LICENSE=bsd ./build.sh        # BSD-only build

# Line 111: Change argument parsing
LICENSE="$2"

# Line 126: Change validation
case "${LICENSE}" in

# Line 129: Change error message
log_error "Invalid license tier: ${LICENSE}"

# Line 136: Change log
log_info "License tier: ${LICENSE}"

# Lines 143-145: Change exec make args
LICENSE="${LICENSE}" \

# Lines 157, 161: Change docker run args
-e LICENSE="${LICENSE}" \
make LICENSE="${LICENSE}" "${TARGET}"
```

**Step 2: Run shellcheck to verify syntax** (30 sec)

```bash
shellcheck platforms/linuxmusl-x64/build.sh
```

Expected: No errors (warnings about echo -e are acceptable)

**Step 3: Remove USER builder from Dockerfile** (1 min)

Remove lines 50-52 from `platforms/linuxmusl-x64/Dockerfile`:

```dockerfile
# DELETE these lines:
# Create build user (non-root)
RUN adduser -D -h /build builder
USER builder
```

Keep WORKDIR /build but remove the user creation.

**Step 4: Add PKG_CONFIG_LIBDIR to config.mk** (2 min)

Add these lines after line 44 in `platforms/linuxmusl-x64/config.mk`:

```makefile
# pkg-config setup for consistent dependency resolution
PKG_CONFIG := pkg-config
PKG_CONFIG_LIBDIR := $(PREFIX)/lib/pkgconfig

# Export variables
export CC CXX CFLAGS CXXFLAGS LDFLAGS
export PKG_CONFIG PKG_CONFIG_LIBDIR
```

**Step 5: Remove LICENSE_TIER mapping from codec.mk** (1 min)

The codec.mk already uses `LICENSE` correctly. Verify no LICENSE_TIER references exist:

```bash
grep -n "LICENSE_TIER" platforms/linuxmusl-x64/codecs/codec.mk
```

Expected: No output (no LICENSE_TIER references)

**Step 6: Commit changes** (30 sec)

```bash
git add platforms/linuxmusl-x64/
git commit -m "fix(linuxmusl-x64): use LICENSE env var, remove USER builder

- Change LICENSE_TIER to LICENSE in build.sh (CI passes LICENSE=)
- Remove USER builder from Dockerfile (fixes permission denied)
- Add PKG_CONFIG_LIBDIR export to config.mk

Addresses PR #13 review issues #1, #2, #7"
```

---

### Task 2: Fix linux-armv6 LICENSE variable and Dockerfile

**Files:**
- Modify: `platforms/linux-armv6/build.sh`
- Modify: `platforms/linux-armv6/Dockerfile`
- Modify: `platforms/linux-armv6/config.mk`
- Modify: `platforms/linux-armv6/codecs/codec.mk`

**Step 1: Update build.sh to use LICENSE instead of LICENSE_TIER** (3 min)

Apply the same transformations as Task 1 to `platforms/linux-armv6/build.sh`:

```bash
# Line 23: Update comment
#   LICENSE               Same as --license option

# Line 30: Update example
#   LICENSE=bsd ./build.sh        # BSD-only build

# Line 40: Change variable name
LICENSE="${LICENSE:-gpl}"

# Line 96-103: Update usage() function
  LICENSE               Same as --license option
  LICENSE=bsd ./build.sh        # BSD-only build

# Line 112: Change argument parsing
LICENSE="$2"

# Line 127: Change validation
case "${LICENSE}" in

# Line 130: Change error message
log_error "Invalid license tier: ${LICENSE}"

# Line 137: Change log
log_info "License tier: ${LICENSE}"

# Lines 144-146: Change exec make args
LICENSE="${LICENSE}" \

# Lines 166, 170: Change docker run args
-e LICENSE="${LICENSE}" \
make LICENSE="${LICENSE}" "${TARGET}"
```

**Step 2: Run shellcheck to verify syntax** (30 sec)

```bash
shellcheck platforms/linux-armv6/build.sh
```

Expected: No errors

**Step 3: Remove USER builder from Dockerfile** (1 min)

Remove lines 48-50 from `platforms/linux-armv6/Dockerfile`:

```dockerfile
# DELETE these lines:
# Create build user (non-root)
RUN useradd -m -d /build builder
USER builder
```

**Step 4: Add config.mk file** (2 min)

Check if config.mk exists, if not create it based on linux-x64:

```bash
ls -la platforms/linux-armv6/config.mk
```

If it exists, add PKG_CONFIG_LIBDIR. If not, create a minimal one.

**Step 5: Remove LICENSE_TIER mapping from codec.mk** (1 min)

Remove lines 33-35 from `platforms/linux-armv6/codecs/codec.mk`:

```makefile
# DELETE these lines:
# Map LICENSE_TIER env var to LICENSE make var
ifdef LICENSE_TIER
    LICENSE := $(LICENSE_TIER)
endif
```

The codec.mk should only use `LICENSE` directly, which the Makefile passes from build.sh.

**Step 6: Commit changes** (30 sec)

```bash
git add platforms/linux-armv6/
git commit -m "fix(linux-armv6): use LICENSE env var, remove USER builder

- Change LICENSE_TIER to LICENSE in build.sh (CI passes LICENSE=)
- Remove USER builder from Dockerfile (fixes permission denied)
- Remove LICENSE_TIER mapping from codec.mk
- Add PKG_CONFIG_LIBDIR export to config.mk

Addresses PR #13 review issues #1, #2, #7, #8"
```

---

### Task 3: Fix linux-ppc64le LICENSE variable and Dockerfile

**Files:**
- Modify: `platforms/linux-ppc64le/build.sh`
- Modify: `platforms/linux-ppc64le/Dockerfile`
- Modify: `platforms/linux-ppc64le/config.mk` (if exists)
- Modify: `platforms/linux-ppc64le/codecs/codec.mk`

**Step 1: Update build.sh to use LICENSE instead of LICENSE_TIER** (3 min)

Apply identical transformations to `platforms/linux-ppc64le/build.sh`:
- Lines 23, 30: Update comments
- Line 40: `LICENSE="${LICENSE:-gpl}"`
- Lines 96, 103: Update usage()
- Line 112: `LICENSE="$2"`
- Lines 127, 130, 137: Update validation and logging
- Lines 144, 166, 170: Update make/docker args

**Step 2: Run shellcheck to verify syntax** (30 sec)

```bash
shellcheck platforms/linux-ppc64le/build.sh
```

**Step 3: Remove USER builder from Dockerfile** (1 min)

Remove USER builder lines from `platforms/linux-ppc64le/Dockerfile` (lines 49-50).

**Step 4: Add PKG_CONFIG_LIBDIR to config.mk** (2 min)

Add PKG_CONFIG_LIBDIR export if missing.

**Step 5: Update codec.mk** (1 min)

Remove any LICENSE_TIER mapping if present.

**Step 6: Commit changes** (30 sec)

```bash
git add platforms/linux-ppc64le/
git commit -m "fix(linux-ppc64le): use LICENSE env var, remove USER builder

- Change LICENSE_TIER to LICENSE in build.sh (CI passes LICENSE=)
- Remove USER builder from Dockerfile (fixes permission denied)
- Standardize config.mk and codec.mk patterns

Addresses PR #13 review issues #1, #2, #7, #8"
```

---

### Task 4: Fix linux-riscv64 LICENSE variable and Dockerfile

**Files:**
- Modify: `platforms/linux-riscv64/build.sh`
- Modify: `platforms/linux-riscv64/Dockerfile`
- Modify: `platforms/linux-riscv64/config.mk` (if exists)
- Modify: `platforms/linux-riscv64/codecs/codec.mk`

**Step 1: Update build.sh to use LICENSE instead of LICENSE_TIER** (3 min)

Apply identical transformations to `platforms/linux-riscv64/build.sh`.

**Step 2: Run shellcheck to verify syntax** (30 sec)

```bash
shellcheck platforms/linux-riscv64/build.sh
```

**Step 3: Remove USER builder from Dockerfile** (1 min)

Remove USER builder lines from `platforms/linux-riscv64/Dockerfile` (lines 49-50).

**Step 4: Add PKG_CONFIG_LIBDIR to config.mk** (2 min)

Add PKG_CONFIG_LIBDIR export if missing.

**Step 5: Update codec.mk** (1 min)

Remove any LICENSE_TIER mapping if present.

**Step 6: Commit changes** (30 sec)

```bash
git add platforms/linux-riscv64/
git commit -m "fix(linux-riscv64): use LICENSE env var, remove USER builder

- Change LICENSE_TIER to LICENSE in build.sh (CI passes LICENSE=)
- Remove USER builder from Dockerfile (fixes permission denied)
- Standardize config.mk and codec.mk patterns

Addresses PR #13 review issues #1, #2, #7, #8"
```

---

### Task 5: Fix linux-s390x LICENSE variable and Dockerfile

**Files:**
- Modify: `platforms/linux-s390x/build.sh`
- Modify: `platforms/linux-s390x/Dockerfile`
- Modify: `platforms/linux-s390x/config.mk` (if exists)
- Modify: `platforms/linux-s390x/codecs/codec.mk`

**Step 1: Update build.sh to use LICENSE instead of LICENSE_TIER** (3 min)

Apply identical transformations to `platforms/linux-s390x/build.sh`.

**Step 2: Run shellcheck to verify syntax** (30 sec)

```bash
shellcheck platforms/linux-s390x/build.sh
```

**Step 3: Remove USER builder from Dockerfile** (1 min)

Remove USER builder lines from `platforms/linux-s390x/Dockerfile` (lines 48-49).

**Step 4: Add PKG_CONFIG_LIBDIR to config.mk** (2 min)

Add PKG_CONFIG_LIBDIR export if missing.

**Step 5: Update codec.mk** (1 min)

Remove any LICENSE_TIER mapping if present.

**Step 6: Commit changes** (30 sec)

```bash
git add platforms/linux-s390x/
git commit -m "fix(linux-s390x): use LICENSE env var, remove USER builder

- Change LICENSE_TIER to LICENSE in build.sh (CI passes LICENSE=)
- Remove USER builder from Dockerfile (fixes permission denied)
- Standardize config.mk and codec.mk patterns

Addresses PR #13 review issues #1, #2, #7, #8"
```

---

### Task 6: Fix linuxmusl-arm64v8 LICENSE variable and Dockerfile

**Files:**
- Modify: `platforms/linuxmusl-arm64v8/build.sh`
- Modify: `platforms/linuxmusl-arm64v8/Dockerfile`
- Modify: `platforms/linuxmusl-arm64v8/config.mk` (if exists)
- Modify: `platforms/linuxmusl-arm64v8/codecs/codec.mk`

**Step 1: Update build.sh to use LICENSE instead of LICENSE_TIER** (3 min)

Apply identical transformations to `platforms/linuxmusl-arm64v8/build.sh`.

**Step 2: Run shellcheck to verify syntax** (30 sec)

```bash
shellcheck platforms/linuxmusl-arm64v8/build.sh
```

**Step 3: Remove USER builder from Dockerfile** (1 min)

Remove USER builder lines from `platforms/linuxmusl-arm64v8/Dockerfile` (lines 50-51).

**Step 4: Add PKG_CONFIG_LIBDIR to config.mk** (2 min)

Add PKG_CONFIG_LIBDIR export if missing.

**Step 5: Update codec.mk** (1 min)

The codec.mk is minimal (55 lines) and uses LICENSE correctly. Verify no LICENSE_TIER references.

**Step 6: Commit changes** (30 sec)

```bash
git add platforms/linuxmusl-arm64v8/
git commit -m "fix(linuxmusl-arm64v8): use LICENSE env var, remove USER builder

- Change LICENSE_TIER to LICENSE in build.sh (CI passes LICENSE=)
- Remove USER builder from Dockerfile (fixes permission denied)
- Add PKG_CONFIG_LIBDIR export to config.mk

Addresses PR #13 review issues #1, #2, #7"
```

---

### Task 7: Code Review

Final review of all changes to ensure consistency and correctness.

**Step 1: Verify all LICENSE_TIER references removed** (1 min)

```bash
grep -r "LICENSE_TIER" platforms/
```

Expected: No output (no remaining LICENSE_TIER references)

**Step 2: Verify all USER builder lines removed** (1 min)

```bash
grep -r "USER builder" platforms/
```

Expected: No output

**Step 3: Verify PKG_CONFIG_LIBDIR in all config.mk files** (1 min)

```bash
grep -l "PKG_CONFIG_LIBDIR" platforms/*/config.mk | wc -l
```

Expected: 8 (all platforms should have it)

**Step 4: Run linting** (2 min)

```bash
mise run lint
```

Expected: All checks pass

**Step 5: Push changes** (30 sec)

```bash
git push origin feat/linux-platform-support
```

---

## Verification Checklist

After all tasks complete, verify:

- [ ] `grep -r "LICENSE_TIER" platforms/` returns nothing
- [ ] `grep -r "USER builder" platforms/` returns nothing
- [ ] All 6 affected build.sh files use `LICENSE=` pattern
- [ ] All 6 affected Dockerfiles run as root
- [ ] All config.mk files export PKG_CONFIG_LIBDIR
- [ ] `mise run lint` passes
- [ ] CI builds succeed for all 30 jobs
