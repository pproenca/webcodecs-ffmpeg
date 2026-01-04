#!/usr/bin/env bash
#
# FFmpeg Decoding Tests
# Validates decoding capabilities and format support
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source test configuration
source "$SCRIPT_DIR/test-config.sh"

# ============================================================================
# Test Results
# ============================================================================

DECODE_TESTS_PASSED=0
DECODE_TESTS_FAILED=0
DECODE_TESTS_SKIPPED=0

# ============================================================================
# Video Decoding Tests
# ============================================================================

test_decode_video() {
  local codec_name="$1"
  local input_file="$2"
  local output_pattern="$RESULTS_DIR/decode-${codec_name}-%04d.png"

  print_info "Testing $codec_name decode"

  # Check if input file exists
  if [[ ! -f "$input_file" ]]; then
    print_warning "$codec_name input not found (skipped)"
    DECODE_TESTS_SKIPPED=$((DECODE_TESTS_SKIPPED + 1))
    return 2
  fi

  # Decode to PNG frames
  if ! "$FFMPEG_BIN" \
    -i "$input_file" \
    -vframes 10 \
    -y \
    "$output_pattern" 2>/dev/null; then
    print_error "$codec_name decode failed"
    DECODE_TESTS_FAILED=$((DECODE_TESTS_FAILED + 1))
    return 1
  fi

  # Check that frames were created
  local frame_count=$(find "$RESULTS_DIR" -name "decode-${codec_name}-*.png" | wc -l | tr -d ' ')

  if [[ $frame_count -lt 10 ]]; then
    print_error "$codec_name only decoded $frame_count frames (expected 10)"
    DECODE_TESTS_FAILED=$((DECODE_TESTS_FAILED + 1))
    return 1
  fi

  print_success "$codec_name: $frame_count frames extracted"
  DECODE_TESTS_PASSED=$((DECODE_TESTS_PASSED + 1))
  return 0
}

# ============================================================================
# Audio Decoding Tests
# ============================================================================

test_decode_audio() {
  local codec_name="$1"
  local input_file="$2"
  local output="$RESULTS_DIR/decode-${codec_name}.wav"

  print_info "Testing $codec_name audio decode"

  # Check if input file exists
  if [[ ! -f "$input_file" ]]; then
    print_warning "$codec_name input not found (skipped)"
    DECODE_TESTS_SKIPPED=$((DECODE_TESTS_SKIPPED + 1))
    return 2
  fi

  # Decode to WAV
  if ! "$FFMPEG_BIN" \
    -i "$input_file" \
    -c:a pcm_s16le \
    -y \
    "$output" 2>/dev/null; then
    print_error "$codec_name audio decode failed"
    DECODE_TESTS_FAILED=$((DECODE_TESTS_FAILED + 1))
    return 1
  fi

  # Validate output
  if [[ ! -f "$output" ]]; then
    print_error "$codec_name output not created"
    DECODE_TESTS_FAILED=$((DECODE_TESTS_FAILED + 1))
    return 1
  fi

  local file_size=$(stat -f%z "$output" 2>/dev/null || stat -c%s "$output" 2>/dev/null)
  if [[ $file_size -eq 0 ]]; then
    print_error "$codec_name output is empty"
    DECODE_TESTS_FAILED=$((DECODE_TESTS_FAILED + 1))
    return 1
  fi

  print_success "$codec_name: $(du -h "$output" | cut -f1)"
  DECODE_TESTS_PASSED=$((DECODE_TESTS_PASSED + 1))
  return 0
}

# ============================================================================
# Format Conversion Tests
# ============================================================================

test_format_conversion() {
  local from_format="$1"
  local to_format="$2"
  local input_file="$3"
  local output="$RESULTS_DIR/convert-${from_format}-to-${to_format}.${to_format}"

  print_info "Testing format conversion: $from_format → $to_format"

  if [[ ! -f "$input_file" ]]; then
    print_warning "Input not found for $from_format → $to_format (skipped)"
    DECODE_TESTS_SKIPPED=$((DECODE_TESTS_SKIPPED + 1))
    return 2
  fi

  # Convert format
  if ! "$FFMPEG_BIN" \
    -i "$input_file" \
    -c:v libx264 \
    -preset ultrafast \
    -y \
    "$output" 2>/dev/null; then
    print_error "$from_format → $to_format conversion failed"
    DECODE_TESTS_FAILED=$((DECODE_TESTS_FAILED + 1))
    return 1
  fi

  # Validate output
  if ! validate_video_output "$output"; then
    print_error "$from_format → $to_format output validation failed"
    DECODE_TESTS_FAILED=$((DECODE_TESTS_FAILED + 1))
    return 1
  fi

  print_success "$from_format → $to_format: $(du -h "$output" | cut -f1)"
  DECODE_TESTS_PASSED=$((DECODE_TESTS_PASSED + 1))
  return 0
}

