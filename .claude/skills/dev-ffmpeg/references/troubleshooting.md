# FFmpeg Build Troubleshooting

## Table of Contents
- Configure Errors
- Compilation Errors  
- Link Errors
- Runtime Errors
- Platform-Specific Issues

---

## Configure Errors

### "ERROR: x264 not found using pkg-config"

**Cause:** pkg-config can't find x264.pc file.

**Fix:**
```bash
# Find where x264.pc is installed
find /usr -name "x264.pc" 2>/dev/null

# Add to PKG_CONFIG_PATH
export PKG_CONFIG_PATH=/usr/local/lib/pkgconfig:$PKG_CONFIG_PATH

# Verify
pkg-config --libs x264
```

### "ERROR: libx265 not found"

**Same solution as x264.** Additionally, x265 requires:
```bash
# x265 might install to lib64 on some systems
export PKG_CONFIG_PATH=/usr/local/lib64/pkgconfig:$PKG_CONFIG_PATH
```

### "nasm/yasm not found or too old"

**Cause:** FFmpeg requires nasm ≥2.13 for x86 SIMD optimizations.

**Fix:**
```bash
# Ubuntu/Debian
sudo apt install nasm

# macOS
brew install nasm

# Or disable if not needed (slower builds)
./configure --disable-x86asm
```

### "ERROR: xxx not found" (Generic)

**Debug steps:**
```bash
# Check config.log for actual error
tail -100 ffbuild/config.log

# Verify library is installed
pkg-config --exists libxxx && echo "Found" || echo "Not found"

# Check if headers exist
ls /usr/local/include/xxx.h

# Check if library exists
ls /usr/local/lib/libxxx.so*
```

### "C compiler test failed"

**Cause:** GCC/Clang not working or missing.

**Fix:**
```bash
# Verify compiler works
echo 'int main(){}' | gcc -x c - -o /dev/null && echo "OK"

# Install if missing
sudo apt install build-essential  # Debian/Ubuntu
sudo dnf install gcc gcc-c++ make # Fedora/RHEL
```

### Configure hangs or takes forever

**Cause:** Often network timeout checking for optional features.

**Fix:**
```bash
# Disable network probing
./configure --disable-network

# Or disable specific protocol probes
./configure --disable-protocol=https,http
```

---

## Compilation Errors

### "make: *** No targets specified"

**Cause:** Configure failed silently.

**Fix:**
```bash
# Check for config.mak
ls ffbuild/config.mak || echo "Configure failed"

# Check config.log for the actual error
cat ffbuild/config.log | grep -A5 "error:"
```

### "fatal error: xxx.h: No such file or directory"

**Cause:** Development headers not installed.

**Fix (Ubuntu/Debian):**
```bash
# Find package containing header
apt-file search xxx.h

# Install dev package
sudo apt install libxxx-dev
```

### "undefined reference to `av_xxx'"

**Cause:** Linking against wrong FFmpeg version or missing library.

**Fix:**
```bash
# Ensure you're linking all required libs
pkg-config --libs libavcodec libavformat libavutil

# Order matters! Link in dependency order
-lavformat -lavcodec -lavutil -lm -lpthread
```

### Out of memory during compilation

**Fix:**
```bash
# Reduce parallel jobs
make -j2  # Instead of -j$(nproc)

# Or single-threaded
make -j1
```

---

## Link Errors

### "cannot find -lxxx"

**Cause:** Library not in linker search path.

**Fix:**
```bash
# Find the library
find /usr -name "libxxx.so*" 2>/dev/null

# Add to ldflags
./configure --extra-ldflags="-L/usr/local/lib"

# Or set LD_LIBRARY_PATH
export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH
```

### "undefined reference to `xxx@GLIBC_2.34'"

**Cause:** Binary compiled against newer glibc than target system.

**Fix:**
- Build on older system (use Docker with older Ubuntu/Debian)
- Or use fully static linking:
```bash
./configure --enable-static --disable-shared \
  --extra-ldflags="-static" \
  --pkg-config-flags="--static"
```

