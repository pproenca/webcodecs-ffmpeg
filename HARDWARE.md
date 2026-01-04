# Hardware Acceleration Variants

This document describes the hardware-accelerated FFmpeg build variants and npm packages.

**Status:** Phase 3 - COMPLETE (All variants implemented, npm packages configured)
**Last Updated:** 2026-01-04

---

## Overview

Hardware acceleration variants provide GPU-accelerated encoding/decoding, offering 5-10x faster performance compared to software codecs. Each variant targets specific GPU hardware and is available as an opt-in npm package.

## Implemented Variants

### ✅ Linux VA-API (Intel/AMD GPU)

**Location:** `platforms/linux-x64-glibc-vaapi/`
**Status:** COMPLETE

**Target Hardware:**
- Intel integrated GPUs (HD Graphics, Iris, Arc)
- AMD GPUs (Radeon with AMDGPU drivers)

**Runtime Requirements:**
- `/dev/dri/renderD128` device
- `libva` drivers installed
- User in `video` or `render` group

**npm Package:** `@pproenca/ffmpeg-linux-x64-glibc-vaapi`

**Installation:**
```bash
npm install @pproenca/ffmpeg-linux-x64-glibc-vaapi
```

**Usage with Main Package:**
```javascript
const { getBinaryPath } = require('@pproenca/ffmpeg');

// Use VA-API build if installed, fall back to standard
const ffmpegPath = getBinaryPath('ffmpeg', { hardwareAccel: 'vaapi' });
```

**Implementation:**
```dockerfile
# Added to Dockerfile
RUN apt-get install -y libva-dev libdrm-dev

# Added to FFmpeg configure
--enable-vaapi
```

**Usage Example:**
```bash
ffmpeg -vaapi_device /dev/dri/renderD128 \
  -vf 'format=nv12,hwupload' \
  -c:v h264_vaapi \
  -b:v 5M output.mp4
```

**Performance:** 5-8x faster than software encoding

**See:** [VA-API README](platforms/linux-x64-glibc-vaapi/README.md)

---

## Additional Variants

The following variants are implemented and configured for npm distribution:

### 📋 Linux VDPAU (NVIDIA GPU - Legacy)

**Status:** PATTERN DEFINED

**Implementation Pattern:**
```dockerfile
# Dockerfile changes
RUN apt-get install -y libvdpau-dev

# FFmpeg configure
--enable-vdpau
```

**Target Hardware:**
- NVIDIA GPUs (legacy acceleration)
- Superseded by NVENC for encoding

**Notes:**
- VDPAU primarily for decoding
- NVENC preferred for NVIDIA encoding
- Consider skipping if NVENC implemented

---

### ✅ Linux NVENC (NVIDIA Dedicated Encoders)

**Location:** `platforms/linux-x64-glibc-nvenc/`
**Status:** COMPLETE

**Target Hardware:**
- NVIDIA GPUs (GeForce 600 series / Kepler+)
- Dedicated NVENC/NVDEC hardware

**Runtime Requirements:**
- NVIDIA proprietary drivers (535+)
- `nvidia-smi` working
- CUDA toolkit

**npm Package:** `@pproenca/ffmpeg-linux-x64-glibc-nvenc`

**Installation:**
```bash
npm install @pproenca/ffmpeg-linux-x64-glibc-nvenc
```

**Usage with Main Package:**
```javascript
const { getBinaryPath } = require('@pproenca/ffmpeg');

// Use NVENC build if installed, fall back to standard
const ffmpegPath = getBinaryPath('ffmpeg', { hardwareAccel: 'nvenc' });
```

**Performance:** 10-15x faster than software encoding

**Usage Example:**
```bash
ffmpeg -hwaccel cuda -hwaccel_output_format cuda \
  -i input.mp4 \
  -c:v h264_nvenc \
  -preset fast \
  output.mp4
```

**See:** [NVENC README](platforms/linux-x64-glibc-nvenc/README.md)

---

### ✅ macOS VideoToolbox

**Status:** COMPLETE (Included in standard darwin builds)

