# Build Configuration System

The FFmpeg prebuilds repository supports customizable builds through JSON configuration files. This allows you to enable/disable specific codecs, features, and optimizations to create builds tailored to your needs.

## Quick Start

### Using Presets

Three preset configurations are provided:

```bash
# Minimal build (H.264/H.265 + Opus/MP3, ~35MB)
export BUILD_CONFIG=presets/minimal.json
./build/orchestrator.sh linux-x64-glibc

# Streaming build (Modern web codecs + network, ~55MB)
export BUILD_CONFIG=presets/streaming.json
./build/orchestrator.sh darwin-arm64

# Full build (All codecs, ~80MB, default)
export BUILD_CONFIG=presets/full.json
./build/orchestrator.sh windows-x64
```

### Custom Configuration

1. **Copy a preset as starting point:**
   ```bash
   cp presets/streaming.json my-custom-build.json
   ```

2. **Edit the configuration:**
   ```bash
   # Disable a codec
   jq '.codecs.video.av1.enabled = false' my-custom-build.json > tmp.json && mv tmp.json my-custom-build.json

   # Enable a feature
   jq '.features.network.enabled = true' my-custom-build.json > tmp.json && mv tmp.json my-custom-build.json
   ```

3. **Build with your config:**
   ```bash
   export BUILD_CONFIG=my-custom-build.json
   ./build/orchestrator.sh linux-x64-glibc
   ```

## Configuration Structure

The build configuration JSON has five main sections:

### 1. Codecs

Control which video and audio codecs are compiled into FFmpeg.

**Video Codecs:**
- `h264` - H.264/AVC (libx264, GPL, most compatible)
- `h265` - H.265/HEVC (libx265, GPL, better compression)
- `vp8` / `vp9` - WebM codecs (libvpx, BSD)
- `av1` - AV1 reference encoder (libaom, BSD, slow but highest quality)
- `svt-av1` - Intel's AV1 encoder (BSD, faster than libaom)
- `rav1e` - Rust AV1 encoder (BSD, requires Cargo toolchain)
- `theora` - Legacy Ogg video (BSD)
- `xvid` - MPEG-4 ASP (GPL)

**Audio Codecs:**
- `opus` - Best quality/bitrate (BSD, recommended)
- `mp3` - Universal compatibility (libmp3lame, LGPL)
- `aac` - Native FFmpeg AAC encoder (LGPL, built-in)
- `fdk-aac` - High-quality AAC (Non-free, better than native)
- `flac` - Lossless audio (BSD)
- `speex` - Speech codec (BSD)
- `vorbis` - Ogg audio (BSD)

**Example:**
```json
{
  "codecs": {
    "video": {
      "h264": {"enabled": true},
      "h265": {"enabled": true},
      "av1": {"enabled": false}
    },
    "audio": {
      "opus": {"enabled": true},
      "mp3": {"enabled": false}
    }
  }
}
```

### 2. Features

Enable/disable FFmpeg features beyond codecs.

- `subtitle_rendering` - Subtitle rendering with libass/freetype (~2MB overhead)
- `network` - Network protocols (HTTP, HTTPS, RTMP for streaming)
- `hwaccel` - Hardware acceleration (use dedicated HW variants instead)

**Example:**
```json
{
  "features": {
    "subtitle_rendering": {"enabled": true},
    "network": {"enabled": true},
    "hwaccel": {"enabled": false}
  }
}
```

### 3. Optimization

Choose optimization strategy.

- `size` - Optimize for smallest binary (`--enable-small`, ~15-20% smaller)
- `speed` - Optimize for execution speed (default, best performance)
- `lto` - Link-Time Optimization (+10-15 min build, +5-10% performance)

**Example:**
```json
{
  "optimization": {
    "size": {"enabled": false},
    "speed": {"enabled": true},
    "lto": {"enabled": false}
  }
}
```

### 4. Build

Control build-time options.

- `static_linking` - Static binaries (required for npm, do not disable)
- `debug_symbols` - Include debug symbols (5-10x larger binary)
- `documentation` - Build FFmpeg docs (not included in npm packages)

**Example:**
```json
{
  "build": {
    "static_linking": {"enabled": true},
    "debug_symbols": {"enabled": false},
    "documentation": {"enabled": false}
  }
}
```

### 5. License

Configure licensing implications.

- `gpl` - Enable GPL components (x264, x265, xvid) - makes build GPL
- `version3` - Enable GPL-3.0/LGPL-3.0 licenses
- `nonfree` - Enable non-free components (fdk-aac)

**Example:**
```json
{
  "license": {
    "gpl": {"enabled": true},
    "version3": {"enabled": true},
    "nonfree": {"enabled": false}
  }
}
```

## Preset Comparison

| Preset | Video Codecs | Audio Codecs | Features | Size | Build Time | Use Case |
|--------|-------------|--------------|----------|------|------------|----------|
| **minimal** | H.264, H.265 | Opus, MP3, AAC | None | ~35MB | 12-18 min | Simple transcoding |
| **streaming** | H.264, H.265, VP9, AV1, SVT-AV1 | Opus, AAC, fdk-aac, Vorbis | Network, Subtitles | ~55MB | 20-28 min | Live streaming, WebRTC |
| **full** | All codecs | All codecs | All features | ~80MB | 25-35 min | General-purpose |

## License Implications

**Your build's license depends on enabled components:**

