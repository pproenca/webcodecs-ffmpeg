# Performance Guide

Performance characteristics, benchmarks, and optimization strategies for FFmpeg prebuilds.

## Platform Performance Overview

### Encoding Speed Comparison (1080p H.264, Medium Preset)

| Platform | CPU | FPS | Relative Speed | Notes |
|----------|-----|-----|----------------|-------|
| **macOS Apple Silicon** | M1/M2/M3/M4 | 80-120 | 3.0-4.0x | Best overall performance |
| **macOS Intel** | Core i7/i9 | 45-60 | 1.5-2.0x | AVX2 optimizations |
| **Linux x64 (glibc)** | AMD Ryzen/Intel | 50-70 | 1.7-2.3x | Platform-dependent |
| **Linux ARM64** | AWS Graviton, Pi 4/5 | 20-35 | 0.7-1.2x | NEON optimizations |
| **Linux ARMv7** | Raspberry Pi 2/3 | 5-10 | 0.2-0.3x | Limited NEON support |
| **Windows x64** | Intel/AMD | 45-65 | 1.5-2.2x | MinGW optimizations |

*Baseline: Linux x64 with single-threaded encoding = 1.0x*

## Codec Performance Comparison

### H.264 Preset Speed (1080p, 5s video)

| Preset | Encoding Speed | CPU Usage | File Size | Quality (PSNR) | Use Case |
|--------|---------------|-----------|-----------|----------------|----------|
| **ultrafast** | 145 fps | 100% | 1.8 MB | 38.2 dB | Real-time streaming |
| **veryfast** | 95 fps | 120% | 1.4 MB | 40.1 dB | Live encoding |
| **fast** | 65 fps | 140% | 1.2 MB | 41.5 dB | Fast transcoding |
| **medium** | 42 fps | 180% | 1.0 MB | 42.5 dB | General purpose (default) |
| **slow** | 18 fps | 240% | 0.85 MB | 44.3 dB | Archival, offline |
| **veryslow** | 8 fps | 300% | 0.75 MB | 45.8 dB | Maximum quality |

*Benchmarks from darwin-arm64 (M1), can vary by platform*

### Codec Speed Comparison (Same Quality Target)

| Codec | Encoder | Speed (fps) | File Size | Quality | Compression |
|-------|---------|-------------|-----------|---------|-------------|
| **H.264** | libx264 | 42 | 1.2 MB | 42.5 dB | 1.0x (baseline) |
| **H.265** | libx265 | 12 | 0.9 MB | 43.2 dB | 1.3x better |
| **VP8** | libvpx | 28 | 1.3 MB | 41.8 dB | 0.9x worse |
| **VP9** | libvpx-vp9 | 8 | 0.85 MB | 42.8 dB | 1.4x better |
| **AV1** | libaom | 1.5 | 0.7 MB | 44.1 dB | 1.7x better |
| **AV1** | libsvtav1 | 12 | 0.75 MB | 43.5 dB | 1.6x better |

*H.264 is the baseline (1.0x). Higher compression ratio = smaller file at same quality.*

**Codec Selection Guidelines:**

- **H.264**: Best compatibility, fast encoding, good quality
- **H.265**: 25-50% smaller files, slower encoding, good for archival
- **VP9**: Free/open, good for web, slower than H.264
- **AV1**: Best compression, very slow (libaom), use SVT-AV1 for speed
- **SVT-AV1**: Good balance of compression and speed for AV1

## Hardware Acceleration

### VideoToolbox (macOS Only)

Apple's hardware encoder - significantly faster than software encoding:

```bash
# Use VideoToolbox (H.264)
ffmpeg -i input.mp4 -c:v h264_videotoolbox -b:v 5M output.mp4

# Use VideoToolbox (HEVC)
ffmpeg -i input.mp4 -c:v hevc_videotoolbox -b:v 3M output.mp4
```

**Performance:**

| Resolution | Software (libx264) | VideoToolbox | Speedup |
|------------|-------------------|--------------|---------|
| 480p | 180 fps | 450+ fps | 2.5x |
| 720p | 95 fps | 320 fps | 3.4x |
| 1080p | 42 fps | 180 fps | 4.3x |
| 4K | 8 fps | 60 fps | 7.5x |

**Limitations:**
- Quality slightly lower than libx264 at same bitrate
- Limited preset control (use `-b:v` for bitrate)
- macOS-only (darwin-x64, darwin-arm64)

