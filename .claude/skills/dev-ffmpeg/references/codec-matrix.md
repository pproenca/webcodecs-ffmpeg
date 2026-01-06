# Codec Dependency Matrix

## Table of Contents
- License Summary
- Video Codecs
- Audio Codecs
- Container/Muxer Support
- Hardware Acceleration
- Filters and Processing

---

## License Summary

| License | Redistribution | Configure Flag | Codecs Enabled |
|---------|---------------|----------------|----------------|
| LGPL 2.1+ | ✓ Proprietary linking OK | (default) | Built-in codecs only |
| GPL 2+ | ✓ Source required | `--enable-gpl` | x264, x265, xvid, etc. |
| GPL 3+ | ✓ Source required | `--enable-gpl --enable-version3` | OpenCORE AMR, etc. |
| Nonfree | ✗ Not redistributable | `--enable-nonfree` | libfdk-aac, openssl |

---

## Video Codecs

### H.264 / AVC

| Library | Flag | License | Quality | Speed | Notes |
|---------|------|---------|---------|-------|-------|
| libx264 | `--enable-libx264` | GPL | Excellent | Fast | Industry standard |
| openh264 | `--enable-libopenh264` | BSD | Good | Medium | Cisco patent license |
| (built-in) | — | LGPL | Decode only | — | No encode |

**x264 build from source:**
```bash
git clone --depth 1 https://code.videolan.org/videolan/x264.git
cd x264
./configure --prefix=/usr/local --enable-shared --enable-pic
make -j$(nproc) && sudo make install
```

### H.265 / HEVC

| Library | Flag | License | Quality | Speed | Notes |
|---------|------|---------|---------|-------|-------|
| libx265 | `--enable-libx265` | GPL | Excellent | Slow | Best quality |
| kvazaar | `--enable-libkvazaar` | BSD | Good | Fast | LGPL-compatible |

**x265 build from source:**
```bash
git clone --depth 1 https://bitbucket.org/multicoreware/x265_git.git
cd x265_git/build/linux
cmake -G "Unix Makefiles" \
  -DCMAKE_INSTALL_PREFIX=/usr/local \
  -DENABLE_SHARED=ON \
  ../../source
make -j$(nproc) && sudo make install
```

### VP8 / VP9

| Library | Flag | License | Notes |
|---------|------|---------|-------|
| libvpx | `--enable-libvpx` | BSD | Encode + decode |

**libvpx build:**
```bash
git clone --depth 1 https://chromium.googlesource.com/webm/libvpx.git
cd libvpx
./configure --prefix=/usr/local --enable-shared --enable-pic \
  --disable-examples --disable-unit-tests
make -j$(nproc) && sudo make install
```

### AV1

| Library | Flag | License | Type | Speed | Notes |
|---------|------|---------|------|-------|-------|
| libaom | `--enable-libaom` | BSD | Encode+Decode | Very slow | Reference impl |
| libsvtav1 | `--enable-libsvtav1` | BSD | Encode | Fast | Intel/Netflix |
| libdav1d | `--enable-libdav1d` | BSD | Decode only | Very fast | VideoLAN |
| librav1e | `--enable-librav1e` | BSD | Encode | Medium | Rust-based |

**Recommended AV1 setup:**
- Decode: libdav1d (fastest)
- Encode: libsvtav1 (best speed/quality)

```bash
# dav1d
git clone --depth 1 https://code.videolan.org/videolan/dav1d.git
cd dav1d
meson setup build --prefix=/usr/local --buildtype=release
ninja -C build && sudo ninja -C build install

# SVT-AV1
git clone --depth 1 https://gitlab.com/AOMediaCodec/SVT-AV1.git
cd SVT-AV1/Build
cmake .. -DCMAKE_INSTALL_PREFIX=/usr/local -DBUILD_SHARED_LIBS=ON
make -j$(nproc) && sudo make install
```

### Other Video Codecs

| Codec | Library | Flag | License | Notes |
|-------|---------|------|---------|-------|
| MPEG-4 | xvid | `--enable-libxvid` | GPL | Legacy |
| Theora | libtheora | `--enable-libtheora` | BSD | Web video |
| JPEG | libjpeg | (built-in) | — | Thumbnail extraction |
| WebP | libwebp | `--enable-libwebp` | BSD | Image sequences |

---

## Audio Codecs

### AAC

| Library | Flag | License | Quality | Notes |
|---------|------|---------|---------|-------|
| libfdk-aac | `--enable-libfdk-aac` | Nonfree | Excellent | Best quality |
| (built-in aac) | — | LGPL | Good | Native FFmpeg |
| libvo-aacenc | `--enable-libvo-aacenc` | Apache | Poor | Deprecated |

