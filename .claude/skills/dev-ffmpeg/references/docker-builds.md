# Docker-Based FFmpeg Builds

## Table of Contents
- Pre-built Docker Images
- Building Your Own Image
- Multi-stage Builds
- CI/CD Pipeline Patterns
- BtbN/FFmpeg-Builds System

---

## Pre-built Docker Images

### jrottenberg/ffmpeg

Most popular FFmpeg Docker images. Multiple variants:

```bash
# Latest on Ubuntu LTS
docker pull jrottenberg/ffmpeg:latest

# Specific version + variant
docker pull jrottenberg/ffmpeg:7.1-ubuntu2404
docker pull jrottenberg/ffmpeg:7.1-alpine320
docker pull jrottenberg/ffmpeg:7.1-scratch  # Minimal

# With hardware acceleration
docker pull jrottenberg/ffmpeg:7.1-vaapi2404    # Intel VAAPI
docker pull jrottenberg/ffmpeg:7.1-nvidia2204   # NVIDIA NVENC
```

**Variants explained:**
- `ubuntu2404` - Libs from Ubuntu packages, FFmpeg from source
- `ubuntu2404-edge` - Everything built from source
- `alpine320` - Small Alpine-based
- `scratch` - Minimal, stripped binaries
- `vaapi*` - Intel hardware acceleration
- `nvidia*` - NVIDIA GPU acceleration

### Usage Examples

```bash
# Simple transcode
docker run -v $(pwd):/data jrottenberg/ffmpeg:7.1-alpine \
  -i /data/input.mp4 -c:v libx264 /data/output.mp4

# Extract audio
docker run -v $(pwd):/data jrottenberg/ffmpeg:7.1-alpine \
  -i /data/video.mp4 -vn -c:a libopus /data/audio.opus

# Stream to stdout
docker run jrottenberg/ffmpeg:7.1-alpine \
  -i http://example.com/video.mp4 -f mp4 - > output.mp4
```

---

## Building Your Own Image

### Minimal Dockerfile

```dockerfile
FROM ubuntu:24.04 AS builder

RUN apt-get update && apt-get install -y \
    build-essential pkg-config git nasm yasm \
    libx264-dev libx265-dev libvpx-dev libopus-dev

WORKDIR /build
RUN git clone --depth 1 --branch n7.1 https://git.ffmpeg.org/ffmpeg.git

WORKDIR /build/ffmpeg
RUN ./configure \
    --prefix=/opt/ffmpeg \
    --enable-gpl \
    --enable-libx264 \
    --enable-libx265 \
    --enable-libvpx \
    --enable-libopus \
    --enable-shared \
    --disable-debug \
    --disable-doc \
    && make -j$(nproc) \
    && make install

# Runtime image
FROM ubuntu:24.04
RUN apt-get update && apt-get install -y \
    libx264-164 libx265-209 libvpx9 libopus0 \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /opt/ffmpeg /opt/ffmpeg
ENV PATH="/opt/ffmpeg/bin:$PATH"
ENV LD_LIBRARY_PATH="/opt/ffmpeg/lib:$LD_LIBRARY_PATH"

ENTRYPOINT ["ffmpeg"]
```

### Static Binary (Scratch Image)

```dockerfile
FROM alpine:3.20 AS builder

RUN apk add --no-cache \
    build-base pkgconfig git nasm yasm \
    x264-dev x265-dev libvpx-dev opus-dev

WORKDIR /build
RUN git clone --depth 1 --branch n7.1 https://git.ffmpeg.org/ffmpeg.git

WORKDIR /build/ffmpeg
RUN ./configure \
    --prefix=/opt/ffmpeg \
    --enable-gpl \
    --enable-libx264 \
    --enable-libx265 \
    --enable-libvpx \
    --enable-libopus \
    --enable-static \
    --disable-shared \
    --pkg-config-flags="--static" \
    --extra-ldflags="-static" \
    --disable-debug \
    --disable-doc \
    && make -j$(nproc) \
    && make install \
    && strip /opt/ffmpeg/bin/*

FROM scratch
COPY --from=builder /opt/ffmpeg/bin/ffmpeg /ffmpeg
COPY --from=builder /opt/ffmpeg/bin/ffprobe /ffprobe
ENTRYPOINT ["/ffmpeg"]
```

---

## Multi-Stage for Native Addons

For Node.js native addons needing FFmpeg libraries:

