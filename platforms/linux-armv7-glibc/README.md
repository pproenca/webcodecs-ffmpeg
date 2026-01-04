# FFmpeg Linux ARMv7 (glibc)

Static FFmpeg build for ARMv7 Linux systems with glibc (older 32-bit ARM devices).

## Target Platforms

- **Raspberry Pi 2 / 3** (Raspbian/Raspberry Pi OS 32-bit)
- **Raspberry Pi Zero 2 W** (ARMv7 quad-core)
- **Older ARM Single-Board Computers** (ODROID-C1, BeagleBone Black)
- **Legacy ARM devices** (32-bit ARM Linux)
- **Embedded systems** (ARMv7-based industrial devices)

## Architecture Characteristics

ARMv7 is the 32-bit ARM architecture (predecessor to ARM64):

- **32-bit instruction set** (armhf/armv7l)
- **Limited NEON support** compared to ARM64
- **Lower performance** than ARM64 (older architecture)
- **Still widely deployed** in legacy and embedded systems

**Performance expectation:** 2-3x slower than ARM64 for video encoding.

## Architecture Optimizations

This build includes ARMv7-specific optimizations where available:

- **NEON intrinsics** (limited compared to ARM64)
- **ARMv7 assembly** optimizations where available
- **Native ARMv7 compilation** (not cross-compiled)
- **Position-Independent Code** (PIC) for shared library linking

## Supported Codecs

**Video Encoders:**
- H.264/AVC (libx264) - GPL
- H.265/HEVC (libx265) - GPL
- VP8/VP9 (libvpx) - BSD
- AV1 (libaom, SVT-AV1) - BSD
- Theora (libtheora) - BSD
- MPEG-4 ASP (Xvid) - GPL

**Audio Encoders:**
- Opus (libopus) - BSD
- MP3 (libmp3lame) - LGPL
- AAC (libfdk-aac) - Non-free
- Vorbis (libvorbis) - BSD
- FLAC - BSD
- Speex - BSD

**Additional Features:**
- Subtitle rendering (libass) - ISC
- Font rendering (libfreetype) - FreeType License

## Performance Characteristics

### Raspberry Pi 3 (1GB RAM, ARM Cortex-A53)

| Operation | Performance | Notes |
|-----------|------------|-------|
| 480p H.264 encode (x264) | 10-15 fps | Recommended max resolution |
| 720p H.264 encode (x264) | 4-6 fps | Slow, but viable for offline |
| 1080p H.264 encode (x264) | 1-2 fps | Too slow for practical use |
| Audio transcoding | Real-time | Fast enough for all formats |

### Raspberry Pi 2 (1GB RAM, ARM Cortex-A7)

| Operation | Performance | Notes |
|-----------|------------|-------|
| 480p H.264 encode (x264) | 6-10 fps | Acceptable for basic use |
| 720p H.264 encode (x264) | 2-4 fps | Very slow |
| Audio-only tasks | Real-time | Audio transcoding works well |

**Recommendation:** Keep resolution ≤ 480p for real-time encoding. Use `-preset ultrafast` for best performance.

## Usage Examples

### Basic Transcoding (Optimized for ARMv7)

```bash
# Transcode to 480p H.264 (recommended max for Pi 2/3)
ffmpeg -i input.mp4 \
  -vf scale=854:480 \
  -c:v libx264 \
  -preset ultrafast \
  -crf 28 \
  -c:a aac -b:a 128k \
  output.mp4
```

### Raspberry Pi Security Camera

```bash
# Encode USB camera stream (480p, low latency)
ffmpeg -f v4l2 -i /dev/video0 \
  -vf scale=640:480 \
  -c:v libx264 \
  -preset ultrafast \
  -tune zerolatency \
  -b:v 1M \
  -c:a aac -b:a 64k \
  -f flv rtmp://stream.example.com/live
```

### Audio-Only Transcoding (Fast)

```bash
# Convert FLAC to MP3 (no video, very fast)
ffmpeg -i input.flac \
  -c:a libmp3lame \
  -b:a 192k \
  output.mp3
```

### Time-Lapse Creation

```bash
# Create time-lapse from images (less demanding)
ffmpeg -framerate 30 -pattern_type glob -i '*.jpg' \
  -c:v libx264 \
  -preset medium \
  -crf 28 \
  -pix_fmt yuv420p \
  timelapse.mp4
```

## Docker Build

```bash
# From project root
docker buildx build \
  --platform linux/arm/v7 \
  -f platforms/linux-armv7-glibc/Dockerfile \
  -t ffmpeg-builder:linux-armv7-glibc \
  .
```

## Runtime Requirements

### System Libraries

Requires glibc 2.39+ (Ubuntu 24.04, Debian 13, or newer):

```bash
# Verify glibc version
ldd --version
# Expected: ldd (Ubuntu GLIBC 2.39) 2.39 or newer
```

### Disk Space

| Component | Size |
|-----------|------|
| FFmpeg binary | ~70-80 MB |
| FFprobe binary | ~70-75 MB |
| Static libraries | ~280 MB |
| Headers | ~10 MB |
| **Total** | ~430-445 MB |