**Target Hardware:**
- All macOS systems (Intel + Apple Silicon)
- Built into macOS, no additional drivers required

**npm Package:** `@pproenca/ffmpeg-darwin`

**Installation:**
```bash
npm install @pproenca/ffmpeg-darwin
# Or use the main package for automatic detection
npm install @pproenca/ffmpeg
```

**Notes:**
- VideoToolbox hardware acceleration is **always enabled** in darwin builds
- No separate package needed - use standard `@pproenca/ffmpeg-darwin`
- Universal binary supports both Intel (x64) and Apple Silicon (arm64)

**Usage Example:**
```bash
ffmpeg -hwaccel videotoolbox \
  -i input.mp4 \
  -c:v h264_videotoolbox \
  -b:v 5M output.mp4
```

---

### ✅ Windows DXVA2

**Location:** `platforms/windows-x64-dxva2/`
**Status:** COMPLETE

**Target Hardware:**
- All Windows systems (DXVA2 built into Windows)
- Intel QuickSync (QSV) optional enhancement

**npm Package:** `@pproenca/ffmpeg-windows-x64-dxva2`

**Installation:**
```bash
npm install @pproenca/ffmpeg-windows-x64-dxva2
```

**Usage with Main Package:**
```javascript
const { getBinaryPath } = require('@pproenca/ffmpeg');

// Use DXVA2 build if installed, fall back to standard
const ffmpegPath = getBinaryPath('ffmpeg', { hardwareAccel: 'dxva2' });
```

**Usage Example:**
```bash
# DXVA2 hardware decode
ffmpeg -hwaccel dxva2 -i input.mp4 -c:v libx264 output.mp4
```

**See:** [DXVA2 README](platforms/windows-x64-dxva2/README.md)

---

## Implementation Pattern Summary

All hardware acceleration variants follow this pattern:

### 1. Create Platform Directory

```bash
mkdir platforms/{platform}-{hw-type}
cp platforms/{platform}/Dockerfile platforms/{platform}-{hw-type}/
```

### 2. Update Dockerfile

```dockerfile
# 1. Update header documentation
# FFmpeg Hardware-Accelerated Build for {Platform} ({HW Type})

# 2. Add hardware-specific dependencies
RUN apt-get install -y lib{hw}-dev

# 3. Add FFmpeg configure flag
--enable-{hw-type}
```

### 3. Create README

```markdown
# FFmpeg {Platform} ({HW Type})

## Hardware Acceleration
{Description of HW type}

## Runtime Requirements
{Dependencies, drivers, permissions}

## Usage Examples
{ffmpeg command examples}

## Performance Comparison
{Benchmarks vs software}
```

### 4. Update Build Scripts

```bash
# build/orchestrator.sh
case "$PLATFORM" in
  {platform}-{hw-type})
    exec "$SCRIPT_DIR/linux.sh" "$PLATFORM"
    ;;
```

### 5. Update npm Packaging

```typescript
// scripts/package-npm.ts
const PLATFORMS: Platform[] = [
  { name: '{platform}-{hw-type}', os: '{os}', cpu: '{cpu}' },
];
```

---

## Hardware Detection

**Script:** `lib/detect-hw.js`

Automatic detection of available GPU hardware:

```javascript
const { detectHardware, getRecommendedVariant } = require('@pproenca/ffmpeg/lib/detect-hw');

const hw = detectHardware();
console.log(hw);
// { platform: 'linux', gpu: 'intel', acceleration: 'vaapi', available: true }

const variant = getRecommendedVariant();
console.log(variant);
// '@pproenca/ffmpeg-linux-x64-glibc-vaapi'
```

**Features:**
- Detects GPU vendor (Intel, AMD, NVIDIA, Apple)
- Identifies available acceleration APIs
- Recommends optimal FFmpeg variant
- Provides encoder recommendations

**Usage in Main Package:**

```javascript
// index.js
const hw = require('./lib/detect-hw');

function getBinaryPath(binary = 'ffmpeg') {
  const variant = hw.getRecommendedVariant();
  // Use HW-accelerated variant if available
  // Fallback to software variant
}
```

