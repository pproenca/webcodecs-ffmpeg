# FFmpeg Prebuilds - Functional Test Suite

Comprehensive testing suite for validating FFmpeg builds across all platforms.

## Quick Start

```bash
# Run all tests on current platform
./tests/run-all-tests.sh

# Clean results and run tests
./tests/run-all-tests.sh --clean

# Test specific platform
./tests/run-all-tests.sh --platform linux-x64-glibc

# Regenerate test fixtures
./tests/run-all-tests.sh --fixtures
```

## Test Structure

```
tests/
├── test-config.sh         # Common configuration and utilities
├── run-all-tests.sh       # Main test suite runner
├── encode-tests.sh        # Video/audio encoding validation
├── decode-tests.sh        # Decoding and format support tests
├── performance-tests.sh   # Performance benchmarks
├── fixtures/              # Test media files
│   ├── test-input.yuv     # Raw video (generated)
│   ├── test-input.mp4     # H.264 video (generated)
│   └── test-input.wav     # Audio (generated)
└── results/               # Test outputs (gitignored)
```

## Test Categories

### 1. Encoding Tests (`encode-tests.sh`)

Validates that all configured codecs can encode test media:

**Video Codecs Tested:**
- H.264 (libx264)
- H.265/HEVC (libx265)
- VP8 (libvpx)
- VP9 (libvpx-vp9)
- AV1 (libaom-av1, libsvtav1)

**Audio Codecs Tested:**
- Opus (libopus)
- MP3 (libmp3lame)
- AAC (native, fdk-aac if enabled)
- FLAC (libflac)
- Vorbis (libvorbis)
- Speex (libspeex)

**Validation:**
- ✅ Encoding completes without errors
- ✅ Output file exists and is non-zero size
- ✅ Output codec matches expected codec (via ffprobe)
- ✅ File size within acceptable range
- ✅ Encoding time within threshold

### 2. Decoding Tests (`decode-tests.sh`)

Validates decoding capabilities and format support:

**Tests:**
- Decode H.264/H.265/VP8/VP9/AV1 videos
- Extract frames from video
- Convert between formats
- Audio format conversion
- Subtitle extraction (if libass enabled)

**Validation:**
- ✅ Decoding completes without errors
- ✅ Frame count matches source
- ✅ Output integrity (checksum validation)

### 3. Performance Benchmarks (`performance-tests.sh`)

Measures encoding performance across codecs and presets:

**Benchmarks:**
- H.264 preset comparison (ultrafast → slow)
- Codec comparison (same quality target)
- Resolution scaling (480p, 720p, 1080p, 4K)
- Multi-threaded encoding efficiency

**Metrics:**
- Encoding speed (fps)
- CPU usage
- Memory usage
- Output quality (PSNR)
- Compression ratio

**Output:**
- JSON results for tracking over time
- Regression detection (compare against baseline)

## Configuration

Test behavior is controlled by `test-config.sh`:

### Test Media Specifications

```bash
TEST_VIDEO_DURATION=5        # seconds
TEST_VIDEO_WIDTH=1920
TEST_VIDEO_HEIGHT=1080
TEST_VIDEO_FPS=30

TEST_AUDIO_DURATION=5        # seconds
TEST_AUDIO_SAMPLE_RATE=48000
TEST_AUDIO_CHANNELS=2
```

### Validation Thresholds

```bash
MAX_OUTPUT_SIZE_MB=50        # Maximum file size
MIN_PSNR_DB=30.0             # Minimum quality (PSNR)

# Per-codec encoding time limits
MAX_ENCODING_TIME=(
  ["libx264"]=30
  ["libx265"]=60
  ["libaom-av1"]=120
  # ...
)
```

## Platform-Specific Testing

Each platform is tested independently:

```bash
# macOS Intel
./tests/run-all-tests.sh --platform darwin-x64

# macOS Apple Silicon
./tests/run-all-tests.sh --platform darwin-arm64

# Linux x64 glibc
./tests/run-all-tests.sh --platform linux-x64-glibc

# Linux x64 musl (Alpine, static)
./tests/run-all-tests.sh --platform linux-x64-musl

# Linux ARM64 glibc
./tests/run-all-tests.sh --platform linux-arm64-glibc

# Linux ARM64 musl
./tests/run-all-tests.sh --platform linux-arm64-musl

# Linux ARMv7 (Raspberry Pi)
./tests/run-all-tests.sh --platform linux-armv7-glibc

# Windows x64 (MinGW)
./tests/run-all-tests.sh --platform windows-x64
```

## CI Integration

Tests run automatically in GitHub Actions after builds complete:

```yaml
- name: Run Functional Tests
  run: |
    chmod +x tests/run-all-tests.sh
    ./tests/run-all-tests.sh --platform ${{ matrix.platform }}

- name: Upload Test Results
  if: always()
  uses: actions/upload-artifact@v4
  with:
    name: test-results-${{ matrix.platform }}
    path: tests/results/
```

## Test Fixtures

Test fixtures are generated automatically on first run using FFmpeg's `lavfi` (libavfilter) video/audio sources:

### Video Fixture (testsrc)
```bash
ffmpeg -f lavfi \
  -i "testsrc=duration=5:size=1920x1080:rate=30" \
  -pix_fmt yuv420p \
  test-input.yuv
```

**Pattern:** Color bars, moving gradient, timestamp overlay

