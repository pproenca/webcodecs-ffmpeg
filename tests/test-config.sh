#!/usr/bin/env bash
#
# Test Configuration - Common settings for all test scripts
#

set -euo pipefail

# ============================================================================
# Directory Structure
# ============================================================================
TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$TESTS_DIR/.." && pwd)"
ARTIFACTS_DIR="$PROJECT_ROOT/artifacts"
FIXTURES_DIR="$TESTS_DIR/fixtures"
RESULTS_DIR="$TESTS_DIR/results"

# ============================================================================
# Test Media Configuration
# ============================================================================

# Test video specifications
TEST_VIDEO_DURATION=5  # seconds
TEST_VIDEO_WIDTH=1920
TEST_VIDEO_HEIGHT=1080
TEST_VIDEO_FPS=30

# Test audio specifications
TEST_AUDIO_DURATION=5  # seconds
TEST_AUDIO_SAMPLE_RATE=48000
TEST_AUDIO_CHANNELS=2

# ============================================================================
# Test Fixtures
# ============================================================================

# Video fixtures
TEST_VIDEO_RAW="$FIXTURES_DIR/test-input.yuv"
TEST_VIDEO_H264="$FIXTURES_DIR/test-input.mp4"
TEST_AUDIO_WAV="$FIXTURES_DIR/test-input.wav"

# Expected output fixtures (for validation)
EXPECTED_OUTPUTS_DIR="$FIXTURES_DIR/expected"

# ============================================================================
# Codec Test Matrix
# ============================================================================

# Video codecs to test
declare -a VIDEO_CODECS=(
  "libx264:h264:mp4"
  "libx265:hevc:mp4"
  "libvpx:vp8:webm"
  "libvpx-vp9:vp9:webm"
  "libaom-av1:av1:mp4"
  "libsvtav1:av1:mp4"
)

# Audio codecs to test
declare -a AUDIO_CODECS=(
  "libopus:opus:webm"
  "libmp3lame:mp3:mp3"
  "aac:aac:m4a"
  "libfdk_aac:aac:m4a"
  "flac:flac:flac"
  "libvorbis:vorbis:ogg"
)

# ============================================================================
# Performance Test Presets
# ============================================================================

# Encoding presets for performance testing
declare -A H264_PRESETS=(
  ["ultrafast"]="ultrafast"
  ["veryfast"]="veryfast"
  ["medium"]="medium"
  ["slow"]="slow"
)

# ============================================================================
# Validation Thresholds
# ============================================================================

# Maximum acceptable file size (MB) for test outputs
MAX_OUTPUT_SIZE_MB=50

# Minimum acceptable PSNR (Peak Signal-to-Noise Ratio)
MIN_PSNR_DB=30.0

# Maximum acceptable encoding time (seconds) per codec
declare -A MAX_ENCODING_TIME=(
  ["libx264"]=30
  ["libx265"]=60
  ["libvpx"]=45
  ["libvpx-vp9"]=90
  ["libaom-av1"]=120
  ["libsvtav1"]=60
  ["libopus"]=10
  ["libmp3lame"]=10
  ["aac"]=10
  ["libfdk_aac"]=15
  ["flac"]=10
  ["libvorbis"]=10
)

# ============================================================================
# Platform Detection
# ============================================================================

detect_platform() {
  local os=$(uname -s)
  local arch=$(uname -m)

  case "$os" in
    Darwin)
      case "$arch" in
        x86_64) echo "darwin-x64" ;;
        arm64) echo "darwin-arm64" ;;
        *) echo "darwin-unknown" ;;
      esac
      ;;
    Linux)
      # Detect glibc vs musl
      if ldd --version 2>&1 | grep -q musl; then
        case "$arch" in
          x86_64) echo "linux-x64-musl" ;;
          aarch64) echo "linux-arm64-musl" ;;
          *) echo "linux-unknown-musl" ;;
        esac
      else
        case "$arch" in
          x86_64) echo "linux-x64-glibc" ;;
          aarch64) echo "linux-arm64-glibc" ;;
          armv7l) echo "linux-armv7-glibc" ;;
          *) echo "linux-unknown-glibc" ;;
        esac
      fi
      ;;
    MINGW*|MSYS*|CYGWIN*)
      echo "windows-x64"
      ;;
    *)
      echo "unknown"
      ;;
  esac
}

