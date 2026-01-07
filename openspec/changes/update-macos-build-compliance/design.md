# Design: macOS Build Compliance

## Context

The FFmpeg macOS compilation guide (`docs/CompilationGuide_macOS.txt`) provides official instructions for building FFmpeg on macOS. Our build system has evolved with some configuration choices that diverge from these recommendations.

**Key stakeholders:**
- Native addon developers consuming FFmpeg prebuilds
- CI/CD pipeline (GitHub Actions macos-15, macos-15-intel runners)

**Constraints:**
- Must maintain backward compatibility with existing artifacts
- Must support both Apple Silicon (arm64) and Intel (x64) architectures
- Must work on GitHub Actions runners with limited tooling

## Goals / Non-Goals

**Goals:**
- Align FFmpeg configure flags with official recommendations
- Ensure optimal CPU feature detection on native builds
- Accurate documentation reflecting actual build environment
- Verify assembly optimizations are enabled for x264/x265

**Non-Goals:**
- Adding new codecs (fdk-aac, libass, theora - these are intentionally excluded)
- Changing the static linking strategy
- Modifying license tier structure

## Decisions

### Decision 1: Remove `--enable-cross-compile` from darwin-arm64

**What:** Remove the `--enable-cross-compile` flag from darwin-arm64 FFMPEG_BASE_OPTS

**Why:**
- darwin-arm64 builds run on native ARM64 runners (macos-15)
- `--enable-cross-compile` disables auto-detection of CPU features
- FFmpeg's configure can detect arm64 features natively without this flag
- The flag was likely a historical artifact from before native ARM runners

**Alternatives considered:**
- Keep the flag for "consistency" - Rejected because it inhibits optimization
- Use `--enable-cross-compile` with explicit feature flags - Overly complex

### Decision 2: Keep `--target-os=darwin`

**What:** Retain the `--target-os=darwin` flag even after removing cross-compile

**Why:**
- Explicitly declares target OS even for native builds
- Ensures consistent configure behavior
- Low risk, clear intent

### Decision 3: Xcode CLI Tools Verification

**What:** Add `xcode-select -p` check to build.sh scripts

**Why:**
- Official FFmpeg guide requires Xcode Command Line Tools
- Early failure with clear message is better than cryptic build errors
- Matches guide's prerequisites section

**Implementation:**
```bash
verify_xcode_cli_tools() {
  if ! xcode-select -p &>/dev/null; then
    log_error "Xcode Command Line Tools not installed"
    log_error "Install with: xcode-select --install"
    exit 1
  fi
  log_info "Xcode CLI tools: $(xcode-select -p)"
}
```

## Risks / Trade-offs

### Risk 1: Removing `--enable-cross-compile` Changes Binary Output
- **Risk:** FFmpeg may detect different features, producing incompatible binaries
- **Mitigation:**
  - Architecture verification already catches wrong-arch binaries
  - Compare configure output before/after change
  - Test binary on target platform

### Risk 2: darwin-x64 Cross-Compile Reference Removal
- **Risk:** Someone may revert to cross-compilation in future
- **Mitigation:**
  - Document the decision in commit message
  - CLAUDE.md already recommends native over cross-compile

## Migration Plan

1. Make changes in single PR
2. Verify CI passes for both darwin-arm64 and darwin-x64
3. Compare artifact sizes and features with previous builds
4. No user-facing migration needed (build artifacts unchanged)

**Rollback:**
- Revert PR if binaries differ unexpectedly
- No data migration required

## Open Questions

1. **Q:** Should we add configure output logging to verify features?
   **A:** Yes, added as task 4.1 - helpful for debugging future issues

2. **Q:** Should we verify NASM version matches versions.mk?
   **A:** darwin-x64 already handles this (builds NASM from source). darwin-arm64 uses Homebrew which is acceptable.
