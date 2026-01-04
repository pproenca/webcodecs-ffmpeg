#!/usr/bin/env bash
#
# FFmpeg Encoding Tests
# Validates that all configured codecs can encode test media
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source test configuration
source "$SCRIPT_DIR/test-config.sh"

# ============================================================================
# Test Results
# ============================================================================

ENCODE_TESTS_PASSED=0
ENCODE_TESTS_FAILED=0
ENCODE_TESTS_SKIPPED=0

# ============================================================================
# Video Encoding Tests
# ============================================================================

test_encode_video() {
  local encoder="$1"
  local codec="$2"
  local container="$3"
  local output="$RESULTS_DIR/test-${encoder}.${container}"

  # Check if codec is available
  if ! check_codec "$encoder"; then
    print_warning "$encoder encoder not available (skipped)"
    ENCODE_TESTS_SKIPPED=$((ENCODE_TESTS_SKIPPED + 1))
    return 2
  fi

  # Get encoding time threshold
  local max_time="${MAX_ENCODING_TIME[$encoder]:-120}"

  print_info "Testing $encoder ($codec) → $container"

  # Start timer
  local start_time=$(date +%s)

  # Encode video
  if ! "$FFMPEG_BIN" \
    -i "$TEST_VIDEO_H264" \
    -c:v "$encoder" \
    -pix_fmt yuv420p \
    -t "$TEST_VIDEO_DURATION" \
    -y \
    "$output" 2>/dev/null; then
    print_error "$encoder encoding failed"
    ENCODE_TESTS_FAILED=$((ENCODE_TESTS_FAILED + 1))
    return 1
  fi

  # End timer
  local end_time=$(date +%s)
  local duration=$((end_time - start_time))

  # Validate output
  if ! validate_video_output "$output" "$codec"; then
    print_error "$encoder output validation failed"
    ENCODE_TESTS_FAILED=$((ENCODE_TESTS_FAILED + 1))
    return 1
  fi

  # Check encoding time
  if [[ $duration -gt $max_time ]]; then
    print_warning "$encoder took ${duration}s (threshold: ${max_time}s)"
  fi

  # Get encoding speed if ffprobe available
  if check_ffprobe; then
    local frames=$("$FFPROBE_BIN" -v error -select_streams v:0 -count_frames -show_entries stream=nb_read_frames -of default=noprint_wrappers=1:nokey=1 "$output" 2>/dev/null || echo "0")
    if [[ $frames -gt 0 ]]; then
      local fps=$(echo "scale=1; $frames / $duration" | bc 2>/dev/null || echo "N/A")
      print_success "$encoder: ${duration}s, ${fps} fps, $(du -h "$output" | cut -f1)"
    else
      print_success "$encoder: ${duration}s, $(du -h "$output" | cut -f1)"
    fi
  else
    print_success "$encoder: ${duration}s, $(du -h "$output" | cut -f1)"
  fi

  ENCODE_TESTS_PASSED=$((ENCODE_TESTS_PASSED + 1))
  return 0
}

# ============================================================================
# Audio Encoding Tests
# ============================================================================

test_encode_audio() {
  local encoder="$1"
  local codec="$2"
  local container="$3"
  local output="$RESULTS_DIR/test-${encoder}.${container}"

  # Check if codec is available
  if ! check_codec "$encoder"; then
    print_warning "$encoder encoder not available (skipped)"
    ENCODE_TESTS_SKIPPED=$((ENCODE_TESTS_SKIPPED + 1))
    return 2
  fi

  # Get encoding time threshold
  local max_time="${MAX_ENCODING_TIME[$encoder]:-30}"

  print_info "Testing $encoder ($codec) → $container"

  # Start timer
  local start_time=$(date +%s)

  # Encode audio
  if ! "$FFMPEG_BIN" \
    -i "$TEST_AUDIO_WAV" \
    -c:a "$encoder" \
    -t "$TEST_AUDIO_DURATION" \
    -y \
    "$output" 2>/dev/null; then
    print_error "$encoder encoding failed"
    ENCODE_TESTS_FAILED=$((ENCODE_TESTS_FAILED + 1))
    return 1
  fi

  # End timer
  local end_time=$(date +%s)
  local duration=$((end_time - start_time))

  # Validate output exists and has size
  if [[ ! -f "$output" ]]; then
    print_error "$encoder output file not created"
    ENCODE_TESTS_FAILED=$((ENCODE_TESTS_FAILED + 1))
    return 1
  fi

  local file_size=$(stat -f%z "$output" 2>/dev/null || stat -c%s "$output" 2>/dev/null)
  if [[ $file_size -eq 0 ]]; then
    print_error "$encoder output file is empty"
    ENCODE_TESTS_FAILED=$((ENCODE_TESTS_FAILED + 1))
    return 1
  fi

  # Check encoding time
  if [[ $duration -gt $max_time ]]; then
    print_warning "$encoder took ${duration}s (threshold: ${max_time}s)"
  fi

  print_success "$encoder: ${duration}s, $(du -h "$output" | cut -f1)"

  ENCODE_TESTS_PASSED=$((ENCODE_TESTS_PASSED + 1))
  return 0
}

