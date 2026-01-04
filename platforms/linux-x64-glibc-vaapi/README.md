# FFmpeg Linux x64 (glibc + VA-API)

Hardware-accelerated FFmpeg build for Intel/AMD GPUs using VA-API.

## Hardware Acceleration

**VA-API (Video Acceleration API)** provides GPU-accelerated encoding and decoding for:

- **Intel GPUs:** HD Graphics, Iris, Iris Xe, Arc
- **AMD GPUs:** Radeon (with open-source AMDGPU drivers)

## Supported Codecs (Hardware)

| Codec | Encode | Decode | Notes |
|-------|--------|--------|-------|
| H.264/AVC | ✅ | ✅ | Most widely supported |
| H.265/HEVC | ✅ | ✅ | Intel Gen 9+ (Skylake+), AMD Raven Ridge+ |
| VP8 | ❌ | ✅ | Decode only on Intel |
| VP9 | ✅ | ✅ | Intel Gen 9+ (Kaby Lake+) |
| AV1 | ✅ | ✅ | Intel Arc/Iris Xe, AMD RDNA2+ |
| MPEG-2 | ✅ | ✅ | Legacy support |
| VC-1 | ❌ | ✅ | Decode only |

## Runtime Requirements

### System Requirements

1. **GPU Driver:**
   ```bash
   # Install Intel VA-API driver
   sudo apt install intel-media-va-driver

   # OR for AMD
   sudo apt install mesa-va-drivers
   ```

2. **Device Access:**
   - Requires `/dev/dri/renderD128` device
   - User must be in `video` or `render` group

3. **Verify VA-API:**
   ```bash
   # Install vainfo tool
   sudo apt install vainfo

   # Check available encoders/decoders
   vainfo
   ```

   Expected output:
   ```
   vainfo: VA-API version: 1.20 (libva 2.20.0)
   vainfo: Driver version: Intel iHD driver - 2.0.0
   VAProfileH264Main              : VAEntrypointVLD
   VAProfileH264Main              : VAEntrypointEncSlice
   VAProfileHEVCMain              : VAEntrypointVLD
   VAProfileHEVCMain              : VAEntrypointEncSlice
   ...
   ```

## Usage Examples

### Hardware-Accelerated H.264 Encoding

```bash
ffmpeg -i input.mp4 \
  -vaapi_device /dev/dri/renderD128 \
  -vf 'format=nv12,hwupload' \
  -c:v h264_vaapi \
  -b:v 5M \
  output.mp4
```

### Hardware-Accelerated H.265 Encoding

```bash
ffmpeg -i input.mp4 \
  -vaapi_device /dev/dri/renderD128 \
  -vf 'format=nv12,hwupload' \
  -c:v hevc_vaapi \
  -b:v 3M \
  output.mp4
```

### Hardware Decoding + Software Encoding

```bash
ffmpeg -hwaccel vaapi \
  -hwaccel_device /dev/dri/renderD128 \
  -i input.mp4 \
  -c:v libx264 \
  output.mp4
```

## Docker Build

```bash
# From project root
docker buildx build \
  --platform linux/amd64 \
  -f platforms/linux-x64-glibc-vaapi/Dockerfile \
  -t ffmpeg-builder:linux-x64-glibc-vaapi \
  .
```

## Performance Comparison

| Operation | Software (libx264) | Hardware (VA-API) | Speedup |
|-----------|-------------------|-------------------|---------|
| 1080p H.264 encode | 60 fps | 300-500 fps | 5-8x |
| 4K H.265 encode | 15 fps | 80-120 fps | 5-8x |
| 1080p transcode | 45 fps | 250-400 fps | 5-9x |

*Benchmarks on Intel i5-11400 (UHD Graphics 730)*

## Limitations

### Quality Trade-offs

- Hardware encoders prioritize speed over quality
- Lower quality per bitrate compared to software (x264/x265)
- Limited tuning options (no CRF, fewer presets)

### When to Use Software Encoding

Use software encoding (libx264, libx265) when:
- Archival quality needed (low bitrate, high quality)
- Advanced features required (HDR10+, Dolby Vision)
- Encoding offline (time not critical)

Use hardware encoding (VA-API) when:
- Real-time encoding required (streaming, live video)
- High throughput needed (batch transcoding)
- Power efficiency important (laptops, edge devices)

## Troubleshooting

### "No VA display found"

```bash
# Check device exists
ls -la /dev/dri/renderD*

# Check permissions
groups  # Should include 'video' or 'render'

# Add user to group
sudo usermod -aG render $USER
# Then logout/login
```

### "Failed to initialize VAAPI"

```bash
# Verify VA-API drivers installed
dpkg -l | grep va-driver

# Install Intel drivers
sudo apt install intel-media-va-driver

# OR install AMD drivers
sudo apt install mesa-va-drivers

# Restart and verify
vainfo
```

### "Encoder not found: h264_vaapi"

```bash
# Check FFmpeg VA-API support
ffmpeg -hide_banner -encoders | grep vaapi

# Should show:
# V..... h264_vaapi    H.264/AVC (VAAPI)
# V..... hevc_vaapi    H.265/HEVC (VAAPI)
```

## Build Time

**Estimated:** 30-40 minutes (similar to base build)

## See Also

- [VDPAU variant](../linux-x64-glibc-vdpau/) - NVIDIA GPU acceleration
- [NVENC variant](../linux-x64-glibc-nvenc/) - NVIDIA dedicated encoders
- [VA-API Documentation](https://01.org/linuxmedia/vaapi)
