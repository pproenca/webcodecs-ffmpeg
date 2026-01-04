# FFmpeg Linux x64 (glibc + NVENC)

Hardware-accelerated FFmpeg build for NVIDIA GPUs using NVENC/NVDEC.

## Hardware Acceleration

**NVENC (NVIDIA Video Encoder)** and **NVDEC (NVIDIA Video Decoder)** provide dedicated GPU hardware for video encoding and decoding, offering significantly better performance than VA-API.

## Supported Hardware

- **NVIDIA GeForce** 600 series (Kepler) and newer
- **NVIDIA Quadro** K-series and newer
- **NVIDIA Tesla** K-series and newer
- **NVIDIA RTX** series (best performance)

## Supported Codecs (Hardware)

| Codec | Encode | Decode | Notes |
|-------|--------|--------|-------|
| H.264/AVC | ✅ | ✅ | All NVENC GPUs |
| H.265/HEVC | ✅ | ✅ | Maxwell (GTX 900) and newer |
| AV1 | ✅ | ✅ | RTX 40 series (Ada Lovelace) only |
| VP8 | ❌ | ✅ | Decode only |
| VP9 | ✅ | ✅ | Pascal (GTX 10) and newer |
| MPEG-2 | ✅ | ✅ | All NVENC GPUs |
| MPEG-4 | ❌ | ✅ | Decode only |

## Runtime Requirements

### System Requirements

1. **NVIDIA Proprietary Drivers:**
   ```bash
   # Ubuntu/Debian
   sudo apt install nvidia-driver-535  # or latest version

   # Verify installation
   nvidia-smi
   ```

2. **Device Access:**
   - Requires `/dev/nvidia*` devices
   - Driver must be loaded and functional

3. **Verify NVENC Availability:**
   ```bash
   # Check GPU and driver version
   nvidia-smi

   # Expected output:
   # +-----------------------------------------------------------------------------+
   # | NVIDIA-SMI 535.129.03   Driver Version: 535.129.03   CUDA Version: 12.2   |
   # +-------------------------------+----------------------+----------------------+
   # | GPU  Name        Persistence-M| Bus-Id        Disp.A | Volatile Uncorr. ECC |
   # ...
   ```

## Usage Examples

### Hardware-Accelerated H.264 Encoding

```bash
ffmpeg -i input.mp4 \
  -c:v h264_nvenc \
  -preset fast \
  -b:v 5M \
  output.mp4
```

### Hardware-Accelerated H.265 Encoding

```bash
ffmpeg -i input.mp4 \
  -c:v hevc_nvenc \
  -preset medium \
  -b:v 3M \
  output.mp4
```

### Hardware Decoding + NVENC Encoding (Full GPU Pipeline)

```bash
ffmpeg -hwaccel cuda \
  -hwaccel_output_format cuda \
  -i input.mp4 \
  -c:v h264_nvenc \
  -preset fast \
  output.mp4
```

### Quality Presets

NVENC supports presets similar to x264:

| Preset | Speed | Quality | Use Case |
|--------|-------|---------|----------|
| `fast` | Fastest | Lower | Real-time streaming |
| `medium` | Balanced | Good | General purpose |
| `slow` | Slower | Better | High quality needed |
| `lossless` | Slowest | Perfect | Archival (huge files) |

## Docker Build

```bash
# From project root
docker buildx build \
  --platform linux/amd64 \
  -f platforms/linux-x64-glibc-nvenc/Dockerfile \
  -t ffmpeg-builder:linux-x64-glibc-nvenc \
  .
```

## Performance Comparison

| Operation | Software (libx264) | NVENC (GTX 1060) | Speedup |
|-----------|-------------------|------------------|---------|
| 1080p H.264 encode | 60 fps | 500-700 fps | 8-12x |
| 4K H.265 encode | 15 fps | 180-240 fps | 12-16x |
| 1080p transcode | 45 fps | 600-800 fps | 13-18x |