# ============================================================================
# Subtitle Rendering Tests
# ============================================================================

test_subtitle_rendering() {
  print_info "Testing subtitle rendering (libass)"

  # Check if libass filter is available
  if ! "$FFMPEG_BIN" -hide_banner -filters 2>/dev/null | grep -q "ass"; then
    print_warning "Subtitle rendering not available (skipped)"
    ENCODE_TESTS_SKIPPED=$((ENCODE_TESTS_SKIPPED + 1))
    return 2
  fi

  # Create simple ASS subtitle file
  local subtitle_file="$RESULTS_DIR/test-subtitle.ass"
  cat > "$subtitle_file" <<'EOF'
[Script Info]
Title: Test Subtitles

[V4+ Styles]
Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
Style: Default,Arial,20,&H00FFFFFF,&H000088EF,&H00000000,&H00666666,-1,0,0,0,100,100,0,0,1,2,0,2,10,10,10,1

[Events]
Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
Dialogue: 0,0:00:00.00,0:00:05.00,Default,,0,0,0,,Test Subtitle
EOF

  local output="$RESULTS_DIR/test-subtitle-burn.mp4"

  # Burn subtitle into video
  if ! "$FFMPEG_BIN" \
    -i "$TEST_VIDEO_H264" \
    -vf "ass=$subtitle_file" \
    -c:v libx264 \
    -preset ultrafast \
    -t 5 \
    -y \
    "$output" 2>/dev/null; then
    print_error "Subtitle rendering failed"
    ENCODE_TESTS_FAILED=$((ENCODE_TESTS_FAILED + 1))
    return 1
  fi

  if ! validate_video_output "$output" "h264"; then
    print_error "Subtitle rendering output validation failed"
    ENCODE_TESTS_FAILED=$((ENCODE_TESTS_FAILED + 1))
    return 1
  fi

  print_success "Subtitle rendering: OK"
  ENCODE_TESTS_PASSED=$((ENCODE_TESTS_PASSED + 1))
  return 0
}

# ============================================================================
# Network Protocol Tests
# ============================================================================

test_network_protocols() {
  print_info "Testing network protocols"

  # Check if network protocols are enabled
  if ! "$FFMPEG_BIN" -hide_banner -protocols 2>/dev/null | grep -q "http"; then
    print_warning "Network protocols not enabled (expected for offline builds)"
    ENCODE_TESTS_SKIPPED=$((ENCODE_TESTS_SKIPPED + 1))
    return 2
  fi

  # Simple test: list protocols
  local protocols=$("$FFMPEG_BIN" -hide_banner -protocols 2>/dev/null | grep -E "http|https|rtmp" | wc -l | tr -d ' ')

  if [[ $protocols -gt 0 ]]; then
    print_success "Network protocols: $protocols protocols enabled"
    ENCODE_TESTS_PASSED=$((ENCODE_TESTS_PASSED + 1))
    return 0
  else
    print_warning "Network protocols enabled but none found"
    ENCODE_TESTS_SKIPPED=$((ENCODE_TESTS_SKIPPED + 1))
    return 2
  fi
}

# ============================================================================
# Main Test Execution
# ============================================================================

main() {
  print_section "FFmpeg Encoding Tests"

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
  # Video Encoding Tests
  # ========================================================================

  print_section "Video Encoding Tests"

  # Parse video codec matrix
  # Format: "encoder:codec:container"
  for codec_spec in "${VIDEO_CODECS[@]}"; do
    IFS=':' read -r encoder codec container <<< "$codec_spec"
    test_encode_video "$encoder" "$codec" "$container" || true
  done

  # ========================================================================
  # Audio Encoding Tests
  # ========================================================================

  print_section "Audio Encoding Tests"

  # Parse audio codec matrix
  # Format: "encoder:codec:container"
  for codec_spec in "${AUDIO_CODECS[@]}"; do
    IFS=':' read -r encoder codec container <<< "$codec_spec"
    test_encode_audio "$encoder" "$codec" "$container" || true
  done

  # ========================================================================
  # Feature Tests
  # ========================================================================

  print_section "Feature Tests"

  test_subtitle_rendering || true
  test_network_protocols || true

  # ========================================================================
  # Summary
  # ========================================================================

  print_section "Encoding Tests Summary"

  echo ""
  echo "Total Tests: $((ENCODE_TESTS_PASSED + ENCODE_TESTS_FAILED + ENCODE_TESTS_SKIPPED))"
  print_success "Passed: $ENCODE_TESTS_PASSED"

  if [[ $ENCODE_TESTS_FAILED -gt 0 ]]; then
    print_error "Failed: $ENCODE_TESTS_FAILED"
  fi

  if [[ $ENCODE_TESTS_SKIPPED -gt 0 ]]; then
    print_warning "Skipped: $ENCODE_TESTS_SKIPPED (codecs not available in this build)"
  fi

  echo ""

  if [[ $ENCODE_TESTS_FAILED -gt 0 ]]; then
    print_error "Encoding tests FAILED"
    exit 1
  else
    print_success "Encoding tests PASSED"
    exit 0
  fi
}

# Run main
main
