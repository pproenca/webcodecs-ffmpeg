# FFmpeg Windows x64 (DXVA2)

Hardware-accelerated FFmpeg build for Windows using DXVA2 (DirectX Video Acceleration).

## Hardware Acceleration

**DXVA2 (DirectX Video Acceleration 2)** provides GPU-accelerated video decoding on Windows. Available on all Windows systems with DirectX 9.0c or later.

## Supported Hardware

- **All Windows GPUs** with DirectX 9.0c+ support
- **Intel integrated GPUs** (HD Graphics, Iris, Iris Xe, Arc)
- **AMD GPUs** (Radeon series)
- **NVIDIA GPUs** (GeForce, Quadro, Tesla)

## Supported Codecs (Hardware Decode)

| Codec | Decode | Encode | Notes |
|-------|--------|--------|-------|
| H.264/AVC | ✅ | ❌ | Most GPUs |
| H.265/HEVC | ✅ | ❌ | Intel Skylake+, AMD Polaris+, NVIDIA Maxwell+ |
| VP8 | ✅ | ❌ | Limited GPU support |
| VP9 | ✅ | ❌ | Intel Kaby Lake+, AMD Raven Ridge+ |
| MPEG-2 | ✅ | ❌ | All GPUs |
| VC-1 | ✅ | ❌ | Most GPUs |

**Note:** DXVA2 is primarily for **hardware decoding**. For hardware encoding on Windows:
- Intel GPUs: Use QuickSync Video (QSV) - requires libmfx
- NVIDIA GPUs: Use NVENC (separate variant)
- AMD GPUs: Use AMF (not currently supported)

## Runtime Requirements

### System Requirements

1. **Windows 7 or later** (DXVA2 built-in)
2. **DirectX 9.0c or later**
3. **GPU drivers installed**

No additional runtime dependencies - DXVA2 is built into Windows.

### Verify DXVA2 Availability

```powershell
# Check DirectX version
dxdiag

# Should show DirectX 11 or 12 on modern systems
```

## Usage Examples

### Hardware-Accelerated Decoding

```bash
# Basic hardware decode
ffmpeg -hwaccel dxva2 \
  -i input.mp4 \
  -c:v libx264 \
  output.mp4
```

### Decode with DXVA2, Encode with Software

```bash
# Fast transcoding using GPU decode + CPU encode
ffmpeg -hwaccel dxva2 \
  -i input.mp4 \
  -c:v libx265 \
  -preset medium \
  -crf 23 \
  output.mp4
```

### Extract Frames (GPU-Accelerated)

```bash
# Extract frames using GPU decoding
ffmpeg -hwaccel dxva2 \
  -i video.mp4 \
  -vf "fps=1" \
  frame_%04d.png
```

## Docker Build (Cross-Compilation)

This variant is built using MinGW-w64 cross-compilation from Linux:

```bash
# From project root
docker buildx build \
  --platform linux/amd64 \
  -f platforms/windows-x64-dxva2/Dockerfile \
  -t ffmpeg-builder:windows-x64-dxva2 \
  .
```

**Note:** The build runs on Linux but produces Windows `.exe` binaries.

## Performance Comparison

| Operation | Software Decode | DXVA2 Decode | CPU Savings |
|-----------|----------------|--------------|-------------|
| 1080p H.264 decode | 100% CPU | 10-15% CPU | ~85% |
| 4K H.265 decode | 100% CPU | 15-20% CPU | ~80% |
| Multi-stream decode | Overload | Handles 4-6 streams | Massive |

**Main Benefit:** DXVA2 frees up CPU for other tasks (encoding, filtering, etc.)

## Limitations

### Decode-Only

DXVA2 **only provides hardware decoding**, not encoding. For hardware encoding:

| Use Case | Recommendation |
|----------|----------------|
| Intel GPU encoding | Build with QuickSync (libmfx) - future enhancement |
| NVIDIA GPU encoding | Use separate NVENC variant (not yet available for Windows) |
| AMD GPU encoding | Use AMF (not currently supported) |

### Quality

Hardware decoding is **bit-exact** - same quality as software decode, just faster and more power-efficient.

## Troubleshooting

### \"Failed to initialize DXVA2\"

```powershell
# Update GPU drivers
# Intel: Download from intel.com/content/www/us/en/download-center
# NVIDIA: Download from nvidia.com/drivers
# AMD: Download from amd.com/support

# Check DirectX version
dxdiag
# Should show DirectX 11 or 12
```

### \"hwaccel not found: dxva2\"

```bash
# Check FFmpeg DXVA2 support
ffmpeg -hide_banner -hwaccels

# Should show:
# Hardware acceleration methods:
# dxva2
```

### Poor Performance

If DXVA2 decoding is slower than software:
1. **Update GPU drivers** - old drivers have poor DXVA2 performance
2. **Check CPU usage** - DXVA2 should reduce CPU usage significantly
3. **Try different video** - some files may not benefit from DXVA2
4. **Compare bitrates** - DXVA2 helps most with high-bitrate 4K video

## When to Use DXVA2

**Use DXVA2 when:**
- ✅ Transcoding video (decode with GPU, encode with CPU)
- ✅ Playing high-bitrate 4K video
- ✅ Processing multiple video streams simultaneously
- ✅ CPU-constrained system

**Skip DXVA2 when:**
- ❌ Already encoding with hardware (no need to decode with hardware too)
- ❌ Simple frame extraction (software fast enough)
- ❌ Very old GPU (pre-2010) - software might be faster

## Build Time

**Estimated:** 25-35 minutes (cross-compilation from Linux)

## See Also

- [Base Windows variant](../windows-x64/) - Software-only (no hardware accel)
- [QuickSync Guide](https://trac.ffmpeg.org/wiki/Hardware/QuickSync) - Intel hardware encoding
- [DXVA2 Documentation](https://docs.microsoft.com/en-us/windows/win32/medfound/directx-video-acceleration-2-0)
- [FFmpeg Windows Build Guide](https://trac.ffmpeg.org/wiki/CompilationGuide/CrossCompilingForWindows)

## Future Enhancements

Potential additions to this variant:

1. **Intel QuickSync (QSV)**
   - Requires building libmfx (Intel Media SDK)
   - Provides hardware encoding on Intel GPUs
   - Adds: `--enable-libmfx`

2. **NVIDIA NVENC** (Windows)
   - Requires NVIDIA codec headers
   - Best hardware encoder for NVIDIA GPUs
   - Separate variant recommended

3. **AMD AMF**
   - AMD's hardware encoder
   - Requires AMF SDK
   - Not currently supported in FFmpeg's configure