```dockerfile
# Build FFmpeg with shared libs
FROM node:20-bookworm AS ffmpeg-builder

RUN apt-get update && apt-get install -y \
    build-essential pkg-config nasm yasm \
    libx264-dev libx265-dev libvpx-dev

WORKDIR /ffmpeg
RUN git clone --depth 1 --branch n7.1 https://git.ffmpeg.org/ffmpeg.git .
RUN ./configure \
    --prefix=/usr/local \
    --enable-gpl \
    --enable-shared \
    --enable-pic \
    --enable-libx264 \
    --enable-libx265 \
    --enable-libvpx \
    --disable-static \
    --disable-debug \
    --disable-doc \
    && make -j$(nproc) \
    && make install

# Build native addon
FROM node:20-bookworm AS addon-builder

COPY --from=ffmpeg-builder /usr/local/lib /usr/local/lib
COPY --from=ffmpeg-builder /usr/local/include /usr/local/include
COPY --from=ffmpeg-builder /usr/local/lib/pkgconfig /usr/local/lib/pkgconfig

RUN apt-get update && apt-get install -y \
    build-essential python3 pkg-config \
    libx264-dev libx265-dev libvpx-dev

ENV PKG_CONFIG_PATH=/usr/local/lib/pkgconfig
ENV LD_LIBRARY_PATH=/usr/local/lib

WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
RUN npm run build

# Runtime
FROM node:20-bookworm-slim

RUN apt-get update && apt-get install -y \
    libx264-164 libx265-209 libvpx9 \
    && rm -rf /var/lib/apt/lists/*

COPY --from=ffmpeg-builder /usr/local/lib/libav* /usr/local/lib/
COPY --from=ffmpeg-builder /usr/local/lib/libsw* /usr/local/lib/
COPY --from=addon-builder /app /app

ENV LD_LIBRARY_PATH=/usr/local/lib
WORKDIR /app
CMD ["node", "index.js"]
```

---

## CI/CD Pipeline Patterns

### GitHub Actions

```yaml
name: Build FFmpeg

on: [push, pull_request]

jobs:
  build:
    strategy:
      matrix:
        os: [ubuntu-22.04, ubuntu-24.04]
        ffmpeg: ['7.0', '7.1']
    
    runs-on: ${{ matrix.os }}
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Install dependencies
        run: |
          sudo apt-get update
          sudo apt-get install -y \
            build-essential pkg-config nasm yasm \
            libx264-dev libx265-dev libvpx-dev
      
      - name: Build FFmpeg
        run: |
          git clone --depth 1 --branch n${{ matrix.ffmpeg }} \
            https://git.ffmpeg.org/ffmpeg.git
          cd ffmpeg
          ./configure \
            --prefix=$HOME/ffmpeg-install \
            --enable-gpl \
            --enable-shared \
            --enable-libx264 \
            --enable-libx265 \
            --enable-libvpx
          make -j$(nproc)
          make install
      
      - name: Upload artifacts
        uses: actions/upload-artifact@v4
        with:
          name: ffmpeg-${{ matrix.ffmpeg }}-${{ matrix.os }}
          path: ~/ffmpeg-install/
```

### Matrix Build with Docker

```yaml
jobs:
  docker-build:
    strategy:
      matrix:
        target: [linux64, linuxarm64, win64]
        variant: [gpl, lgpl]
    
    runs-on: ubuntu-latest
    
    steps:
      - uses: docker/setup-buildx-action@v3
      
      - name: Build
        run: |
          git clone https://github.com/BtbN/FFmpeg-Builds.git
          cd FFmpeg-Builds
          ./build.sh ${{ matrix.target }} ${{ matrix.variant }}
```

---

## BtbN/FFmpeg-Builds System

Professional-grade build system with:
- Daily automated builds
- Multiple targets (win64, linux64, linuxarm64, winarm64)
- License variants (gpl, lgpl, nonfree)
- Static and shared builds

### Local Build

```bash
git clone https://github.com/BtbN/FFmpeg-Builds.git
cd FFmpeg-Builds

# Build for Linux x64 with GPL
./build.sh linux64 gpl

# Build for Windows x64 with specific version
./build.sh win64 gpl 7.1

# Options: gpl, lgpl, gpl-shared, lgpl-shared, nonfree
# Addins: 7.1, 7.0, 6.1, debug, lto
```

### How It Works

1. **generate.sh** - Creates Dockerfile from library scripts
2. **makeimage.sh** - Builds Docker image with toolchain
3. **build.sh** - Runs FFmpeg configure/make in container
4. Artifacts output to `artifacts/` directory

### Adding Custom Libraries

Edit or add scripts in `scripts.d/`:

```bash
# scripts.d/50-mylibrary.sh
ffbuild_enabled() {
    return 0  # Always enabled
    # return -1 to disable
}

ffbuild_dockerbuild() {
    git clone --depth 1 https://github.com/example/mylibrary.git
    cd mylibrary
    ./configure --prefix="$FFBUILD_PREFIX"
    make -j$(nproc)
    make install
}

ffbuild_configure() {
    echo --enable-mylibrary
}

ffbuild_unconfigure() {
    echo --disable-mylibrary
}
```

---

## Hardware Acceleration in Docker

### NVIDIA (NVENC/NVDEC)

```bash
# Requires nvidia-docker2
docker run --gpus all jrottenberg/ffmpeg:7.1-nvidia2204 \
  -hwaccel cuda -hwaccel_output_format cuda \
  -i input.mp4 -c:v h264_nvenc output.mp4
```

### Intel VAAPI

```bash
docker run --device /dev/dri:/dev/dri \
  jrottenberg/ffmpeg:7.1-vaapi2404 \
  -hwaccel vaapi -hwaccel_device /dev/dri/renderD128 \
  -i input.mp4 -c:v h264_vaapi output.mp4
```
