# ffmpeg-prebuilds

Statically-linked FFmpeg binaries for Node.js native addons.

[![CI](https://github.com/pproenca/ffmpeg-prebuilds/actions/workflows/ci.yml/badge.svg)](https://github.com/pproenca/ffmpeg-prebuilds/actions/workflows/ci.yml)
[![npm](https://img.shields.io/npm/v/@pproenca/ffmpeg)](https://www.npmjs.com/package/@pproenca/ffmpeg)

## Install

```bash
npm install @pproenca/ffmpeg
```

The package auto-selects the correct binary for your platform.

## Packages

| Package | Codecs | License |
|---------|--------|---------|
| [`@pproenca/ffmpeg`](https://www.npmjs.com/package/@pproenca/ffmpeg) | VP8/9, AV1, Opus, Vorbis | BSD-3-Clause |
| [`@pproenca/ffmpeg-lgpl`](https://www.npmjs.com/package/@pproenca/ffmpeg-lgpl) | + MP3 (LAME) | LGPL-2.1+ |
| [`@pproenca/ffmpeg-gpl`](https://www.npmjs.com/package/@pproenca/ffmpeg-gpl) | + H.264, H.265 | GPL-2.0+ |

## Platforms

| Platform | Architecture | Status |
|----------|--------------|--------|
| macOS | ARM64 (Apple Silicon) | Supported |
| macOS | x86_64 | Planned |
| Linux | x86_64 | Planned |
| Windows | x86_64 | Planned |

## Usage

These packages provide FFmpeg headers and static libraries for building native
Node.js addons. See [Native Addon Usage](docs/native-addon-usage.md) for
integration with node-gyp and CMake.

```javascript
const ffmpeg = require('@pproenca/ffmpeg');

console.log(ffmpeg.include);  // Path to headers
console.log(ffmpeg.lib);      // Path to static libraries
console.log(ffmpeg.bin);      // Path to ffmpeg binary
```

## License

Multi-licensed depending on codec selection. See [LICENSE](LICENSE) for details.

Build scripts and tooling: MIT
