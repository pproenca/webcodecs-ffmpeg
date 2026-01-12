# Tasks: Disable LTO for SVT-AV1 on musl Builds

## 1. Implementation

- [x] 1.1 Add `SVTAV1_CMAKE_OPTS` variable to `platforms/linuxmusl-x64/config.mk` with `-DSVT_AV1_LTO=OFF`
- [x] 1.2 Update `shared/codecs/bsd/svt-av1.mk` to include `$(SVTAV1_CMAKE_OPTS)` in cmake invocation
- [x] 1.3 Add comment in config.mk explaining why LTO is disabled for musl

## 2. Verification

- [ ] 2.1 Build SVT-AV1 locally on musl container to confirm LTO is disabled
- [ ] 2.2 Verify `libSvtAv1Enc.a` does not contain LTO bytecode (inspect with `file` or `nm`)
- [ ] 2.3 Confirm FFmpeg links successfully against the rebuilt library

## 3. CI Validation

- [ ] 3.1 Push changes to trigger CI build for `linuxmusl-x64`
- [ ] 3.2 Verify both `free` and `non-free` tiers build successfully
- [ ] 3.3 Confirm existing platforms (darwin-arm64, darwin-x64, linux-arm64, linux-x64) are unaffected

## 4. Release

- [ ] 4.1 Run `./scripts/bump-version.sh patch` to bump to 0.1.5
- [ ] 4.2 Push commit and tag: `git push origin master v0.1.5`
- [ ] 4.3 Trigger release workflow with tag `v0.1.5`
- [ ] 4.4 Verify npm packages published successfully
