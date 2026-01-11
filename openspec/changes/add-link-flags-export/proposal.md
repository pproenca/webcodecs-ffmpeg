# Add Link Flags Export

## Summary

Add a `./link-flags` export to platform-specific npm packages that provides pre-computed linker flags for native addon compilation. Each platform package exports the complete set of flags needed to link against FFmpeg and its codec dependencies.

## Problem

Consumers building native Node.js addons against these FFmpeg packages must manually determine:
1. The correct FFmpeg library link order (reverse dependency order matters for static linking)
2. Which codec libraries were included in the build
3. Platform-specific system libraries (-lpthread, -ldl, -liconv, etc.)
4. macOS frameworks (VideoToolbox, CoreMedia, etc.)

This is error-prone and requires consumers to understand FFmpeg's build configuration.

## Solution

Generate a `link-flags.js` file in each platform package during artifact population. The file exports:

```js
module.exports = {
  libDir,  // Absolute path to lib directory
  flags    // Complete linker flags string
};
```

Example usage in node-webcodecs:
```js
const pkgName = isMuslLibc()
  ? '@pproenca/webcodecs-ffmpeg-linux-x64-musl'
  : '@pproenca/webcodecs-ffmpeg-linux-x64';
const { flags } = require(`${pkgName}/link-flags`);
```

## Scope

**In scope:**
- Add `./link-flags` export to all platform package.json files
- Generate link-flags.js during `populate-artifacts.sh`
- Include FFmpeg libs, codec libs, system libs, and frameworks per platform
- Include link-flags.js in package `files` array

**Out of scope:**
- Changes to the main `@pproenca/webcodecs-ffmpeg` package (uses resolve.js pattern)
- Changes to the dev package (headers only, no linking)
- Runtime platform detection (already handled by consumers)

## Affected Packages

| Package | Gets link-flags.js |
|---------|-------------------|
| @pproenca/webcodecs-ffmpeg-darwin-arm64 | Yes |
| @pproenca/webcodecs-ffmpeg-darwin-x64 | Yes |
| @pproenca/webcodecs-ffmpeg-linux-arm64 | Yes |
| @pproenca/webcodecs-ffmpeg-linux-x64 | Yes |
| @pproenca/webcodecs-ffmpeg-linux-x64-musl | Yes |
| @pproenca/webcodecs-ffmpeg-*-non-free | Yes (same pattern) |
| @pproenca/webcodecs-ffmpeg (main) | No (uses resolve.js) |
| @pproenca/webcodecs-ffmpeg-dev | No (headers only) |
