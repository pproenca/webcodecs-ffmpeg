# Incremental Builds with ccache

The build system supports `ccache` (compiler cache) to significantly speed up incremental builds by caching compiled object files.

## Performance Impact

| Build Type | macOS (Native) | Docker (Linux) |
|------------|----------------|----------------|
| **First build** (cold cache) | 20-25 min | 25-35 min |
| **Incremental build** (warm cache) | 2-5 min | 5-10 min |
| **Speedup** | **4-10x faster** | **3-5x faster** |

## macOS Setup

### Install ccache

```bash
brew install ccache
```

### Build with ccache

ccache is automatically detected and used if installed:

```bash
./build/orchestrator.sh darwin-arm64
```

Output will show:
```
✓ Using ccache for incremental builds (cache dir: /Users/you/.ccache)
  First build: ~20-25 min, subsequent builds: ~2-5 min
```

### Configure ccache

```bash
# Set cache size (default: 5GB, recommended: 10GB for FFmpeg)
ccache --set-config=max_size=10G

# View cache statistics
ccache -s

# Clear cache
ccache -C
```

### Environment Variables

```bash
# Custom cache directory
export CCACHE_DIR=/path/to/custom/cache

# Disable ccache temporarily
export CCACHE_DISABLE=1
./build/orchestrator.sh darwin-arm64
```

## Docker Setup

### Linux Docker Builds

ccache is **pre-installed** in all Docker images. To enable persistent caching across builds:

```bash
# Build with Docker cache mount
docker buildx build \
  --platform linux/amd64 \
  --cache-from type=local,src=/tmp/docker-cache \
  --cache-to type=local,dest=/tmp/docker-cache \
  -f platforms/linux-x64-glibc/Dockerfile \
  -t ffmpeg-builder:linux-x64-glibc \
  .
```

The build scripts already use GitHub Actions cache in CI:
```bash
--cache-from type=gha,scope="$PLATFORM"
--cache-to type=gha,mode=max,scope="$PLATFORM"
```

### Windows Cross-Compilation

Windows builds (MinGW cross-compile) also support ccache:

```bash
./build/windows.sh windows-x64
```

## CI/CD Integration

GitHub Actions workflow already configures ccache:

```yaml
- name: Build FFmpeg
  run: ./build/orchestrator.sh ${{ matrix.platform }}
  env:
    CCACHE_DIR: ${{ github.workspace }}/.ccache
```

Docker layer caching is enabled via GitHub Actions cache:
- Cache key: `${{ matrix.platform }}-${{ hashFiles('versions.properties') }}`
- Scope: Per-platform and per-version

## When ccache Helps Most

**Maximum benefit:**
- 🔥 Changing FFmpeg configure flags
- 🔥 Updating FFmpeg version (e.g., n8.0 → n8.1)
- 🔥 Modifying build scripts without codec changes
- 🔥 Local development iterations

**Moderate benefit:**
- ⚡ Updating single codec version (e.g., x264 stable → new commit)
- ⚡ Adding/removing optional features

**Minimal benefit:**
- ❌ Full clean builds (cache miss)
- ❌ Changing all codec versions simultaneously
- ❌ First build ever (no cache exists)

## Troubleshooting

### macOS: "ccache not found"

```bash
# Install via Homebrew
brew install ccache

# Verify installation
which ccache
# Expected: /opt/homebrew/bin/ccache (Apple Silicon)
#           /usr/local/bin/ccache (Intel)
```

### Cache Not Being Used

```bash
# Check cache stats
ccache -s

# Look for:
# - cache hit rate > 0%
# - files in cache > 0

# If all zeros, cache is not being used
# Ensure CC/CXX environment variables are NOT overriding ccache
env | grep -E '^CC=|^CXX='
# Should be empty or show ccache
```

### Cache Miss After Version Update

This is **expected**. When updating `versions.properties`, most source files change, invalidating the cache. The cache will rebuild and be available for subsequent builds.

### Docker: Cache Not Persisting

Docker builds are ephemeral by default. To persist cache:

**Option 1: Use GitHub Actions cache** (automatic in CI)

**Option 2: Mount local cache directory**
```bash
docker buildx build \
  --cache-from type=local,src=$HOME/.docker-cache \
  --cache-to type=local,dest=$HOME/.docker-cache \
  ...
```

**Option 3: Use Docker volumes**
```bash
docker volume create ffmpeg-ccache
docker buildx build \
  --mount type=volume,source=ffmpeg-ccache,target=/cache \
  ...
```

## Cache Management

### View Cache Size

```bash
# macOS
du -sh ~/.ccache

# Docker (if mounted)
du -sh /tmp/docker-cache
```

### Clean Old Cache Entries

```bash
# Remove entries older than 30 days
ccache --evict-older-than 30d

# Remove all cache
ccache -C
```

### Recommended Cache Sizes

| Use Case | macOS Cache | Docker Cache |
|----------|------------|--------------|
| **Casual development** | 5GB | N/A (ephemeral) |
| **Active development** | 10GB | 5GB per platform |
| **Multi-platform CI** | N/A | 2GB per platform |

## Implementation Details

### macOS Native Builds

The `build/macos.sh` script detects ccache and sets:
```bash
export CC="ccache clang"
export CXX="ccache clang++"
export CCACHE_DIR="${CCACHE_DIR:-$HOME/.ccache}"
```

### Docker Builds

All Dockerfiles include:
```dockerfile
# Install ccache
RUN apt-get install -y ccache

# Add to PATH (highest priority)
ENV PATH=/usr/lib/ccache:$PREFIX/bin:$PATH
ENV CCACHE_DIR=/cache
```

The `/usr/lib/ccache` directory contains symlinks that intercept compiler calls:
```
/usr/lib/ccache/gcc -> /usr/bin/ccache
/usr/lib/ccache/g++ -> /usr/bin/ccache
/usr/lib/ccache/clang -> /usr/bin/ccache
```

### What Gets Cached

ccache caches:
- ✅ Compiled object files (`.o`)
- ✅ Preprocessed source (after includes expanded)
- ✅ Compiler flags and environment

ccache does NOT cache:
- ❌ Linking steps
- ❌ Configure script output
- ❌ CMake generation
- ❌ Archive creation (`.a` files)

## Best Practices

1. **Keep cache directory on fast storage** (SSD, not network drive)
2. **Don't share cache between different architectures** (arm64 vs x64)
3. **Clear cache after major toolchain updates** (e.g., Xcode upgrade)
4. **Monitor cache hit rate** - should be >80% for incremental builds
5. **Increase cache size if seeing frequent evictions**

## See Also

- [ccache Documentation](https://ccache.dev/)
- [Docker Build Cache](https://docs.docker.com/build/cache/)
- [GitHub Actions Cache](https://github.com/actions/cache)