### Audio Fixture (sine)
```bash
ffmpeg -f lavfi \
  -i "sine=frequency=1000:duration=5:sample_rate=48000" \
  -ac 2 \
  test-input.wav
```

**Pattern:** 1000Hz sine wave, stereo

### Regenerating Fixtures

```bash
# Delete and regenerate
rm tests/fixtures/*
./tests/run-all-tests.sh --fixtures
```

## Expected Output

```
==========================================
FFmpeg Prebuilds - Functional Test Suite
==========================================

Platform: darwin-arm64
FFmpeg: /path/to/artifacts/darwin-arm64/bin/ffmpeg

✓ FFmpeg binary found
✓ FFprobe binary found
✓ Test fixtures initialized

==========================================
Running: Encoding Tests
==========================================

=== Video Encoding ===
✓ libx264 (H.264) - 25.3 fps, 1.2 MB
✓ libx265 (HEVC) - 8.7 fps, 0.9 MB
✓ libvpx-vp9 (VP9) - 3.2 fps, 0.8 MB
✓ libaom-av1 (AV1) - 1.5 fps, 0.7 MB
✓ libsvtav1 (AV1) - 12.1 fps, 0.75 MB

=== Audio Encoding ===
✓ libopus (Opus) - 0.3 MB
✓ libmp3lame (MP3) - 0.6 MB
✓ aac (AAC) - 0.5 MB

✓ Encoding Tests PASSED

==========================================
Running: Decoding Tests
==========================================

✓ H.264 decode - 1500 frames extracted
✓ VP9 decode - 1500 frames extracted
✓ Format conversion (mp4 → webm) - OK

✓ Decoding Tests PASSED

==========================================
Running: Performance Benchmarks
==========================================

=== H.264 Preset Comparison (1080p) ===
ultrafast: 145 fps, PSNR 38.2 dB
veryfast:   95 fps, PSNR 40.1 dB
medium:     42 fps, PSNR 42.5 dB
slow:       18 fps, PSNR 44.3 dB

✓ Performance Benchmarks PASSED

==========================================
Test Summary
==========================================

Total Tests: 3
✓ Passed: 3
✗ Failed: 0
⚠ Skipped: 0

Duration: 127s

✓ Test suite PASSED
```

## Development Workflow

### Adding New Tests

1. **Create test in appropriate script** (encode/decode/performance)
2. **Follow naming convention:** `test_<category>_<codec>`
3. **Use test-config.sh utilities** for validation
4. **Update codec matrix** if testing new codec

Example:
```bash
test_encode_xvid() {
  local output="$RESULTS_DIR/test-xvid.avi"

  "$FFMPEG_BIN" \
    -i "$TEST_VIDEO_H264" \
    -c:v libxvid \
    -q:v 4 \
    -y \
    "$output" 2>/dev/null

  validate_video_output "$output" "mpeg4"
}
```

### Debugging Test Failures

```bash
# Run specific test script
bash tests/encode-tests.sh

# Enable verbose FFmpeg output (remove 2>/dev/null)
# Check results directory
ls -lh tests/results/

# Inspect output with ffprobe
ffprobe tests/results/test-libx264.mp4
```

## Performance Tracking

Performance results are saved as JSON for regression tracking:

```json
{
  "platform": "darwin-arm64",
  "timestamp": "2026-01-04T12:00:00Z",
  "benchmarks": {
    "libx264": {
      "preset": "medium",
      "fps": 42.3,
      "psnr": 42.5,
      "file_size_mb": 1.2
    }
  }
}
```

Use `git diff` to compare performance across commits.

## Continuous Integration

### Build Matrix Integration

Tests run for every platform in CI:

```yaml
strategy:
  matrix:
    platform: [darwin-x64, darwin-arm64, linux-x64-glibc, ...]

steps:
  - name: Build FFmpeg
    run: ./build/orchestrator.sh ${{ matrix.platform }}

  - name: Run Tests
    run: ./tests/run-all-tests.sh --platform ${{ matrix.platform }}
```

### Failure Handling

- Tests continue after individual failures
- Full summary provided at end
- Test results uploaded as artifacts
- Non-zero exit code if any tests fail

## Maintenance

### Updating Thresholds

If tests consistently fail due to performance changes:

```bash
# Edit test-config.sh
MAX_ENCODING_TIME=(
  ["libx265"]=90  # Increased from 60
)
```

Commit threshold changes with rationale.

### Adding New Codecs

1. Update codec matrix in `test-config.sh`:
   ```bash
   VIDEO_CODECS+=(
     "librav1e:av1:mp4"
   )
   ```

2. Add encoding time threshold:
   ```bash
   MAX_ENCODING_TIME["librav1e"]=180
   ```

3. Tests will automatically include new codec

## Troubleshooting

### Fixtures Not Generating

**Symptom:** "lavfi source not found"

**Solution:** Your FFmpeg build may have `--disable-filters`. Re-build with filters enabled.

### Tests Timeout on ARM

**Symptom:** ARMv7 tests exceed time limits

**Solution:** ARM builds are slower. Adjust `MAX_ENCODING_TIME` for ARM platforms or reduce test video duration.

### Inconsistent Results

**Symptom:** Performance varies between runs

**Solution:**
- Close background applications
- Use `nice -n -10` for consistent CPU priority
- Run multiple iterations and average

## See Also

- [Build Configuration](../BUILD-CONFIG.md) - Customize codec selection
- [Performance Guide](../PERFORMANCE.md) - Optimization techniques
- [Verification Script](../build/verify.sh) - Binary validation
