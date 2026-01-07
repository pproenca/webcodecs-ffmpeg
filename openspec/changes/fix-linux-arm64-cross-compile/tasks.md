# Tasks: fix-linux-arm64-cross-compile

## 1. Update Autoconf Codec Recipes

- [x] 1.1 Update `shared/codecs/bsd/opus.mk` to pass `--host=$(HOST_TRIPLET)` when defined
- [x] 1.2 Update `shared/codecs/bsd/ogg.mk` to pass `--host=$(HOST_TRIPLET)` when defined
- [x] 1.3 Update `shared/codecs/bsd/vorbis.mk` to pass `--host=$(HOST_TRIPLET)` when defined
- [x] 1.4 Update `shared/codecs/lgpl/lame.mk` to pass `--host=$(HOST_TRIPLET)` when defined

## 2. Verification

- [ ] 2.1 Test linux-arm64 build locally with Docker: `./docker/build.sh linux-arm64 codecs`
- [ ] 2.2 Verify opus.stamp created successfully
- [ ] 2.3 Verify full build: `./docker/build.sh linux-arm64 all`
- [ ] 2.4 Push to CI and verify all 3 linux-arm64 jobs pass (bsd, lgpl, gpl)

## 3. Documentation

- [x] 3.1 Update CLAUDE.md with cross-compilation `--host` pattern for autoconf codecs
