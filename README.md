# ffmpeg-prebuilds

Statically-linked FFmpeg binaries for Node.js native addons.

[![CI](https://github.com/pproenca/ffmpeg-prebuilds/actions/workflows/ci.yml/badge.svg)](https://github.com/pproenca/ffmpeg-prebuilds/actions/workflows/ci.yml)
[![npm](https://img.shields.io/npm/v/@pproenca/webcodecs-ffmpeg)](https://www.npmjs.com/package/@pproenca/webcodecs-ffmpeg)

## Install

```bash
npm install @pproenca/webcodecs-ffmpeg
```

The package auto-selects the correct binary for your platform.

## Packages

| Package | Codecs | License | Use Case |
|---------|--------|---------|----------|
| [`@pproenca/webcodecs-ffmpeg`](https://www.npmjs.com/package/@pproenca/webcodecs-ffmpeg) | VP8/9, AV1, Opus, Vorbis, MP3 | LGPL-2.1+ | Commercial/proprietary apps |
| [`@pproenca/webcodecs-ffmpeg-non-free`](https://www.npmjs.com/package/@pproenca/webcodecs-ffmpeg-non-free) | All above + H.264, H.265 | GPL-2.0+ | Open source projects |

**Default (`@pproenca/webcodecs-ffmpeg`)** is safe for commercial use with LGPL compliance.

Use `@pproenca/webcodecs-ffmpeg-non-free` for x264/x265 codecs (requires GPL compliance - full source disclosure).

## Platforms

| Platform | Architecture | Status |
|----------|--------------|--------|
| macOS | ARM64 (Apple Silicon) | Supported |
| macOS | x86_64 (Intel) | Supported |
| Linux | x86_64 | Supported |
| Linux | ARM64 | Supported |
| Windows | x86_64 | Planned |

## Usage

These packages provide FFmpeg headers and static libraries for building native
Node.js addons. See [Native Addon Usage](docs/native-addon-usage.md) for
integration with node-gyp and CMake.

```javascript
const ffmpeg = require('@pproenca/webcodecs-ffmpeg');

console.log(ffmpeg.include);  // Path to headers
console.log(ffmpeg.lib);      // Path to static libraries
console.log(ffmpeg.bin);      // Path to ffmpeg binary
```

## License

Multi-licensed depending on codec selection. See [LICENSE](LICENSE) for details.

Build scripts and tooling: MIT
