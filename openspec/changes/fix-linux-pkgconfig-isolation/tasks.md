# Tasks: fix-linux-pkgconfig-isolation

## 1. Previous Attempt (Insufficient)

- [x] 1.1 Update `platforms/linux-arm64/Makefile` ffmpeg.stamp target to use inline `PKG_CONFIG_LIBDIR=` prefix instead of `export`
- [x] 1.2 Update `platforms/linux-x64/Makefile` ffmpeg.stamp target with same pattern
- [x] 1.3 Update darwin-* Makefiles to use same pattern for consistency
- [x] 1.4 Add note to CLAUDE.md bug patterns about Docker environment isolation

**Result:** CI still fails - inline prefix is correct but not the root cause.

## 2. Correct Fix: Override pkg-config Binary

- [x] 2.1 Add `--pkg-config=pkg-config` to `platforms/linux-arm64/Makefile` FFMPEG_BASE_OPTS
- [x] 2.2 Add `--pkg-config=pkg-config` to `platforms/linux-x64/Makefile` FFMPEG_BASE_OPTS
- [x] 2.3 Keep inline `PKG_CONFIG_LIBDIR` prefix (still needed for path isolation)

## 3. Verification

- [ ] 3.1 Push fix and verify linux-arm64-bsd CI job passes
- [ ] 3.2 Verify linux-arm64-lgpl CI job passes
- [ ] 3.3 Verify linux-arm64-gpl CI job passes
- [ ] 3.4 Verify linux-x64-* CI jobs pass (3 jobs)
- [ ] 3.5 Verify darwin-* CI jobs still pass (6 jobs)

## 4. Documentation

- [x] 4.1 Update CLAUDE.md bug patterns with the cross-prefixed pkg-config lesson
