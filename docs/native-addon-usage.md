# Using FFmpeg Prebuilds for Node.js Native Addons

This guide explains how to use the `@pproenca/ffmpeg-*` npm packages to build Node.js native addons that link against FFmpeg.

## Package Structure

| Package | Contents | Purpose |
|---------|----------|---------|
| `@pproenca/ffmpeg-dev` | Headers (`include/`) | Compilation |
| `@pproenca/ffmpeg-{platform}-{tier}` | Static libs (`.a`), pkg-config (`.pc`) | Linking |
| `@pproenca/ffmpeg`, `@pproenca/ffmpeg-gpl`, etc. | Meta packages | Platform auto-selection |

**Platforms:** `darwin-arm64`, `darwin-x64`

**Tiers:**
- `bsd` (default): VP8/9, AV1, Opus, Vorbis
- `lgpl`: BSD + MP3
- `gpl`: All codecs including x264/x265

## Installation

```bash
npm install @pproenca/ffmpeg-dev @pproenca/ffmpeg-gpl
```

The meta package (`@pproenca/ffmpeg-gpl`) automatically installs the correct platform-specific package via `optionalDependencies`.

## binding.gyp Configuration

### Basic Example

```gyp
{
  "targets": [{
    "target_name": "myaddon",
    "sources": ["src/addon.cc"],
    "include_dirs": [
      "<!@(node -p \"require('node-addon-api').include\")",
      "<!(node -p \"require('@pproenca/ffmpeg-dev/gyp-config').include\")"
    ],
    "defines": ["NAPI_DISABLE_CPP_EXCEPTIONS"],
    "conditions": [
      ["OS=='mac'", {
        "libraries": [
          "<!@(PKG_CONFIG_PATH=<!(node -p \"require('@pproenca/ffmpeg-gpl/resolve').pkgconfig\") pkg-config --static --libs libavcodec libavutil)"
        ],
        "xcode_settings": {
          "OTHER_LDFLAGS": [
            "-framework CoreFoundation",
            "-framework VideoToolbox",
            "-framework CoreMedia",
            "-framework CoreVideo"
          ]
        }
      }]
    ]
  }]
}
```

### Helper Modules

**`@pproenca/ffmpeg-dev/gyp-config`:**
```javascript
const config = require('@pproenca/ffmpeg-dev/gyp-config');
console.log(config.include); // Path to headers
```

**`@pproenca/ffmpeg-gpl/resolve`:**
```javascript
const resolve = require('@pproenca/ffmpeg-gpl/resolve');
console.log(resolve.lib);       // Path to static libraries
console.log(resolve.pkgconfig); // Path to pkg-config files
```

### Available pkg-config Modules

```bash
# List all available modules
PKG_CONFIG_PATH=$(node -p "require('@pproenca/ffmpeg-gpl/resolve').pkgconfig") pkg-config --list-all

# Common modules:
# libavcodec  - Encoding/decoding
# libavutil   - Utilities (always required)
# libavformat - Container formats (muxing/demuxing)
# libswscale  - Scaling/color conversion
# libswresample - Audio resampling
```

## Example: Minimal Addon

**package.json:**
```json
{
  "name": "my-ffmpeg-addon",
  "version": "1.0.0",
  "main": "index.js",
  "scripts": {
    "install": "node-gyp rebuild",
    "prebuild": "prebuildify --napi --strip"
  },
  "devDependencies": {
    "@pproenca/ffmpeg-dev": "^0.1.5",
    "@pproenca/ffmpeg-gpl": "^0.1.5",
    "node-addon-api": "^7.0.0",
    "node-gyp": "^10.0.0",
    "prebuildify": "^6.0.0"
  }
}
```

**src/addon.cc:**
```cpp
#include <napi.h>

extern "C" {
#include <libavcodec/avcodec.h>
#include <libavutil/avutil.h>
}

Napi::String GetVersion(const Napi::CallbackInfo& info) {
  Napi::Env env = info.Env();
  return Napi::String::New(env, av_version_info());
}

Napi::Object Init(Napi::Env env, Napi::Object exports) {
  exports.Set("version", Napi::Function::New(env, GetVersion));
  return exports;
}

NODE_API_MODULE(myaddon, Init)
```

**index.js:**
```javascript
const path = require('path');
const binary = require('node-gyp-build')(path.join(__dirname));
module.exports = binary;
```

## Distributing Precompiled Binaries

Use [prebuildify](https://github.com/prebuild/prebuildify) to ship precompiled `.node` files:

```bash
# Build for current platform
npx prebuildify --napi --strip

# Result: prebuilds/darwin-arm64/node.napi.node
```

### CI Workflow Example

```yaml
# .github/workflows/prebuild.yml
name: Prebuild
on: push

jobs:
  build:
    strategy:
      matrix:
        os: [macos-14, macos-13]  # arm64, x64
    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 20
      - run: npm ci
      - run: npx prebuildify --napi --strip
      - uses: actions/upload-artifact@v4
        with:
          name: prebuilds-${{ matrix.os }}
          path: prebuilds/
```

## FFmpeg APIs for WebCodecs-style Usage

| WebCodecs Concept | FFmpeg Equivalent |
|-------------------|-------------------|
| VideoDecoder | `avcodec_open2()`, `avcodec_send_packet()`, `avcodec_receive_frame()` |
| VideoEncoder | `avcodec_open2()`, `avcodec_send_frame()`, `avcodec_receive_packet()` |
| VideoFrame | `AVFrame` |
| EncodedVideoChunk | `AVPacket` |

### Decoder Example (C++)

```cpp
#include <libavcodec/avcodec.h>

// Find decoder
const AVCodec* codec = avcodec_find_decoder(AV_CODEC_ID_H264);

// Allocate context
AVCodecContext* ctx = avcodec_alloc_context3(codec);

// Open decoder
avcodec_open2(ctx, codec, NULL);

// Decode loop
AVPacket* pkt = av_packet_alloc();
AVFrame* frame = av_frame_alloc();

// Send packet to decoder
avcodec_send_packet(ctx, pkt);

// Receive decoded frame
avcodec_receive_frame(ctx, frame);
```

## Troubleshooting

### "pkg-config not found"

Install pkg-config:
```bash
# macOS
brew install pkg-config
```

### "Library not found"

Ensure the platform package is installed:
```bash
npm ls @pproenca/ffmpeg-darwin-arm64-gpl
```

### Linker errors about missing symbols

Add required frameworks to `OTHER_LDFLAGS`:
```gyp
"OTHER_LDFLAGS": [
  "-framework CoreFoundation",
  "-framework VideoToolbox",
  "-framework CoreMedia",
  "-framework CoreVideo",
  "-framework Security"
]
```

### "undefined reference to x265/x264"

Ensure you're using the GPL tier:
```bash
npm install @pproenca/ffmpeg-gpl
```

## License Considerations

- **BSD tier**: Safe for any project
- **LGPL tier**: Requires LGPL compliance (dynamic linking or source disclosure)
- **GPL tier**: Requires GPL compliance (full source disclosure)

Choose the tier that matches your licensing requirements.