### VA-API (Linux Intel/AMD GPUs)

Linux hardware acceleration for Intel/AMD:

```bash
# Check if VA-API available
vainfo

# Encode with VA-API (H.264)
ffmpeg -vaapi_device /dev/dri/renderD128 -i input.mp4 \
  -vf 'format=nv12,hwupload' \
  -c:v h264_vaapi -b:v 5M output.mp4
```

**Performance:**
- 3-5x faster than software encoding
- Requires `linux-x64-glibc-vaapi` build variant
- Quality comparable to `veryfast` preset

### NVENC (NVIDIA GPUs)

NVIDIA hardware encoder:

```bash
# Encode with NVENC (H.264)
ffmpeg -hwaccel cuda -i input.mp4 \
  -c:v h264_nvenc -preset fast -b:v 5M output.mp4

# Encode with NVENC (HEVC)
ffmpeg -hwaccel cuda -i input.mp4 \
  -c:v hevc_nvenc -preset fast -b:v 3M output.mp4
```

**Performance:**
- 5-10x faster than software encoding
- Requires `linux-x64-glibc-nvenc` build variant
- Quality comparable to `fast` preset

## Optimization Strategies

### 1. Choose the Right Codec

**For Real-Time Streaming:**
```bash
# H.264 ultrafast - highest speed
ffmpeg -i input.mp4 -c:v libx264 -preset ultrafast -tune zerolatency output.mp4
```

**For Offline Transcoding:**
```bash
# H.265 slow - best compression
ffmpeg -i input.mp4 -c:v libx265 -preset slow -crf 23 output.mp4
```

**For Web Video:**
```bash
# VP9 for WebM
ffmpeg -i input.mp4 -c:v libvpx-vp9 -b:v 2M -c:a libopus -b:a 128k output.webm
```

### 2. Use Appropriate Preset

| Preset | When to Use |
|--------|-------------|
| **ultrafast** | Live streaming, real-time encoding |
| **veryfast** | Fast transcoding, live events |
| **medium** | General-purpose, balanced speed/quality |
| **slow** | Archival, high-quality offline encoding |
| **veryslow** | Maximum quality, time not critical |

### 3. Multi-Threading

FFmpeg auto-detects CPU cores, but you can override:

```bash
# Use all cores (default)
ffmpeg -i input.mp4 -c:v libx264 -preset medium output.mp4

# Limit to 4 threads (for concurrent jobs)
ffmpeg -threads 4 -i input.mp4 -c:v libx264 -preset medium output.mp4

# Single-threaded (for debugging)
ffmpeg -threads 1 -i input.mp4 -c:v libx264 -preset medium output.mp4
```

**Threading Efficiency:**

| Threads | Encoding Speed | Efficiency |
|---------|----------------|------------|
| 1 | 12 fps | 100% (baseline) |
| 2 | 22 fps | 92% |
| 4 | 40 fps | 83% |
| 8 | 68 fps | 71% |
| 16 | 95 fps | 49% |

*Diminishing returns after 4-8 threads due to synchronization overhead*

### 4. Resolution Scaling

Downscaling before encoding dramatically improves speed:

| Input Resolution | Output Resolution | Encoding Speed | Use Case |
|-----------------|-------------------|----------------|----------|
| 4K (3840x2160) | 1080p (1920x1080) | 4x faster | Most displays are 1080p |
| 1080p (1920x1080) | 720p (1280x720) | 2.5x faster | Mobile devices, streaming |
| 720p (1280x720) | 480p (854x480) | 1.8x faster | Low-bandwidth scenarios |

```bash
# Downscale to 720p during encoding
ffmpeg -i input-4k.mp4 -vf scale=1280:720 -c:v libx264 -preset fast output-720p.mp4
```

### 5. Two-Pass Encoding

For best quality at target file size (slower, better quality):

```bash
# Pass 1
ffmpeg -i input.mp4 -c:v libx264 -b:v 2M -pass 1 -f null /dev/null

# Pass 2
ffmpeg -i input.mp4 -c:v libx264 -b:v 2M -pass 2 output.mp4
```

**When to use:**
- Targeting specific file size
- Distributing to fixed-bitrate channels
- Maximizing quality at constrained bitrate

**Cost:** 2x encoding time

### 6. Constant Rate Factor (CRF)

