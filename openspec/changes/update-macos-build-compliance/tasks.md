# Implementation Tasks

## 1. Prerequisites Verification

- [ ] 1.1 Add `verify_xcode_cli_tools()` function to darwin-arm64/build.sh
- [ ] 1.2 Add `verify_xcode_cli_tools()` function to darwin-x64/build.sh
- [ ] 1.3 Test both platforms detect missing Xcode CLI tools correctly

## 2. darwin-arm64 FFmpeg Configuration

- [ ] 2.1 Remove `--enable-cross-compile` from FFMPEG_BASE_OPTS in darwin-arm64/Makefile
- [ ] 2.2 Verify native build still produces arm64 binaries
- [ ] 2.3 Compare configure output before/after to confirm CPU feature detection improves

## 3. darwin-x64 Documentation Fix

- [ ] 3.1 Update build.sh header comment to say "Native Intel build on macos-15-intel runners"
- [ ] 3.2 Update `verify_platform()` function - remove cross-compilation reference
- [ ] 3.3 Update `run_build()` log output - remove "Cross-compiling to x86_64" message

## 4. Assembly Optimization Verification

- [ ] 4.1 Add logging to FFmpeg build to show NASM detection status
- [ ] 4.2 Verify x264 configure output shows NASM enabled
- [ ] 4.3 Verify x265 configure output shows assembly enabled
- [ ] 4.4 Document expected configure output in verification step

## 5. Testing

- [ ] 5.1 Build darwin-arm64 locally and verify arm64 architecture
- [ ] 5.2 Run CI build on darwin-arm64 and verify artifacts
- [ ] 5.3 Verify darwin-x64 CI build with native Intel runner

## Dependencies

- Tasks 1.x can run in parallel
- Task 2.x depends on 1.x completion
- Task 3.x can run in parallel with 2.x
- Task 4.x depends on 2.x completion
- Task 5.x depends on all prior tasks
