# Windows x64 FFmpeg Build

Cross-compiled Windows x64 FFmpeg binaries using MinGW-w64 on Ubuntu 24.04.

## Build Method

This platform uses **cross-compilation** from Linux to Windows, following the [official FFmpeg Windows cross-compilation guide](https://trac.ffmpeg.org/wiki/CompilationGuide/CrossCompilingForWindows).

## Toolchain

- **Compiler:** MinGW-w64 (x86_64-w64-mingw32-gcc)
- **Host System:** Ubuntu 24.04
- **Target System:** Windows 10/11 x64

## Output

- `ffmpeg.exe` - Main FFmpeg binary (statically linked)
- `ffprobe.exe` - FFprobe analysis tool
- Static libraries (`.a` files) - For development

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

## Build Time

**Estimated:** 25-35 minutes (in Docker on Ubuntu runner)

## Building Locally

### Prerequisites

- Docker installed
- 4 GB free disk space

### Build Command

```bash
# From repository root
./build/orchestrator.sh windows-x64
```

This will:
1. Build Docker image with MinGW-w64 toolchain
2. Cross-compile all codec dependencies
3. Cross-compile FFmpeg
4. Extract artifacts to `artifacts/windows-x64/`

### Verify Build

```bash
# Check binary exists
ls -lh artifacts/windows-x64/bin/ffmpeg.exe

# Check architecture (should show PE32+ for Windows x64)
file artifacts/windows-x64/bin/ffmpeg.exe
```

## Testing on Windows

To test the built binaries on Windows:

```powershell
# Copy artifacts to Windows machine
# Run ffmpeg.exe
.\ffmpeg.exe -version

# Test encoding
.\ffmpeg.exe -i input.mp4 -c:v libx264 -crf 23 output.mp4
```

## npm Package

Published as: `@pproenca/ffmpeg-windows-x64`

## Static Linking

All dependencies are statically linked into the `.exe` files. No external DLLs required.

## License

GPL v2+ (due to x264 and x265)

See `CODECS.md` for detailed licensing information.
