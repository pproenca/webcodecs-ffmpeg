---
name: dev-ffmpeg
description: Configure and compile FFmpeg from source for any platform and architecture. Handles cross-compilation (Linux→Windows, x86_64→ARM), license compliance (LGPL/GPL/nonfree), codec dependencies, and Docker-based builds. Use when building FFmpeg binaries, creating CI/CD pipelines for FFmpeg compilation, debugging configure failures, or selecting codecs and features for custom builds.
---

# FFmpeg Build Configuration

Configure working FFmpeg compilation for any target platform.

## Quick Decision: Which Build Approach?

| Scenario | Approach | Reference |
|----------|----------|-----------|
| Need binaries quickly | Pre-built from BtbN or gyan.dev | — |
| Production deployment | Docker-based build | `references/docker-builds.md` |
| Development/debugging | Native build on target | Platform reference |
| Cross-compiling | Docker + toolchain | `references/cross-compile.md` |
| Node.js native addon | Shared libs + pkg-config | `references/shared-libs.md` |

## Build Workflow

1. **Determine requirements** → License, codecs, platform, linking
2. **Install dependencies** → Platform toolchain + codec libraries  
3. **Configure FFmpeg** → `./configure` with flags
4. **Build** → `make -j$(nproc) && make install`
5. **Verify** → `ffmpeg -version` and `-buildconf`

## Step 1: License Decision

```
Will you DISTRIBUTE the binary?
├─ NO → Any configuration including --enable-nonfree
└─ YES → Need GPL codecs (x264, x265)?
         ├─ YES → --enable-gpl (GPL v2+)
         └─ NO  → Default LGPL 2.1+
```

**License flags:**
- Default: LGPL 2.1+ (can link with proprietary code)
- `--enable-gpl`: Enables GPL codecs (x264, x265, xvid)
- `--enable-version3`: Upgrade to (L)GPL v3 (needed for some libs)
- `--enable-nonfree`: Patent-encumbered codecs (NOT redistributable)

## Step 2: Linking Decision

| Use Case | Linking | Flags |
|----------|---------|-------|
| Standalone binary | Static | `--enable-static --disable-shared` |
| Native addon | Shared | `--enable-shared --disable-static --enable-pic` |
| Both | Both | `--enable-static --enable-shared --enable-pic` |

## Step 3: Configure Patterns

### Minimal LGPL (redistributable)

```bash
./configure \
  --prefix=/usr/local \
  --enable-shared \
  --enable-pic \
  --disable-debug \
  --disable-doc
```

### Standard GPL (common codecs)

```bash
./configure \
  --prefix=/usr/local \
  --enable-gpl \
  --enable-shared \
  --enable-pic \
  --enable-libx264 \
  --enable-libx265 \
  --enable-libvpx \
  --enable-libopus \
  --enable-libvorbis \
  --disable-debug \
  --disable-doc
```

### Full Build (not redistributable)

```bash
./configure \
  --prefix=/usr/local \
  --enable-gpl \
  --enable-nonfree \
  --enable-version3 \
  --enable-shared \
  --enable-pic \
  --enable-libx264 \
  --enable-libx265 \
  --enable-libvpx \
  --enable-libaom \
  --enable-libsvtav1 \
  --enable-libdav1d \
  --enable-libopus \
  --enable-libvorbis \
  --enable-libmp3lame \
  --enable-libfdk-aac \
  --disable-debug \
  --disable-doc
```

### For Native Addons (Node.js/Python bindings)

```bash
./configure \
  --prefix=/usr/local \
  --enable-shared \
  --disable-static \
  --enable-pic \
  --enable-gpl \
  --enable-libx264 \
  --enable-libx265 \
  --enable-libvpx

# After install, verify:
pkg-config --libs --cflags libavcodec libavformat libavutil
```

## Codec Quick Reference

| Codec | Flag | License | Ubuntu Package |
|-------|------|---------|----------------|
| H.264 | `--enable-libx264` | GPL | libx264-dev |
| H.265 | `--enable-libx265` | GPL | libx265-dev |
| VP8/VP9 | `--enable-libvpx` | BSD | libvpx-dev |
| AV1 decode | `--enable-libdav1d` | BSD | libdav1d-dev |
| AV1 encode | `--enable-libaom` | BSD | libaom-dev |
| AV1 fast | `--enable-libsvtav1` | BSD | libsvtav1-dev |
| AAC HQ | `--enable-libfdk-aac` | Nonfree | libfdk-aac-dev |
| MP3 | `--enable-libmp3lame` | LGPL | libmp3lame-dev |
| Opus | `--enable-libopus` | BSD | libopus-dev |
| Vorbis | `--enable-libvorbis` | BSD | libvorbis-dev |

See `references/codec-matrix.md` for full codec dependency details.

## Environment Variables

Essential for custom prefix builds:

```bash
export PREFIX=/usr/local
export PATH="$PREFIX/bin:$PATH"
export LD_LIBRARY_PATH="$PREFIX/lib:$LD_LIBRARY_PATH"
export PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig:$PKG_CONFIG_PATH"
export CFLAGS="-I$PREFIX/include"
export LDFLAGS="-L$PREFIX/lib"
```

## Common Errors Quick Reference

| Error | Fix |
|-------|-----|
| `ERROR: x264 not found` | `export PKG_CONFIG_PATH=/usr/local/lib/pkgconfig` |
| `libavcodec.so: cannot open` | `export LD_LIBRARY_PATH=/usr/local/lib` |
| `nasm/yasm not found` | `apt install nasm` |
| `make: *** No targets` | Check `ffbuild/config.log` for configure errors |
| `undefined reference to` | Check link order in `--extra-ldflags` |

See `references/troubleshooting.md` for detailed solutions.

## Platform References

- **Linux** → `references/platform-linux.md`
- **macOS** → `references/platform-macos.md`
- **Windows** → `references/platform-windows.md`
- **Cross-compile** → `references/cross-compile.md`
- **Docker builds** → `references/docker-builds.md`
- **vcpkg (Windows)** → `references/vcpkg.md`
