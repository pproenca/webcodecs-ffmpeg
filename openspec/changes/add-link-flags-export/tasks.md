# Tasks: Add Link Flags Export

## Implementation Tasks

### 1. Update platform package.json files

Add `./link-flags` export and include in files array.

**Files to modify:**
- [x] `npm/webcodecs-ffmpeg-darwin-arm64/package.json`
- [x] `npm/webcodecs-ffmpeg-darwin-x64/package.json`
- [x] `npm/webcodecs-ffmpeg-linux-arm64/package.json`
- [x] `npm/webcodecs-ffmpeg-linux-x64/package.json`
- [x] `npm/webcodecs-ffmpeg-linux-x64-musl/package.json`
- [x] `npm/webcodecs-ffmpeg-darwin-arm64-non-free/package.json`
- [x] `npm/webcodecs-ffmpeg-darwin-x64-non-free/package.json`
- [x] `npm/webcodecs-ffmpeg-linux-arm64-non-free/package.json`
- [x] `npm/webcodecs-ffmpeg-linux-x64-non-free/package.json`
- [x] `npm/webcodecs-ffmpeg-linux-x64-musl-non-free/package.json`

Changes per file:
```json
{
  "files": ["lib", "versions.json", "link-flags.js"],
  "exports": {
    "./lib": "./lib/index.js",
    "./pkgconfig": "./lib/pkgconfig/index.js",
    "./link-flags": "./link-flags.js",
    "./package": "./package.json",
    "./versions": "./versions.json"
  }
}
```

### 2. Add link-flags generation to populate-artifacts.sh

Add a `generate_link_flags` function that creates platform-specific link-flags.js files.

**Subtasks:**
- [x] Define platform-to-flags mapping (darwin, linux-glibc, linux-musl)
- [x] Define FFmpeg library order array
- [x] Define codec library arrays (free vs non-free)
- [x] Generate link-flags.js with correct platform flags
- [x] Call generation in `populate_platform` function

### 3. Verify generation locally

- [x] Run `./scripts/populate-artifacts.sh` with sample artifacts
- [x] Check generated link-flags.js content for each platform
- [x] Verify exports work: `node -p "require('./npm/webcodecs-ffmpeg-darwin-arm64/link-flags')"`

## Validation

- [x] All platform package.json files have consistent exports
- [x] Generated link-flags.js files have correct platform-specific flags
- [x] No lint errors in generated JavaScript
- [x] Package files array includes link-flags.js

## Dependencies

- Depends on existing artifact population workflow
- No changes to build system (Makefiles)
- No changes to CI workflows