| Configuration | Resulting License | Can Distribute? |
|---------------|------------------|----------------|
| No GPL codecs (disable x264, x265, xvid) | LGPL-2.1+ | ✅ Yes, even commercially |
| GPL codecs enabled | GPL-2.0+ | ✅ Yes, but derivative works must be GPL |
| GPL + non-free (fdk-aac) | GPL + Non-free | ⚠️ Check distribution restrictions |

**To create an LGPL-only build:**
```json
{
  "codecs": {
    "video": {
      "h264": {"enabled": false},   // GPL
      "h265": {"enabled": false},   // GPL
      "xvid": {"enabled": false},   // GPL
      "vp8": {"enabled": true},     // BSD - OK
      "vp9": {"enabled": true},     // BSD - OK
      "av1": {"enabled": true}      // BSD - OK
    }
  },
  "license": {
    "gpl": {"enabled": false},
    "nonfree": {"enabled": false}
  }
}
```

## Advanced Usage

### Environment Variable Overrides

Individual codecs can be toggled via environment variables (highest priority):

```bash
# Disable a codec even if config enables it
export ENABLE_H264=false
export ENABLE_FDKAAC=false

# Enable a codec even if config disables it
export ENABLE_VP9=true

./build/orchestrator.sh linux-x64-glibc
```

### Validating Configuration

Check your configuration is valid:

```bash
# Validate JSON syntax
jq empty build-config.json

# List enabled codecs
jq -r '.codecs.video | to_entries[] | select(.value.enabled == true) | .key' build-config.json

# Calculate estimated binary size
jq -r '.metadata.binary_size_estimate' build-config.json
```

### Generating FFmpeg Configure Flags

The `build/parse-config.sh` script parses a build configuration and generates the appropriate FFmpeg configure flags:

```bash
# Parse default config
./build/parse-config.sh
# Output: --enable-gpl --enable-version3 --enable-nonfree ...

# Parse minimal preset
./build/parse-config.sh presets/minimal.json
# Output: --enable-gpl --enable-version3 --enable-libx264 --enable-libx265 ...

# Parse custom config
./build/parse-config.sh my-custom-build.json
```

**Usage in custom build scripts:**

```bash
# Get configure flags
FFMPEG_FLAGS=$(./build/parse-config.sh presets/streaming.json)

# Pass to FFmpeg configure
cd ffmpeg && ./configure \
  --prefix=/build \
  $FFMPEG_FLAGS \
  --extra-cflags="-I/build/include" \
  --extra-ldflags="-L/build/lib"
```

**The script outputs:**
- Detailed summary to stderr (colorized, human-readable)
- Configure flags to stdout (for script consumption)

### Build Time Optimization

**Disable slow codecs to speed up builds:**

- `av1` (libaom) - Very slow to build (~8-10 minutes)
- `rav1e` - Requires Rust toolchain (~15-20 minutes first build)
- `svt-av1` - Moderate build time (~5-7 minutes)
- `x265` - Slow to build (~6-8 minutes)

**Minimal preset removes these, reducing build time from 25-35 min to 12-18 min.**

## Examples

### Example 1: Audio-Only Build

For audio processing applications:

```json
{
  "codecs": {
    "video": {
      "h264": {"enabled": false},
      "h265": {"enabled": false}
    },
    "audio": {
      "opus": {"enabled": true},
      "mp3": {"enabled": true},
      "flac": {"enabled": true},
      "aac": {"enabled": true}
    }
  },
  "optimization": {
    "size": {"enabled": true}
  }
}
```

### Example 2: Web Streaming (LGPL-safe)

For commercial web applications requiring LGPL:

```json
{
  "codecs": {
    "video": {
      "h264": {"enabled": false},  // GPL
      "h265": {"enabled": false},  // GPL
      "vp9": {"enabled": true},
      "av1": {"enabled": true}
    },
    "audio": {
      "opus": {"enabled": true},
      "aac": {"enabled": true}
    }
  },
  "features": {
    "network": {"enabled": true}
  },
  "license": {
    "gpl": {"enabled": false},
    "nonfree": {"enabled": false}
  }
}
```

### Example 3: Archive/Preservation

For long-term archival with maximum quality:

```json
{
  "codecs": {
    "video": {
      "h264": {"enabled": true},
      "h265": {"enabled": true},
      "av1": {"enabled": true}
    },
    "audio": {
      "flac": {"enabled": true},
      "opus": {"enabled": true}
    }
  },
  "features": {
    "subtitle_rendering": {"enabled": true}
  },
  "optimization": {
    "speed": {"enabled": true},
    "lto": {"enabled": true}
  }
}
```

## Implementation Status

- ✅ **Configuration schema** - JSON schema defined in `build-config.json`
- ✅ **Preset configurations** - Three presets provided (minimal, streaming, full)
- ⬜ **Build script integration** - Pending implementation (Phase 4)
- ⬜ **Environment variable support** - Pending implementation (Phase 4)
- ⬜ **Validation tooling** - Pending implementation (Phase 4)

## Next Steps

1. **Phase 4.1** (Current): Integrate config parsing into build scripts
2. **Phase 4.2**: Add environment variable overrides
3. **Phase 4.3**: Create validation script
4. **Phase 4.4**: Update CI to use presets

## See Also

- [CODECS.md](CODECS.md) - Detailed codec documentation
- [versions.properties](versions.properties) - Dependency versions
- [build/orchestrator.sh](build/orchestrator.sh) - Build orchestration script