Single-pass, perceptual quality target (faster, good quality):

```bash
# CRF 23 (default, balanced)
ffmpeg -i input.mp4 -c:v libx264 -crf 23 output.mp4

# CRF 18 (higher quality, larger file)
ffmpeg -i input.mp4 -c:v libx264 -crf 18 output.mp4

# CRF 28 (lower quality, smaller file)
ffmpeg -i input.mp4 -c:v libx264 -crf 28 output.mp4
```

**CRF Scale:**
- **0**: Lossless (huge files)
- **18**: Visually lossless (very high quality)
- **23**: Default (balanced)
- **28**: Acceptable quality (smaller files)
- **51**: Worst quality (tiny files)

**Recommended ranges:**
- Archival: CRF 18-20
- General: CRF 23-25
- Streaming: CRF 28-30

## Platform-Specific Optimizations

### macOS (darwin-x64, darwin-arm64)

**Apple Silicon (M1/M2/M3/M4) - Best Performance:**

```bash
# Use VideoToolbox for maximum speed
ffmpeg -i input.mp4 -c:v h264_videotoolbox -b:v 5M output.mp4

# Software encoding (libx264) still very fast
ffmpeg -i input.mp4 -c:v libx264 -preset veryfast output.mp4
```

**Optimization tips:**
- Use VideoToolbox for speed (4-7x faster)
- Apple Silicon has excellent software encoding (NEON)
- Universal binaries work on both Intel and ARM

### Linux x64 (linux-x64-glibc, linux-x64-musl)

**High-Performance Servers:**

```bash
# Use hardware acceleration if available
# VA-API (Intel/AMD)
ffmpeg -vaapi_device /dev/dri/renderD128 -i input.mp4 \
  -vf 'format=nv12,hwupload' \
  -c:v h264_vaapi -b:v 5M output.mp4

# NVENC (NVIDIA)
ffmpeg -hwaccel cuda -i input.mp4 \
  -c:v h264_nvenc -preset fast -b:v 5M output.mp4
```

**Optimization tips:**
- Install hardware acceleration variant for GPU encoding
- Use AVX2-optimized builds (all x64 builds include this)
- Consider musl builds for containerized environments

### Linux ARM64 (linux-arm64-glibc, linux-arm64-musl)

**AWS Graviton, Raspberry Pi 4/5:**

```bash
# NEON optimizations enabled by default
# Recommended: 720p max resolution, fast preset
ffmpeg -i input.mp4 \
  -vf scale=1280:720 \
  -c:v libx264 -preset fast \
  output.mp4
```

**Optimization tips:**
- Downscale to 720p for acceptable speed
- Use `fast` or `veryfast` preset
- Leverage multiple cores (Graviton has 64+ cores)
- ARM64 builds include NEON intrinsics (x264, x265, vpx, aom)

### Linux ARMv7 (linux-armv7-glibc)

**Raspberry Pi 2/3, Legacy ARM Devices:**

```bash
# Recommended: 480p max, ultrafast preset
ffmpeg -i input.mp4 \
  -vf scale=854:480 \
  -c:v libx264 -preset ultrafast \
  -threads 4 \
  output.mp4
```

**Optimization tips:**
- **DO NOT** attempt 1080p encoding (< 2 fps)
- Downscale to 480p or 360p
- Use `ultrafast` preset only
- Consider hardware H.264 encoder if available (OMX)
- ARMv7 NEON support is limited vs ARM64

### Windows (windows-x64)

**MinGW Cross-Compiled:**

```bash
# Use same optimizations as Linux x64
ffmpeg.exe -i input.mp4 -c:v libx264 -preset fast output.mp4
```

**Optimization tips:**
- Performance similar to Linux x64
- DXVA2 hardware variant available for GPU decode
- Use Windows native paths (e.g., `C:\path\to\file.mp4`)

## Memory Usage

### Typical Memory Footprint

| Resolution | Threads | Memory Usage | Notes |
|------------|---------|--------------|-------|
| 480p | 4 | 150-250 MB | Low memory |
| 720p | 4 | 300-500 MB | Moderate |
| 1080p | 8 | 600-900 MB | High memory |
| 4K | 16 | 1.5-3 GB | Very high memory |

**Reducing memory usage:**