*Benchmarks on NVIDIA GTX 1060 6GB*

**RTX 40 series** (Ada Lovelace) performance is even better:
- 1080p H.264: 1000+ fps
- 4K H.265: 400+ fps
- AV1 encode: 200+ fps (hardware AV1 encoder)

## Quality Considerations

### NVENC vs Software (x264/x265)

| Aspect | Software (libx264) | Hardware (NVENC) |
|--------|-------------------|------------------|
| **Speed** | 1x (baseline) | 10-15x faster |
| **Quality/Bitrate** | Excellent | Good (improving with newer GPUs) |
| **Features** | Full (CRF, tunes) | Limited presets |
| **Power** | High CPU usage | Low CPU, uses GPU |

### When to Use NVENC

**Use NVENC when:**
- ✅ Real-time encoding (streaming, live video)
- ✅ High throughput transcoding (batch jobs)
- ✅ You have an NVIDIA GPU (RTX 20 series or newer recommended)
- ✅ Acceptable quality at higher bitrates

**Use Software (libx264) when:**
- ✅ Maximum quality at low bitrates
- ✅ Archival/preservation
- ✅ No NVIDIA GPU available
- ✅ CPU idle and encoding can run overnight

### NVENC Generation Comparison

| Generation | Example GPUs | Quality | Features |
|------------|--------------|---------|----------|
| **Kepler** (2012) | GTX 600/700 | Poor | Basic H.264 |
| **Maxwell** (2014) | GTX 900 | Fair | HEVC added |
| **Pascal** (2016) | GTX 10 | Good | VP9, better quality |
| **Turing** (2018) | RTX 20 | Very Good | Improved quality, B-frames |
| **Ampere** (2020) | RTX 30 | Excellent | Near x264 medium quality |
| **Ada** (2022) | RTX 40 | Excellent | AV1 encode, even better quality |

**Recommendation:** RTX 20 series or newer for production use. Older generations acceptable for streaming but not archival.

## Troubleshooting

### \"Cannot load libcuda.so.1\"

```bash
# Check NVIDIA driver installed
nvidia-smi

# If not installed:
sudo apt install nvidia-driver-535

# Reboot required after driver install
sudo reboot
```

### \"No NVENC capable devices found\"

```bash
# Verify GPU supports NVENC
nvidia-smi -q | grep "Encoder"

# Expected: "Encoder 0" or similar
# If empty, your GPU doesn't support NVENC
```

### \"Encoder not found: h264_nvenc\"

```bash
# Check FFmpeg NVENC support
ffmpeg -hide_banner -encoders | grep nvenc

# Should show:
# V..... h264_nvenc    NVIDIA NVENC H.264 encoder
# V..... hevc_nvenc    NVIDIA NVENC HEVC encoder
```

### Poor Quality Output

NVENC quality improves with:
1. **Newer GPU architecture** (RTX 30/40 much better than GTX 10)
2. **Higher bitrate** (NVENC needs more bits than x264 for same quality)
3. **Slower preset** (use `-preset slow` instead of `-preset fast`)
4. **Two-pass encoding** (add `-b:v 5M -maxrate 6M -bufsize 12M`)

Example for better quality:
```bash
ffmpeg -i input.mp4 \
  -c:v h264_nvenc \
  -preset slow \
  -rc vbr \
  -cq 23 \
  -b:v 0 \
  -maxrate 10M \
  -bufsize 20M \
  output.mp4
```

## Build Time

**Estimated:** 35-45 minutes (includes nv-codec-headers + base build)

## See Also

- [VA-API variant](../linux-x64-glibc-vaapi/) - Intel/AMD GPU acceleration
- [VDPAU variant](../linux-x64-glibc-vdpau/) - NVIDIA legacy (decode-only focus)
- [NVIDIA NVENC Documentation](https://developer.nvidia.com/nvidia-video-codec-sdk)
- [FFmpeg NVENC Guide](https://trac.ffmpeg.org/wiki/HWAccelIntro#NVENC)