**Note:** Built-in AAC encoder is good enough for most uses. Use libfdk-aac only if you need the absolute best quality and won't redistribute.

### MP3

| Library | Flag | License | Notes |
|---------|------|---------|-------|
| libmp3lame | `--enable-libmp3lame` | LGPL | Standard MP3 encoder |
| (built-in) | — | LGPL | Decode only |

### Opus (Recommended for VoIP/Streaming)

| Library | Flag | License | Notes |
|---------|------|---------|-------|
| libopus | `--enable-libopus` | BSD | Encode + decode |

### Vorbis

| Library | Flag | License | Notes |
|---------|------|---------|-------|
| libvorbis | `--enable-libvorbis` | BSD | Encode + decode |
| Requires | libogg | — | — |

### Other Audio

| Codec | Library | Flag | License | Notes |
|-------|---------|------|---------|-------|
| FLAC | (built-in) | — | LGPL | Lossless |
| AC-3 | (built-in) | — | LGPL | Dolby Digital |
| AMR-NB | opencore-amr | `--enable-libopencore-amrnb` | Apache/GPL3 | Voice |
| AMR-WB | opencore-amr | `--enable-libopencore-amrwb` | Apache/GPL3 | Voice |
| Speex | libspeex | `--enable-libspeex` | BSD | Voice (legacy) |

---

## Container/Format Dependencies

| Format | Library | Flag | License | Notes |
|--------|---------|------|---------|-------|
| Blu-ray | libbluray | `--enable-libbluray` | LGPL | BD playback |
| DVD | libdvdread | `--enable-libdvdread` | GPL | DVD playback |
| SRT streaming | libsrt | `--enable-libsrt` | MPL | Secure streaming |
| RTMP | librtmp | `--enable-librtmp` | LGPL | Flash streaming |
| OpenSSL | openssl | `--enable-openssl` | Nonfree | HTTPS/RTMPS |
| GnuTLS | gnutls | `--enable-gnutls` | LGPL | HTTPS alternative |

---

## Hardware Acceleration

### NVIDIA (NVENC/NVDEC/CUDA)

```bash
# Install SDK headers
git clone --depth 1 https://github.com/FFmpeg/nv-codec-headers.git
cd nv-codec-headers
sudo make install

# Configure FFmpeg
./configure \
  --enable-cuda-nvcc \
  --enable-cuvid \
  --enable-nvenc \
  --enable-nvdec \
  --enable-libnpp \
  --extra-cflags=-I/usr/local/cuda/include \
  --extra-ldflags=-L/usr/local/cuda/lib64
```

### Intel Quick Sync (QSV)

```bash
# Install Intel Media SDK
sudo apt install libmfx-dev

./configure \
  --enable-libmfx \
  --enable-vaapi
```

### Intel VAAPI (Linux)

```bash
sudo apt install libva-dev

./configure --enable-vaapi
```

### Apple VideoToolbox (macOS)

```bash
./configure --enable-videotoolbox
```

### Vulkan Video

```bash
sudo apt install libvulkan-dev libshaderc-dev

./configure \
  --enable-vulkan \
  --enable-libshaderc
```

---

## Filters and Processing

| Feature | Library | Flag | License | Notes |
|---------|---------|------|---------|-------|
| Subtitles | libass | `--enable-libass` | ISC | ASS/SSA rendering |
| Fonts | fontconfig | `--enable-fontconfig` | MIT | Font management |
| Text | freetype | `--enable-libfreetype` | FTL/GPL | Text rendering |
| Stabilization | vid.stab | `--enable-libvidstab` | GPL | Deshake |
| Scene detect | — | (built-in) | — | scdet filter |
| Face detect | — | (built-in) | — | facedetect filter |
| VMAF | libvmaf | `--enable-libvmaf` | BSD | Quality metrics |
| Zscale | zimg | `--enable-libzimg` | WTFPL | High-quality scaling |

---

## Minimal vs Full Build Examples

### Minimal LGPL (Redistributable)

```bash
./configure \
  --enable-shared \
  --enable-pic \
  --enable-libopus \
  --enable-libvorbis \
  --enable-libvpx \
  --disable-debug \
  --disable-doc
```

### Standard GPL

```bash
./configure \
  --enable-gpl \
  --enable-shared \
  --enable-pic \
  --enable-libx264 \
  --enable-libx265 \
  --enable-libvpx \
  --enable-libopus \
  --enable-libvorbis \
  --enable-libmp3lame \
  --disable-debug \
  --disable-doc
```

### Kitchen Sink (Not Redistributable)

```bash
./configure \
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
  --enable-libass \
  --enable-libfreetype \
  --enable-fontconfig \
  --enable-libvidstab \
  --enable-openssl \
  --enable-libsrt \
  --disable-debug \
  --disable-doc
```
