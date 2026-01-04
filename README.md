# FFmpeg Prebuilds

Static FFmpeg binaries and development libraries for Node.js, packaged as platform-specific npm modules.

## Overview

This repository builds and distributes FFmpeg with essential codecs (H.264, H.265, VP9, AV1, Opus, MP3) as:

- **Runtime packages**: `@pproenca/ffmpeg-*` — FFmpeg binaries for direct use
- **Development packages**: `@pproenca/ffmpeg-dev-*` — Static libraries + headers for native addon compilation
- **Main package**: `@pproenca/ffmpeg` — Meta-package with automatic platform detection

Built following the [sharp-libvips](https://github.com/lovell/sharp-libvips) distribution model.

## Installation

### For CLI usage:

```bash
npm install @pproenca/ffmpeg
```

### For native addon development:

```bash
# Install dev package for your platform
npm install --save-dev @pproenca/ffmpeg-dev-linux-x64-glibc
```

## Usage

### Using FFmpeg binaries:

```javascript
const { ffmpegPath, ffprobePath } = require('@pproenca/ffmpeg');
const { execSync } = require('child_process');

// Get FFmpeg version
const version = execSync(`"${ffmpegPath}" -version`, { encoding: 'utf8' });
console.log(version);

// Transcode video
execSync(`"${ffmpegPath}" -i input.mp4 -c:v libx264 output.mp4`);
```

### Using in native addons (binding.gyp):

```python
{
  'targets': [{
    'target_name': 'addon',
    'sources': ['addon.cc'],
    'include_dirs': [
      '<!@(node -p "require(\'path\').join(require.resolve(\'@pproenca/ffmpeg-dev-linux-x64-glibc/package.json\'), \'..\', \'include\')")',
    ],
    'libraries': [
      # Link directly against static libraries (no pkg-config needed)
      '<!@(node -p "require(\'path\').join(require.resolve(\'@pproenca/ffmpeg-dev-linux-x64-glibc/package.json\'), \'..\', \'lib\')")/libavcodec.a',
      '<!@(node -p "require(\'path\').join(require.resolve(\'@pproenca/ffmpeg-dev-linux-x64-glibc/package.json\'), \'..\', \'lib\')")/libavformat.a',
      '<!@(node -p "require(\'path\').join(require.resolve(\'@pproenca/ffmpeg-dev-linux-x64-glibc/package.json\'), \'..\', \'lib\')")/libavutil.a',
      # Add other FFmpeg libraries as needed (libswscale.a, libswresample.a, etc.)
    ],
  }],
}
```

Or set `FFMPEG_ROOT` in your environment for easier linking:

```bash
export FFMPEG_ROOT="$(npm root)/@pproenca/ffmpeg-dev-linux-x64-glibc"

# In your binding.gyp, reference libraries via environment variable
# libraries: ['<(FFMPEG_ROOT)/lib/libavcodec.a', ...]
npm run build
```

## Supported Platforms

| Platform | Runtime Package | Dev Package |
|----------|----------------|-------------|
| macOS x64 | `@pproenca/ffmpeg-darwin-x64` | `@pproenca/ffmpeg-dev-darwin-x64` |
| macOS ARM64 | `@pproenca/ffmpeg-darwin-arm64` | `@pproenca/ffmpeg-dev-darwin-arm64` |
| Linux x64 (glibc) | `@pproenca/ffmpeg-linux-x64-glibc` | `@pproenca/ffmpeg-dev-linux-x64-glibc` |
| Linux x64 (musl) | `@pproenca/ffmpeg-linux-x64-musl` | `@pproenca/ffmpeg-dev-linux-x64-musl` |

**Requirements:**
- macOS: 11.0 (Big Sur) or later
- Linux (glibc): Ubuntu 24.04 or equivalent (glibc 2.35+)
- Linux (musl): Alpine 3.21 or later

## Included Codecs

### Video
- **H.264** (libx264, GPL)
- **H.265/HEVC** (libx265, GPL)
- **VP8/VP9** (libvpx, BSD)
- **AV1** (libaom, BSD)

### Audio
- **Opus** (libopus, BSD)
- **MP3** (libmp3lame, LGPL)
- **Vorbis** (libvorbis + libogg, BSD)

## Build Artifacts

### What's Included
- **Binaries**: ffmpeg, ffprobe (statically linked, self-contained)
- **Static Libraries**: libx264.a, libx265.a, libvpx.a, libaom.a, libopus.a, libmp3lame.a, etc.
- **Headers**: Include files for all libraries (libavcodec, libavformat, libavutil, etc.)

### What's Excluded
- **PKGConfig files** (.pc): Not needed for static builds; removed to avoid path issues
- **Libtool files** (.la): Can cause relocation issues; removed
- **CMake files**: Build-time only; removed from distribution

### Why Static Builds?
This project distributes ready-to-use FFmpeg binaries, not development libraries.
All dependencies are statically linked into the final binaries, making them
completely self-contained with no external dependencies.

## Building from Source

### Prerequisites

- **macOS**: Xcode Command Line Tools, Homebrew
- **Linux**: Docker (for reproducible builds)
- **All**: Node.js 20+, Git

### Build a single platform:

```bash
# Clone repository
git clone https://github.com/pproenca/ffmpeg-prebuilds.git
cd ffmpeg-prebuilds

# Install dependencies
npm install

# Build for your current platform
./build/orchestrator.sh darwin-arm64  # macOS ARM64
./build/orchestrator.sh linux-x64-glibc  # Linux (Docker)

# Verify build
./build/verify.sh darwin-arm64

# Create npm packages
npm run package
```

### Build all platforms (via GitHub Actions):

```bash
git tag v8.0.0
git push --tags
# GitHub Actions will build all platforms in parallel
```

## Version Management

All codec versions are centralized in `versions.properties`:

```properties
FFMPEG_VERSION=n8.0
X264_VERSION=stable
X265_VERSION=3.6
LIBVPX_VERSION=v1.15.2
LIBAOM_VERSION=v3.12.1
# ... etc
```

To update dependencies:

1. Edit `versions.properties`
2. Bump `CACHE_VERSION` to invalidate CI cache
3. Run builds locally to test
4. Create a git tag and push to trigger release

## CI/CD Pipeline

The repository uses GitHub Actions for automated builds:

- **build.yml**: Matrix builds for all platforms (parallel, ~30min total)
- **release.yml**: Publishes to npm on version tags (`v*`)

### Workflow:

```
Tag Push (v8.0.0)
  ↓
Matrix Build (darwin-x64, darwin-arm64, linux-x64-glibc, linux-x64-musl)
  ↓
Create npm packages (runtime + dev)
  ↓
Publish to npm (@pproenca scope)
  ↓
Create GitHub Release (with binary tarballs)
```

## Development

### Testing changes locally:

```bash
# Build one platform
./build/orchestrator.sh darwin-arm64

# Verify output
ls -lh artifacts/darwin-arm64/

# Create packages
npm run package

# Test package installation
cd /tmp
npm install /path/to/ffmpeg-prebuilds/npm-dist/@pproenca/ffmpeg-darwin-arm64

# Verify binary works
node -e "console.log(require('@pproenca/ffmpeg').ffmpegPath)"
```

### Adding a new platform:

1. Create `platforms/<new-platform>/Dockerfile` (for Docker-based builds)
2. Add platform to `PLATFORMS` array in `scripts/package-npm.ts`
3. Update `build/orchestrator.sh` routing logic
4. Add matrix entry to `.github/workflows/build.yml`
5. Test build locally
6. Update this README

## Architecture

```
ffmpeg-prebuilds/
├── build/
│   ├── orchestrator.sh      # Delegates to platform scripts
│   ├── macos.sh             # macOS native builds
│   ├── linux.sh             # Docker-based Linux builds
│   └── verify.sh            # ABI validation
├── platforms/
│   ├── linux-x64-glibc/Dockerfile
│   ├── linux-x64-musl/Dockerfile
│   └── darwin-*/README.md   # Native runner docs
├── scripts/
│   └── package-npm.ts       # Creates npm packages from artifacts
├── versions.properties      # Single source of truth for versions
└── .github/workflows/
    ├── build.yml            # Parallel matrix builds
    └── release.yml          # npm publishing
```

## License

**GPL-2.0-or-later**

This package includes FFmpeg with x264 and x265, which are licensed under GPL v2+. Therefore, the entire distribution must be GPL v2 or later.

Individual codec licenses:
- FFmpeg: LGPL v2.1+ or GPL v2+ (we distribute GPL version)
- x264, x265: GPL v2+
- libvpx, libaom, Opus, Vorbis, Ogg: BSD

See [LICENSE](LICENSE) for full details.

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Test builds on your platform
4. Commit changes (`git commit -m 'Add amazing feature'`)
5. Push to the branch (`git push origin feature/amazing-feature`)
6. Open a Pull Request

### Reporting Issues

When reporting bugs, please include:

- Platform (macOS/Linux, architecture, libc variant)
- FFmpeg version (from `versions.properties`)
- Full error output
- Steps to reproduce

## Related Projects

- [node-webcodecs](https://github.com/pproenca/node-webcodecs) - W3C WebCodecs API for Node.js (uses these prebuilts)
- [sharp-libvips](https://github.com/lovell/sharp-libvips) - Inspiration for this distribution model
- [FFmpeg](https://ffmpeg.org/) - The multimedia framework we're packaging

## Acknowledgments

- FFmpeg team for the amazing multimedia framework
- Lovell Fuller for the sharp-libvips distribution pattern
- VideoLAN for x264
- MulticoreWare for x265
- Google/Chromium for libvpx
- Alliance for Open Media for libaom

## Support

- Issues: [GitHub Issues](https://github.com/pproenca/ffmpeg-prebuilds/issues)
- Discussions: [GitHub Discussions](https://github.com/pproenca/ffmpeg-prebuilds/discussions)