*ARMv7 binaries are slightly smaller than ARM64 due to 32-bit architecture*

## Raspberry Pi Performance Tips

### 1. Use Fastest Preset

```bash
# Always use -preset ultrafast or -preset veryfast
ffmpeg -i input.mp4 -c:v libx264 -preset ultrafast output.mp4
```

### 2. Keep Resolution Low

```bash
# Scale down to 480p or 720p max
ffmpeg -i input.mp4 -vf scale=854:480 -c:v libx264 output.mp4
```

### 3. Reduce Frame Rate

```bash
# Lower frame rate for smoother encoding
ffmpeg -i input.mp4 -r 24 -c:v libx264 output.mp4
```

### 4. Single-Pass Encoding

```bash
# Avoid 2-pass encoding (too slow)
ffmpeg -i input.mp4 -c:v libx264 -crf 28 output.mp4
```

### 5. Audio-Only When Possible

```bash
# Extract audio for fast processing
ffmpeg -i input.mp4 -vn -c:a libmp3lame audio.mp3
```

## Use Cases

### 1. Home Security Camera System

- Encode multiple camera streams at 480p
- Store to local storage or cloud
- ARMv7 is sufficient for 1-2 streams

### 2. Audio Streaming Server

- Transcode audio formats (FLAC → MP3, etc.)
- Podcast recording/editing
- ARMv7 handles audio easily

### 3. Time-Lapse Photography

- Combine images into video
- Low-resolution time-lapses (720p)
- Offline processing (can take hours)

### 4. Legacy Device Support

- Maintain older ARM hardware
- Embedded industrial systems
- IoT video processing

### 5. Educational Projects

- Learn video encoding concepts
- Home automation projects
- Maker community projects

## Build Time

**Estimated:**
- Raspberry Pi 3: 150-180 minutes (2.5-3 hours)
- Raspberry Pi 2: 240-300 minutes (4-5 hours)

**Recommendation:** Build on a faster machine or use GitHub Actions (free ARM runners). Cross-compilation from x64 is also supported.

## Comparison: ARMv7 vs ARM64

| Aspect | ARMv7 (this build) | ARM64 |
|--------|-------------------|-------|
| **Architecture** | 32-bit | 64-bit |
| **Target devices** | Raspberry Pi 2/3 | Raspberry Pi 4/5, Graviton |
| **NEON support** | Limited | Extensive |
| **1080p H.264 encode** | 1-2 fps | 8-12 fps (Pi 4) |
| **720p H.264 encode** | 4-6 fps | 20-30 fps (Pi 4) |
| **Recommended max** | 480p | 1080p |
| **Use case** | Legacy devices | Modern devices |

**If you have a Raspberry Pi 4 or newer:** Use the ARM64 variant for 3-4x better performance.

## Migration from ARMv7 to ARM64

Many ARMv7 devices can run ARM64 OS:

| Device | ARMv7 Support | ARM64 Support | Recommendation |
|--------|--------------|---------------|----------------|
| **Raspberry Pi 4/5** | ❌ ARM64 only | ✅ Native | Use ARM64 build |
| **Raspberry Pi 3** | ✅ Native | ✅ 64-bit OS available | Upgrade to 64-bit OS + ARM64 build |
| **Raspberry Pi 2** | ✅ Native | ❌ Not supported | Use ARMv7 build |
| **Raspberry Pi Zero 2 W** | ✅ Native | ✅ 64-bit OS available | Upgrade to 64-bit OS recommended |

## Licensing

This build is **GPL-2.0-or-later** due to:
- libx264 (GPL)
- libx265 (GPL)
- Xvid (GPL)

Additionally includes **non-free** components:
- libfdk-aac (Fraunhofer FDK AAC)

**Cannot redistribute commercially** without license compliance.

For LGPL-only build (commercial-friendly), use:
- Disable x264, x265, Xvid, fdk-aac
- Use only BSD/LGPL codecs (VP9, AV1, Opus, Vorbis)

## Troubleshooting

### "Illegal instruction" error

```bash
# Verify ARMv7 architecture
uname -m
# Expected: armv7l

# If shows "aarch64", you're running ARM64 OS - use ARM64 build instead
```

### Slow encoding performance

```bash
# Use ultrafast preset and lower resolution
ffmpeg -i input.mp4 \
  -vf scale=640:480 \
  -c:v libx264 \
  -preset ultrafast \
  output.mp4
```

### Out of memory

```bash
# Raspberry Pi 2/3 have limited RAM (1GB)
# Process smaller files or increase swap
sudo dphys-swapfile swapoff
sudo nano /etc/dphys-swapfile  # Set CONF_SWAPSIZE=2048
sudo dphys-swapfile setup
sudo dphys-swapfile swapon
```

## See Also

- [ARM64 glibc variant](../linux-arm64-glibc/) - For Raspberry Pi 4/5, AWS Graviton
- [ARM64 musl variant](../linux-arm64-musl/) - For Alpine Linux on ARM64
- [x64 glibc variant](../linux-x64-glibc/) - For x64 Linux systems
- [CODECS.md](/CODECS.md) - Full codec documentation
- [BUILD-CONFIG.md](/BUILD-CONFIG.md) - Build customization options