PLATFORM=$(detect_platform)
PLATFORM_ARTIFACT_DIR="$ARTIFACTS_DIR/$PLATFORM"
FFMPEG_BIN="$PLATFORM_ARTIFACT_DIR/bin/ffmpeg"
FFPROBE_BIN="$PLATFORM_ARTIFACT_DIR/bin/ffprobe"

# ============================================================================
# Color Output (for terminal display)
# ============================================================================

# ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Color output functions
print_success() {
  echo -e "${GREEN}✓${NC} $1"
}

print_error() {
  echo -e "${RED}✗${NC} $1"
}

print_warning() {
  echo -e "${YELLOW}⚠${NC} $1"
}

print_info() {
  echo -e "${BLUE}ℹ${NC} $1"
}

print_section() {
  echo ""
  echo "=========================================="
  echo "$1"
  echo "=========================================="
}

# ============================================================================
# Validation Functions
# ============================================================================

# Check if FFmpeg binary exists
check_ffmpeg() {
  if [[ ! -f "$FFMPEG_BIN" ]]; then
    print_error "FFmpeg binary not found: $FFMPEG_BIN"
    echo "Please build the platform first: ./build/orchestrator.sh $PLATFORM"
    return 1
  fi

  if [[ ! -x "$FFMPEG_BIN" ]]; then
    print_error "FFmpeg binary is not executable: $FFMPEG_BIN"
    return 1
  fi

  print_success "FFmpeg binary found: $FFMPEG_BIN"
  return 0
}

# Check if FFprobe binary exists
check_ffprobe() {
  if [[ ! -f "$FFPROBE_BIN" ]]; then
    print_warning "FFprobe binary not found: $FFPROBE_BIN"
    return 1
  fi

  if [[ ! -x "$FFPROBE_BIN" ]]; then
    print_warning "FFprobe binary is not executable: $FFPROBE_BIN"
    return 1
  fi

  print_success "FFprobe binary found: $FFPROBE_BIN"
  return 0
}

# Check if a codec is available in FFmpeg build
check_codec() {
  local codec="$1"

  if "$FFMPEG_BIN" -hide_banner -encoders 2>/dev/null | grep -q "$codec"; then
    return 0
  else
    return 1
  fi
}

# Validate video output file
validate_video_output() {
  local output_file="$1"
  local expected_codec="${2:-}"

  if [[ ! -f "$output_file" ]]; then
    print_error "Output file not found: $output_file"
    return 1
  fi

  # Check file size
  local file_size_bytes=$(stat -f%z "$output_file" 2>/dev/null || stat -c%s "$output_file" 2>/dev/null)
  local file_size_mb=$((file_size_bytes / 1024 / 1024))

  if [[ $file_size_mb -gt $MAX_OUTPUT_SIZE_MB ]]; then
    print_warning "Output file size ($file_size_mb MB) exceeds maximum ($MAX_OUTPUT_SIZE_MB MB)"
  fi

  # Validate with ffprobe if available
  if check_ffprobe; then
    local codec_name=$("$FFPROBE_BIN" -v error -select_streams v:0 -show_entries stream=codec_name -of default=noprint_wrappers=1:nokey=1 "$output_file" 2>/dev/null || echo "unknown")

    if [[ -n "$expected_codec" && "$codec_name" != "$expected_codec" ]]; then
      print_warning "Expected codec '$expected_codec', got '$codec_name'"
      return 1
    fi

    print_success "Output validated: $output_file ($codec_name, ${file_size_mb}MB)"
    return 0
  else
    print_info "Output file created: $output_file (${file_size_mb}MB, ffprobe not available for validation)"
    return 0
  fi
}