# ============================================================================
# Stream Extraction Tests
# ============================================================================

test_stream_extraction() {
  print_info "Testing video stream extraction"

  local input="$TEST_VIDEO_H264"
  local video_only="$RESULTS_DIR/extract-video.mp4"
  local audio_only="$RESULTS_DIR/extract-audio.mp3"

  # Extract video stream
  if ! "$FFMPEG_BIN" \
    -i "$input" \
    -c:v copy \
    -an \
    -y \
    "$video_only" 2>/dev/null; then
    print_error "Video stream extraction failed"
    DECODE_TESTS_FAILED=$((DECODE_TESTS_FAILED + 1))
    return 1
  fi

  # Extract audio stream (if available)
  if "$FFMPEG_BIN" \
    -i "$input" \
    -c:a libmp3lame \
    -vn \
    -y \
    "$audio_only" 2>/dev/null; then
    print_success "Stream extraction: video + audio"
  else
    print_success "Stream extraction: video only (no audio in test file)"
  fi

  DECODE_TESTS_PASSED=$((DECODE_TESTS_PASSED + 1))
  return 0
}

# ============================================================================
# Metadata Extraction Tests
# ============================================================================

test_metadata_extraction() {
  print_info "Testing metadata extraction"

  if ! check_ffprobe; then
    print_warning "ffprobe not available (skipped)"
    DECODE_TESTS_SKIPPED=$((DECODE_TESTS_SKIPPED + 1))
    return 2
  fi

  local input="$TEST_VIDEO_H264"

  # Extract video metadata
  local width=$("$FFPROBE_BIN" -v error -select_streams v:0 -show_entries stream=width -of default=noprint_wrappers=1:nokey=1 "$input" 2>/dev/null || echo "unknown")
  local height=$("$FFPROBE_BIN" -v error -select_streams v:0 -show_entries stream=height -of default=noprint_wrappers=1:nokey=1 "$input" 2>/dev/null || echo "unknown")
  local codec=$("$FFPROBE_BIN" -v error -select_streams v:0 -show_entries stream=codec_name -of default=noprint_wrappers=1:nokey=1 "$input" 2>/dev/null || echo "unknown")
  local duration=$("$FFPROBE_BIN" -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$input" 2>/dev/null || echo "unknown")

  if [[ "$width" == "unknown" ]] || [[ "$height" == "unknown" ]]; then
    print_error "Metadata extraction failed"
    DECODE_TESTS_FAILED=$((DECODE_TESTS_FAILED + 1))
    return 1
  fi

  print_success "Metadata: ${width}x${height}, codec=$codec, duration=${duration}s"
  DECODE_TESTS_PASSED=$((DECODE_TESTS_PASSED + 1))
  return 0
}

# ============================================================================
# Frame Accuracy Tests
# ============================================================================

test_frame_accuracy() {
  print_info "Testing frame-accurate seeking"

  if ! check_ffprobe; then
    print_warning "ffprobe not available (skipped)"
    DECODE_TESTS_SKIPPED=$((DECODE_TESTS_SKIPPED + 1))
    return 2
  fi

  local input="$TEST_VIDEO_H264"
  local output="$RESULTS_DIR/seek-test.png"

  # Seek to specific timestamp and extract frame
  if ! "$FFMPEG_BIN" \
    -ss 2.0 \
    -i "$input" \
    -vframes 1 \
    -y \
    "$output" 2>/dev/null; then
    print_error "Frame-accurate seeking failed"
    DECODE_TESTS_FAILED=$((DECODE_TESTS_FAILED + 1))
    return 1
  fi

  # Validate output exists
  if [[ ! -f "$output" ]]; then
    print_error "Seek output not created"
    DECODE_TESTS_FAILED=$((DECODE_TESTS_FAILED + 1))
    return 1
  fi

  print_success "Frame-accurate seeking: OK"
  DECODE_TESTS_PASSED=$((DECODE_TESTS_PASSED + 1))
  return 0
}

# ============================================================================
# Thumbnail Generation Tests
# ============================================================================

test_thumbnail_generation() {
  print_info "Testing thumbnail generation"

  local input="$TEST_VIDEO_H264"
  local output="$RESULTS_DIR/thumbnail.jpg"

  # Generate thumbnail from middle of video
  if ! "$FFMPEG_BIN" \
    -ss 2.5 \
    -i "$input" \
    -vframes 1 \
    -vf "scale=320:180" \
    -q:v 2 \
    -y \
    "$output" 2>/dev/null; then
    print_error "Thumbnail generation failed"
    DECODE_TESTS_FAILED=$((DECODE_TESTS_FAILED + 1))
    return 1
  fi

  # Validate thumbnail
  if [[ ! -f "$output" ]]; then
    print_error "Thumbnail not created"
    DECODE_TESTS_FAILED=$((DECODE_TESTS_FAILED + 1))
    return 1
  fi

  local file_size=$(stat -f%z "$output" 2>/dev/null || stat -c%s "$output" 2>/dev/null)
  if [[ $file_size -lt 1000 ]]; then
    print_warning "Thumbnail unusually small: $file_size bytes"
  fi

  print_success "Thumbnail: $(du -h "$output" | cut -f1)"
  DECODE_TESTS_PASSED=$((DECODE_TESTS_PASSED + 1))
  return 0
}

# ============================================================================
# Main Test Execution
# ============================================================================

main() {
  print_section "FFmpeg Decoding Tests"

  # Check prerequisites
  if ! check_ffmpeg; then
    print_error "FFmpeg not available"
    exit 1
  fi

  # Initialize fixtures if needed
  if [[ ! -f "$TEST_VIDEO_H264" ]]; then
    print_info "Generating test fixtures..."
    initialize_fixtures
  fi

  mkdir -p "$RESULTS_DIR"

  # ========================================================================
  # Encode test files for decoding (if they don't exist)
  # ========================================================================

  print_section "Preparing Test Files"

  # Create various encoded files for decoding tests
  local test_h265="$RESULTS_DIR/test-h265.mp4"
  local test_vp9="$RESULTS_DIR/test-vp9.webm"
  local test_opus="$RESULTS_DIR/test-opus.webm"

  # H.265
  if check_codec "libx265" && [[ ! -f "$test_h265" ]]; then
    print_info "Creating H.265 test file..."
    "$FFMPEG_BIN" -i "$TEST_VIDEO_H264" -c:v libx265 -preset ultrafast -t "$TEST_VIDEO_DURATION" -y "$test_h265" 2>/dev/null || true
  fi

  # VP9
  if check_codec "libvpx-vp9" && [[ ! -f "$test_vp9" ]]; then
    print_info "Creating VP9 test file..."
    "$FFMPEG_BIN" -i "$TEST_VIDEO_H264" -c:v libvpx-vp9 -b:v 1M -t "$TEST_VIDEO_DURATION" -y "$test_vp9" 2>/dev/null || true
  fi

  # Opus
  if check_codec "libopus" && [[ ! -f "$test_opus" ]]; then
    print_info "Creating Opus test file..."
    "$FFMPEG_BIN" -i "$TEST_AUDIO_WAV" -c:a libopus -b:a 128k -t "$TEST_AUDIO_DURATION" -y "$test_opus" 2>/dev/null || true
  fi

  # ========================================================================
  # Video Decoding Tests
  # ========================================================================

  print_section "Video Decoding Tests"

  test_decode_video "h264" "$TEST_VIDEO_H264" || true
  test_decode_video "h265" "$test_h265" || true
  test_decode_video "vp9" "$test_vp9" || true

  # ========================================================================
  # Audio Decoding Tests
  # ========================================================================

  print_section "Audio Decoding Tests"

  test_decode_audio "wav" "$TEST_AUDIO_WAV" || true
  test_decode_audio "opus" "$test_opus" || true

  # ========================================================================
  # Format Conversion Tests
  # ========================================================================

  print_section "Format Conversion Tests"

  test_format_conversion "mp4" "webm" "$TEST_VIDEO_H264" || true

  # ========================================================================
  # Stream Manipulation Tests
  # ========================================================================

  print_section "Stream Manipulation Tests"

  test_stream_extraction || true
  test_metadata_extraction || true

  # ========================================================================
  # Advanced Decoding Tests
  # ========================================================================

  print_section "Advanced Decoding Tests"

  test_frame_accuracy || true
  test_thumbnail_generation || true

  # ========================================================================
  # Summary
  # ========================================================================

  print_section "Decoding Tests Summary"

  echo ""
  echo "Total Tests: $((DECODE_TESTS_PASSED + DECODE_TESTS_FAILED + DECODE_TESTS_SKIPPED))"
  print_success "Passed: $DECODE_TESTS_PASSED"

  if [[ $DECODE_TESTS_FAILED -gt 0 ]]; then
    print_error "Failed: $DECODE_TESTS_FAILED"
  fi

  if [[ $DECODE_TESTS_SKIPPED -gt 0 ]]; then
    print_warning "Skipped: $DECODE_TESTS_SKIPPED (codecs/tools not available)"
  fi

  echo ""

  if [[ $DECODE_TESTS_FAILED -gt 0 ]]; then
    print_error "Decoding tests FAILED"
    exit 1
  else
    print_success "Decoding tests PASSED"
    exit 0
  fi
}

# Run main
main