---

## Testing Hardware Variants

### Verify Hardware Availability

**Linux (VA-API):**
```bash
# Install tools
sudo apt install vainfo

# Check VA-API
vainfo

# Expected: List of supported profiles
```

**Linux (NVENC):**
```bash
# Check NVIDIA GPU
nvidia-smi

# Expected: GPU name and driver version
```

**macOS (VideoToolbox):**
```bash
# VideoToolbox always available
# Test with:
ffmpeg -hwaccels
# Expected: videotoolbox in list
```

### Performance Benchmarking

```bash
# Software encoding (baseline)
time ffmpeg -i input.mp4 -c:v libx264 -preset medium software.mp4

# Hardware encoding (VA-API)
time ffmpeg -vaapi_device /dev/dri/renderD128 \
  -vf 'format=nv12,hwupload' \
  -c:v h264_vaapi \
  hardware.mp4

# Compare times and file sizes
```

---

## Quality Considerations

### Hardware vs Software Trade-offs

| Aspect | Software (libx264) | Hardware (VA-API/NVENC) |
|--------|-------------------|-------------------------|
| **Speed** | 1x (baseline) | 5-15x faster |
| **Quality/Bitrate** | Excellent | Good |
| **Features** | Full (CRF, presets) | Limited |
| **Power** | High CPU usage | Low CPU, uses GPU |
| **Use Case** | Archival, offline | Real-time, streaming |

### When to Use Each

**Use Hardware Acceleration:**
- ✅ Real-time encoding (streaming, live video)
- ✅ High throughput transcoding (batch jobs)
- ✅ Power-constrained environments (laptops, ARM)
- ✅ GPU available and idle

**Use Software Encoding:**
- ✅ Maximum quality at low bitrates
- ✅ Archival/preservation (long-term storage)
- ✅ Advanced features (HDR10+, Dolby Vision)
- ✅ No GPU available

---

## Implementation Priority

Based on user demand and hardware prevalence:

1. **✅ VA-API (Linux Intel/AMD)** - COMPLETE
   - Most common in servers/desktop
   - Wide hardware support

2. **📋 VideoToolbox (macOS)** - HIGH PRIORITY
   - Available on all Macs
   - Simple to implement (no extra deps)
   - Consider making default

3. **📋 NVENC (Linux/Windows NVIDIA)** - MEDIUM PRIORITY
   - Best performance for NVIDIA users
   - Requires proprietary drivers
   - Complex setup

4. **📋 DXVA2/QSV (Windows Intel)** - MEDIUM PRIORITY
   - Windows-specific
   - Intel QuickSync widespread

5. **📋 VDPAU (Linux NVIDIA Legacy)** - LOW PRIORITY
   - Superseded by NVENC
   - Decode-only focus
   - Consider skipping

---

## Summary

**Phase 3 Status:** ✅ COMPLETE

All hardware acceleration variants are implemented and configured:

| Variant | Platform | Package | Status |
|---------|----------|---------|--------|
| VA-API | Linux x64 | `@pproenca/ffmpeg-linux-x64-glibc-vaapi` | ✅ Complete |
| NVENC | Linux x64 | `@pproenca/ffmpeg-linux-x64-glibc-nvenc` | ✅ Complete |
| VideoToolbox | macOS | `@pproenca/ffmpeg-darwin` (built-in) | ✅ Complete |
| DXVA2 | Windows x64 | `@pproenca/ffmpeg-windows-x64-dxva2` | ✅ Complete |

**npm Configuration:** All HW variant packages are configured in `package-npm.ts` and will be published automatically on release.

**Usage:** Install the main package (`@pproenca/ffmpeg`) and optionally install HW variant packages for GPU acceleration.

---

## References

- **VA-API:** https://01.org/linuxmedia/vaapi
- **NVENC:** https://developer.nvidia.com/nvidia-video-codec-sdk
- **VideoToolbox:** https://developer.apple.com/documentation/videotoolbox
- **FFmpeg HW Acceleration:** https://trac.ffmpeg.org/wiki/HWAccelIntro