# ============================================================================
# Test Fixture Generation
# ============================================================================

# Generate test video (YUV raw format)
generate_test_video() {
  print_info "Generating test video fixture ($TEST_VIDEO_WIDTH x $TEST_VIDEO_HEIGHT, ${TEST_VIDEO_DURATION}s)..."

  mkdir -p "$FIXTURES_DIR"

  # Generate raw YUV using FFmpeg lavfi
  "$FFMPEG_BIN" \
    -f lavfi \
    -i "testsrc=duration=${TEST_VIDEO_DURATION}:size=${TEST_VIDEO_WIDTH}x${TEST_VIDEO_HEIGHT}:rate=${TEST_VIDEO_FPS}" \
    -pix_fmt yuv420p \
    -y \
    "$TEST_VIDEO_RAW" 2>/dev/null

  print_success "Test video generated: $TEST_VIDEO_RAW"
}

# Generate test video (H.264 encoded)
generate_test_h264() {
  print_info "Generating H.264 test video..."

  if [[ ! -f "$TEST_VIDEO_RAW" ]]; then
    generate_test_video
  fi

  # Encode to H.264
  "$FFMPEG_BIN" \
    -f rawvideo \
    -pix_fmt yuv420p \
    -s:v "${TEST_VIDEO_WIDTH}x${TEST_VIDEO_HEIGHT}" \
    -r "$TEST_VIDEO_FPS" \
    -i "$TEST_VIDEO_RAW" \
    -c:v libx264 \
    -preset fast \
    -crf 23 \
    -y \
    "$TEST_VIDEO_H264" 2>/dev/null

  print_success "H.264 test video generated: $TEST_VIDEO_H264"
}

# Generate test audio (WAV format)
generate_test_audio() {
  print_info "Generating test audio fixture (${TEST_AUDIO_SAMPLE_RATE}Hz, ${TEST_AUDIO_CHANNELS} channels, ${TEST_AUDIO_DURATION}s)..."

  mkdir -p "$FIXTURES_DIR"

  # Generate sine wave test audio
  "$FFMPEG_BIN" \
    -f lavfi \
    -i "sine=frequency=1000:duration=${TEST_AUDIO_DURATION}:sample_rate=${TEST_AUDIO_SAMPLE_RATE}" \
    -ac "$TEST_AUDIO_CHANNELS" \
    -y \
    "$TEST_AUDIO_WAV" 2>/dev/null

  print_success "Test audio generated: $TEST_AUDIO_WAV"
}

# Initialize all test fixtures
initialize_fixtures() {
  print_section "Initializing Test Fixtures"

  if [[ ! -f "$TEST_VIDEO_RAW" ]]; then
    generate_test_video
  else
    print_info "Test video already exists: $TEST_VIDEO_RAW"
  fi

  if [[ ! -f "$TEST_VIDEO_H264" ]]; then
    generate_test_h264
  else
    print_info "H.264 test video already exists: $TEST_VIDEO_H264"
  fi

  if [[ ! -f "$TEST_AUDIO_WAV" ]]; then
    generate_test_audio
  else
    print_info "Test audio already exists: $TEST_AUDIO_WAV"
  fi

  print_success "Test fixtures initialized"
}

# ============================================================================
# Cleanup Functions
# ============================================================================

cleanup_results() {
  print_info "Cleaning up test results..."
  rm -rf "$RESULTS_DIR"
  mkdir -p "$RESULTS_DIR"
  print_success "Test results cleaned"
}

# ============================================================================
# Export Configuration
# ============================================================================

export TESTS_DIR PROJECT_ROOT ARTIFACTS_DIR FIXTURES_DIR RESULTS_DIR
export PLATFORM PLATFORM_ARTIFACT_DIR FFMPEG_BIN FFPROBE_BIN
export TEST_VIDEO_RAW TEST_VIDEO_H264 TEST_AUDIO_WAV
export VIDEO_CODECS AUDIO_CODECS
export RED GREEN YELLOW BLUE NC