```bash
# Limit buffer size
ffmpeg -i input.mp4 -max_muxing_queue_size 1024 -c:v libx264 output.mp4

# Single-threaded (lowest memory)
ffmpeg -threads 1 -i input.mp4 -c:v libx264 output.mp4
```

## Benchmarking Your Build

Run performance benchmarks with the test suite:

```bash
# Run all performance tests
./tests/performance-tests.sh

# Results saved to:
tests/results/performance-results.json
```

**Benchmark categories:**

1. **H.264 Preset Comparison** - Speed vs quality trade-offs
2. **Codec Comparison** - H.264 vs H.265 vs VP9 vs AV1
3. **Resolution Scaling** - 480p, 720p, 1080p performance
4. **Threading Efficiency** - Multi-core scaling

**Track performance over time:**

```bash
# Commit benchmark results
git add tests/results/performance-results.json
git commit -m "perf: Benchmark results for darwin-arm64"

# Compare across commits
git diff HEAD~5 tests/results/performance-results.json
```

## Troubleshooting Performance Issues

### Slow Encoding Speed

**Problem:** Encoding much slower than expected

**Solutions:**

1. Check CPU usage: `top` or `htop`
   - If < 100%, ffmpeg not using all cores
   - Add `-threads 0` to use all cores

2. Use faster preset:
   ```bash
   # From slow → medium
   ffmpeg -i input.mp4 -c:v libx264 -preset medium output.mp4
   ```

3. Check for I/O bottleneck:
   - Use SSD instead of HDD
   - Output to different disk than input

4. Verify build optimizations:
   ```bash
   # Check for SIMD optimizations
   ffmpeg -hide_banner -buildconf | grep "enable-asm"
   ```

### High Memory Usage

**Problem:** FFmpeg consuming excessive RAM

**Solutions:**

1. Reduce thread count:
   ```bash
   ffmpeg -threads 4 -i input.mp4 output.mp4
   ```

2. Limit queue size:
   ```bash
   ffmpeg -max_muxing_queue_size 512 -i input.mp4 output.mp4
   ```

3. Process in segments:
   ```bash
   # Split input, process separately
   ffmpeg -i input.mp4 -t 60 -c copy part1.mp4
   ffmpeg -i input.mp4 -ss 60 -c copy part2.mp4
   ```

### CPU Overheating

**Problem:** CPU thermal throttling during encoding

**Solutions:**

1. Use faster preset (less CPU intensive):
   ```bash
   ffmpeg -i input.mp4 -c:v libx264 -preset veryfast output.mp4
   ```

2. Limit threads:
   ```bash
   ffmpeg -threads 4 -i input.mp4 output.mp4
   ```

3. Add cooling, improve ventilation

4. Reduce resolution:
   ```bash
   ffmpeg -i input.mp4 -vf scale=1280:720 output.mp4
   ```

## Best Practices

### 1. Start with Defaults

```bash
# Good starting point for most use cases
ffmpeg -i input.mp4 -c:v libx264 -crf 23 -preset medium output.mp4
```

### 2. Profile Before Optimizing

```bash
# Measure baseline performance
time ffmpeg -i input.mp4 -c:v libx264 -preset medium output.mp4
```

### 3. Use Hardware Acceleration When Available

- macOS: VideoToolbox
- Linux Intel/AMD: VA-API
- Linux NVIDIA: NVENC
- Windows: DXVA2 (decode only in our builds)

### 4. Balance Speed vs Quality

| Priority | Recommended Settings |
|----------|---------------------|
| **Speed** | ultrafast preset, CRF 28, hardware acceleration |
| **Quality** | slow preset, CRF 18, two-pass encoding |
| **Balance** | medium preset, CRF 23, single-pass |

### 5. Monitor Resource Usage

```bash
# CPU usage
htop

# Memory usage
free -h

# Disk I/O
iotop

# GPU usage (NVIDIA)
nvidia-smi
```

## Performance Testing Results

See [tests/results/](tests/results/) for platform-specific benchmark results.

Example results included for:
- darwin-arm64 (M1)
- linux-x64-glibc (Intel Xeon)
- linux-arm64-glibc (AWS Graviton)

## See Also

- [Build Configuration](BUILD-CONFIG.md) - Codec selection
- [Hardware Acceleration](HARDWARE.md) - GPU encoding setup
- [Test Suite](tests/README.md) - Run your own benchmarks
- [Codec Documentation](CODECS.md) - Codec details