### Multiple definition errors

**Cause:** Same symbol defined in multiple objects (common with static linking).

**Fix:**
```bash
# Use -fcommon (workaround for GCC 10+)
./configure --extra-cflags="-fcommon"

# Or update the offending library
```

---

## Runtime Errors

### "error while loading shared libraries: libavcodec.so.XX"

**Cause:** Library not in runtime linker path.

**Fix:**
```bash
# Option 1: Update ldconfig
echo "/usr/local/lib" | sudo tee /etc/ld.so.conf.d/ffmpeg.conf
sudo ldconfig

# Option 2: Set LD_LIBRARY_PATH
export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH

# Option 3: Use rpath during build
./configure --extra-ldflags="-Wl,-rpath,/usr/local/lib"
```

### "Discarding xxx, already has more than 500 frames"

**Cause:** Decoder producing frames faster than output can consume.

**Fix:** This is a decode/encode pipeline issue, not a build issue. Use `-threads` or fix the pipeline.

### Segmentation fault

**Debug:**
```bash
# Build with debug symbols
./configure --enable-debug --disable-stripping

# Run with gdb
gdb --args ffmpeg -i input.mp4 output.mp4

# Or get core dump
ulimit -c unlimited
ffmpeg -i input.mp4 output.mp4
gdb ffmpeg core
```

### Wrong codec version at runtime

**Cause:** Multiple FFmpeg installations, picking up wrong one.

**Fix:**
```bash
# Check which ffmpeg is being used
which ffmpeg
ffmpeg -version

# Check library paths
ldd $(which ffmpeg) | grep libav

# Ensure PATH and LD_LIBRARY_PATH are correct
export PATH=/usr/local/bin:$PATH
export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH
```

---

## Platform-Specific Issues

### macOS: "library not found for -lSystem"

**Fix:**
```bash
# Ensure Xcode CLI tools installed
xcode-select --install

# Set SDK path
export SDKROOT=$(xcrun --show-sdk-path)
```

### macOS: Apple Silicon (M1/M2) issues

```bash
# Ensure building for arm64
./configure --arch=arm64

# Some libraries need Rosetta fallback
arch -arm64 ./configure ...
```

### Windows/MinGW: "undefined reference to `__imp_xxx'"

**Cause:** Missing DLL import library.

**Fix:**
```bash
# Ensure static linking or provide import libs
./configure --enable-static --disable-shared

# Or add import library path
--extra-ldflags="-L/path/to/import/libs"
```

### Alpine/musl: "Error relocating xxx: yyy: symbol not found"

**Cause:** glibc-only symbols used.

**Fix:**
```bash
# Install compatibility package
apk add libc6-compat

# Or rebuild dependencies from source for musl
```

---

## Build Verification

After successful build:

```bash
# Check binary
file $(which ffmpeg)

# Check version
ffmpeg -version

# Check configure options
ffmpeg -buildconf

# Check available codecs
ffmpeg -codecs | head -20

# Check for specific codec
ffmpeg -codecs | grep x264

# Check encoders
ffmpeg -encoders | grep -E "264|265|vp9|opus"

# Check decoders  
ffmpeg -decoders | grep -E "264|265|vp9|opus"

# Test encode
ffmpeg -f lavfi -i testsrc=duration=1:size=1280x720 -c:v libx264 test.mp4
```

---

## Getting Help

If issues persist:

1. **Check config.log:** `ffbuild/config.log` contains the actual compiler errors
2. **Search FFmpeg bug tracker:** https://trac.ffmpeg.org/
3. **Ask on IRC:** #ffmpeg on Libera.Chat
4. **Mailing list:** ffmpeg-user@ffmpeg.org

When reporting issues, include:
- Full configure command
- Relevant portion of config.log
- `uname -a` output
- Compiler version (`gcc --version`)
