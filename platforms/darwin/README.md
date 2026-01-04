# macOS Universal FFmpeg Build

Universal binaries for macOS that run on both Intel (x86_64) and Apple Silicon (arm64) Macs.

## Build Method

This platform merges separate x64 and arm64 builds using Apple's `lipo` tool to create universal binaries, following Apple's recommended distribution approach for maximum compatibility.

## Architecture Support

- **Intel Macs:** x86_64 (64-bit)
- **Apple Silicon:** arm64 (M1, M2, M3, M4 series)

## Output

- `ffmpeg` - Universal FFmpeg binary (runs on both architectures)
- `ffprobe` - Universal FFprobe tool
- Universal static libraries - For development

## Included Codecs

### Video
- **H.264:** libx264 (GPL)
- **H.265/HEVC:** libx265 (GPL)
- **VP8/VP9:** libvpx (BSD)
- **AV1:** libaom (BSD)

### Audio
- **Opus:** libopus (BSD)
- **MP3:** libmp3lame (LGPL)
- **Vorbis:** libvorbis (BSD)

## Build Requirements

- macOS 11.0 (Big Sur) or later
- Xcode Command Line Tools
- Both darwin-x64 and darwin-arm64 builds must exist

## Build Time

**Estimated:** 40-50 minutes total
- darwin-x64 build: 20-25 minutes
- darwin-arm64 build: 20-25 minutes
- lipo merge: < 1 minute

## Building Locally

### Prerequisites

```bash
# Install Xcode Command Line Tools
xcode-select --install

# Verify lipo is available
which lipo
```

### Build Commands

```bash
# From repository root

# Step 1: Build both architectures
./build/orchestrator.sh darwin-x64
./build/orchestrator.sh darwin-arm64

# Step 2: Create universal binaries
./build/create-universal.sh
```

This will create universal binaries at `artifacts/darwin-universal/`

### Verify Universal Binary

```bash
# Check binary architecture
file artifacts/darwin-universal/bin/ffmpeg

# Should show:
# Mach-O universal binary with 2 architectures:
#   [x86_64] ...
#   [arm64] ...

# Or use lipo -info
lipo -info artifacts/darwin-universal/bin/ffmpeg

# Should show:
# Architectures in the fat file: ... are: x86_64 arm64
```

### Run FFmpeg

```bash
# The universal binary automatically runs the native architecture
./artifacts/darwin-universal/bin/ffmpeg -version

# Check which architecture is running
./artifacts/darwin-universal/bin/ffmpeg -version | head -1
```

## npm Package

Published as: `@pproenca/ffmpeg-darwin-universal`

Replaces:
- `@pproenca/ffmpeg-darwin-x64` (deprecated)
- `@pproenca/ffmpeg-darwin-arm64` (deprecated)

## Deployment Target

Minimum macOS version: **11.0** (Big Sur)

This ensures compatibility with:
- macOS 11 (2020) - First Apple Silicon release
- macOS 12 (Monterey)
- macOS 13 (Ventura)
- macOS 14 (Sonoma)
- macOS 15 (Sequoia)

## Static Linking

All dependencies are statically linked. No external libraries required.

## Binary Size

- ffmpeg: ~8-9 MB (compressed)
- ffprobe: ~7-8 MB (compressed)

Universal binaries are roughly 2x the size of single-architecture builds.

## License

GPL v2+ (due to x264 and x265)

See `CODECS.md` for detailed licensing information.

## Technical Details

### How Universal Binaries Work

A universal binary is a "fat" binary containing code for multiple architectures. The operating system automatically loads and executes the appropriate slice for the current architecture.

### Creating Universal Libraries

```bash
# Merge two architectures
lipo -create \
  artifacts/darwin-x64/bin/ffmpeg \
  artifacts/darwin-arm64/bin/ffmpeg \
  -output artifacts/darwin-universal/bin/ffmpeg

# Verify
lipo -info artifacts/darwin-universal/bin/ffmpeg
```

### Performance

Both architectures run at native speed - there's no emulation or performance penalty. The system simply loads the appropriate binary slice.

## Migration from Separate Packages

If you were using separate packages:

```javascript
// Old approach (separate packages)
import ffmpeg from '@pproenca/ffmpeg-darwin-x64';  // Intel only
import ffmpeg from '@pproenca/ffmpeg-darwin-arm64'; // Apple Silicon only

// New approach (universal package)
import ffmpeg from '@pproenca/ffmpeg-darwin-universal'; // Works on both
```

The universal package automatically selects the correct architecture at runtime.
