# FFmpeg Linux ARM64 (glibc)

Static FFmpeg build for ARM64 Linux systems with glibc (Ubuntu, Debian, etc.).

## Target Platforms

- **Raspberry Pi 4 / 5** (Debian, Raspbian, Ubuntu)
- **AWS Graviton** (EC2 instances: t4g, c6g, m6g, r6g)
- **Oracle Cloud Ampere** (A1 instances)
- **NVIDIA Jetson** (Nano, Xavier, Orin)
- **Apple Silicon** (via Docker/VM with ARM64 Linux)
- **ARM64 Servers** (Ampere Altra, AWS Graviton3)

## Architecture Optimizations

This build includes ARM64-specific optimizations:

- **NEON intrinsics** for x264, x265, libvpx, libaom
- **ARM64 assembly** optimizations where available
- **Native ARM64 compilation** (not cross-compiled)
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

### Raspberry Pi 4 (4GB RAM, ARM Cortex-A72)

| Operation | Performance | Notes |
|-----------|------------|-------|
| 1080p H.264 decode | 60 fps | Hardware decode via V4L2 (separate variant) |
| 1080p H.264 encode (x264) | 8-12 fps | Software encoding |
| 720p H.264 encode (x264) | 20-30 fps | Acceptable for streaming |
| Audio transcoding | Real-time | Very fast on ARM |

### AWS Graviton2 (c6g.large - 2 vCPUs)

| Operation | Performance | Notes |
|-----------|------------|-------|
| 1080p H.264 encode (x264) | 25-35 fps | Good for batch jobs |
| 4K H.265 encode (x265) | 3-5 fps | Slow, use 1080p or smaller |
| 1080p VP9 encode | 15-20 fps | Modern codec performance |

### AWS Graviton3 (c7g.large - 2 vCPUs)

| Operation | Performance | Notes |
|-----------|------------|-------|
| 1080p H.264 encode (x264) | 40-50 fps | ~2x faster than Graviton2 |
| 4K H.265 encode (x265) | 6-8 fps | Viable for 4K workflows |
| AV1 encode (SVT-AV1) | 10-15 fps @ 1080p | Best AV1 performance |

*Performance varies based on codec settings, CPU cores, and memory*

## Usage Examples

### Basic Transcoding

```bash
# H.264 to H.265 (smaller file)
ffmpeg -i input.mp4 \
  -c:v libx265 \
  -preset medium \
  -crf 28 \
  -c:a copy \
  output.mp4
```

### Raspberry Pi Live Streaming

```bash
# Capture from camera and stream (720p)
ffmpeg -f v4l2 -i /dev/video0 \
  -c:v libx264 \
  -preset ultrafast \
  -tune zerolatency \
  -b:v 2M \
  -f flv rtmp://stream.example.com/live
```

### AWS Graviton Batch Transcoding

```bash
# Multi-threaded encoding (use all vCPUs)
ffmpeg -i input.mp4 \
  -c:v libx264 \
  -preset medium \
  -crf 23 \
  -threads 0 \
  output.mp4
```

## Docker Build

```bash
# From project root
docker buildx build \
  --platform linux/arm64 \
  -f platforms/linux-arm64-glibc/Dockerfile \
  -t ffmpeg-builder:linux-arm64-glibc \
  .
```

## Runtime Requirements

### System Libraries

Requires glibc 2.39+ (Ubuntu 24.04, Debian 13, or newer):

```bash
# Verify glibc version
ldd --version
# Expected: ldd (Ubuntu GLIBC 2.39-0ubuntu8) 2.39 or newer
```

### Disk Space

| Component | Size |
|-----------|------|
| FFmpeg binary | ~75-85 MB |
| FFprobe binary | ~75-80 MB |
| Static libraries | ~300 MB |
| Headers | ~10 MB |
| **Total** | ~460-475 MB |

## Cost-Effectiveness

ARM64 instances offer better price-performance for video encoding:

### AWS Pricing Comparison (us-east-1)

| Instance Type | Arch | vCPUs | RAM | Price/hour | Performance (1080p H.264) | Cost per 1000 frames |
|--------------|------|-------|-----|------------|-------------------------|---------------------|
| **c7g.large** | ARM64 | 2 | 4GB | $0.0725 | 40 fps | $0.05 |
| **c6i.large** | x64 | 2 | 4GB | $0.085 | 35 fps | $0.07 |
| **c7g.xlarge** | ARM64 | 4 | 8GB | $0.145 | 90 fps | $0.04 |
| **c6i.xlarge** | x64 | 4 | 8GB | $0.17 | 75 fps | $0.06 |

**ARM64 provides 20-40% cost savings** for the same encoding throughput.

## Raspberry Pi Use Cases

### Media Server

- **Plex/Jellyfin:** Transcode for streaming to devices
- **Home security:** Encode IP camera streams
- **Live streaming:** Stream events to YouTube/Twitch

### Recommended Settings

```bash
# For Raspberry Pi 4 (balance speed/quality)
ffmpeg -i input.mp4 \
  -c:v libx264 \
  -preset veryfast \
  -crf 28 \
  -maxrate 2M \
  -bufsize 4M \
  -c:a aac -b:a 128k \
  output.mp4
```

**Tips:**
- Use `-preset veryfast` or `-preset ultrafast` for real-time
- Keep resolution ≤ 720p for smooth performance
- Consider hardware decoding variant for better decode performance

## Build Time

**Estimated:**
- Raspberry Pi 4: 90-120 minutes (slow, but works)
- AWS Graviton2 (c6g.large): 35-45 minutes
- AWS Graviton3 (c7g.large): 25-35 minutes

**Recommendation:** Build on Graviton or use GitHub Actions (free ARM runners).

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

## See Also

- [x64 glibc variant](../linux-x64-glibc/) - For x64 Linux systems
- [ARM64 musl variant](../linux-arm64-musl/) - For Alpine Linux
- [ARMv7 variant](../linux-armv7-glibc/) - For older ARM devices (RPi 2/3)
- [CODECS.md](/CODECS.md) - Full codec documentation
- [BUILD-CONFIG.md](/BUILD-CONFIG.md) - Build customization options
