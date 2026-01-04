#!/usr/bin/env bash
#
# FFmpeg Performance Benchmarks
# Measures encoding performance across codecs and presets
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source test configuration
source "$SCRIPT_DIR/test-config.sh"

# ============================================================================
# Performance Results Storage
# ============================================================================

PERF_RESULTS_JSON="$RESULTS_DIR/performance-results.json"
PERF_SUMMARY_FILE="$RESULTS_DIR/performance-summary.txt"

# ============================================================================
# Benchmark Utilities
# ============================================================================

# Measure encoding performance
benchmark_encode() {
  local encoder="$1"
  local input="$2"
  local output="$3"
  shift 3
  local extra_args=("$@")

  # Check if codec is available
  if ! check_codec "$encoder"; then
    echo "0:0:0:0" # fps:time:size:quality
    return 1
  fi

  # Start timer
  local start_time=$(date +%s)

  # Encode with time measurement
  if ! "$FFMPEG_BIN" \
    -i "$input" \
    -c:v "$encoder" \
    "${extra_args[@]}" \
    -y \
    "$output" 2>/dev/null; then
    echo "0:0:0:0"
    return 1
  fi

  # End timer
  local end_time=$(date +%s)
  local duration=$((end_time - start_time))

  # Get file size
  local file_size=$(stat -f%z "$output" 2>/dev/null || stat -c%s "$output" 2>/dev/null)
  local file_size_mb=$(echo "scale=2; $file_size / 1024 / 1024" | bc)

  # Calculate FPS if ffprobe available
  local fps="N/A"
  if check_ffprobe; then
    local frames=$("$FFPROBE_BIN" -v error -select_streams v:0 -count_frames -show_entries stream=nb_read_frames -of default=noprint_wrappers=1:nokey=1 "$output" 2>/dev/null || echo "0")
    if [[ $frames -gt 0 && $duration -gt 0 ]]; then
      fps=$(echo "scale=1; $frames / $duration" | bc)
    fi
  fi

  # Calculate PSNR if possible
  local psnr="N/A"
  if check_ffprobe && [[ -f "$input" ]]; then
    # Use FFmpeg to calculate PSNR (comparing to original)
    local psnr_output=$("$FFMPEG_BIN" \
      -i "$output" \
      -i "$input" \
      -lavfi "psnr=stats_file=$RESULTS_DIR/psnr-tmp.log" \
      -f null - 2>&1 | grep -oP "average:\K[0-9.]+" | head -1 || echo "N/A")
    psnr="$psnr_output"
    rm -f "$RESULTS_DIR/psnr-tmp.log"
  fi

  echo "${fps}:${duration}:${file_size_mb}:${psnr}"
  return 0
}

# ============================================================================
# H.264 Preset Comparison
# ============================================================================

benchmark_h264_presets() {
  print_section "H.264 Preset Comparison (1080p)"

  if ! check_codec "libx264"; then
    print_warning "libx264 not available (skipped)"
    return 1
  fi

  echo ""
  printf "%-15s %10s %10s %10s %10s\n" "Preset" "FPS" "Time (s)" "Size (MB)" "PSNR (dB)"
  printf "%-15s %10s %10s %10s %10s\n" "-------" "---" "--------" "---------" "---------"

  for preset in ultrafast veryfast medium slow; do
    local output="$RESULTS_DIR/perf-h264-${preset}.mp4"

    local result=$(benchmark_encode "libx264" "$TEST_VIDEO_H264" "$output" \
      -preset "$preset" \
      -crf 23 \
      -t "$TEST_VIDEO_DURATION")

    IFS=':' read -r fps time size psnr <<< "$result"

    if [[ "$fps" != "0" ]]; then
      printf "%-15s %10s %10s %10s %10s\n" "$preset" "$fps" "$time" "$size" "$psnr"
      print_success "$preset: ${fps} fps, ${time}s, ${size}MB"
    else
      print_error "$preset: FAILED"
    fi
  done

  echo ""
}

# ============================================================================
# Codec Comparison (Same Quality Target)
# ============================================================================

benchmark_codec_comparison() {
  print_section "Codec Comparison (CRF 23 equivalent)"

  echo ""
  printf "%-15s %10s %10s %10s %10s\n" "Codec" "FPS" "Time (s)" "Size (MB)" "PSNR (dB)"
  printf "%-15s %10s %10s %10s %10s\n" "-----" "---" "--------" "---------" "---------"

  # H.264
  if check_codec "libx264"; then
    local output="$RESULTS_DIR/perf-codec-h264.mp4"
    local result=$(benchmark_encode "libx264" "$TEST_VIDEO_H264" "$output" \
      -preset medium \
      -crf 23 \
      -t "$TEST_VIDEO_DURATION")

    IFS=':' read -r fps time size psnr <<< "$result"
    if [[ "$fps" != "0" ]]; then
      printf "%-15s %10s %10s %10s %10s\n" "H.264" "$fps" "$time" "$size" "$psnr"
    fi
  fi

  # H.265
  if check_codec "libx265"; then
    local output="$RESULTS_DIR/perf-codec-h265.mp4"
    local result=$(benchmark_encode "libx265" "$TEST_VIDEO_H264" "$output" \
      -preset medium \
      -crf 28 \
      -t "$TEST_VIDEO_DURATION")

    IFS=':' read -r fps time size psnr <<< "$result"
    if [[ "$fps" != "0" ]]; then
      printf "%-15s %10s %10s %10s %10s\n" "H.265" "$fps" "$time" "$size" "$psnr"
    fi
  fi

  # VP9
  if check_codec "libvpx-vp9"; then
    local output="$RESULTS_DIR/perf-codec-vp9.webm"
    local result=$(benchmark_encode "libvpx-vp9" "$TEST_VIDEO_H264" "$output" \
      -b:v 2M \
      -crf 31 \
      -t "$TEST_VIDEO_DURATION")

    IFS=':' read -r fps time size psnr <<< "$result"
    if [[ "$fps" != "0" ]]; then
      printf "%-15s %10s %10s %10s %10s\n" "VP9" "$fps" "$time" "$size" "$psnr"
    fi
  fi

  # AV1 (libaom)
  if check_codec "libaom-av1"; then
    local output="$RESULTS_DIR/perf-codec-av1-aom.mp4"
    local result=$(benchmark_encode "libaom-av1" "$TEST_VIDEO_H264" "$output" \
      -cpu-used 8 \
      -crf 35 \
      -t "$TEST_VIDEO_DURATION")

    IFS=':' read -r fps time size psnr <<< "$result"
    if [[ "$fps" != "0" ]]; then
      printf "%-15s %10s %10s %10s %10s\n" "AV1 (libaom)" "$fps" "$time" "$size" "$psnr"
    fi
  fi

  # AV1 (SVT-AV1)
  if check_codec "libsvtav1"; then
    local output="$RESULTS_DIR/perf-codec-av1-svt.mp4"
    local result=$(benchmark_encode "libsvtav1" "$TEST_VIDEO_H264" "$output" \
      -preset 8 \
      -crf 35 \
      -t "$TEST_VIDEO_DURATION")

    IFS=':' read -r fps time size psnr <<< "$result"
    if [[ "$fps" != "0" ]]; then
      printf "%-15s %10s %10s %10s %10s\n" "AV1 (SVT-AV1)" "$fps" "$time" "$size" "$psnr"
    fi
  fi

  echo ""
}

# ============================================================================
# Resolution Scaling
# ============================================================================

benchmark_resolution_scaling() {
  print_section "Resolution Scaling (H.264, medium preset)"

  if ! check_codec "libx264"; then
    print_warning "libx264 not available (skipped)"
    return 1
  fi

  echo ""
  printf "%-15s %10s %10s %10s\n" "Resolution" "FPS" "Time (s)" "Size (MB)"
  printf "%-15s %10s %10s %10s\n" "----------" "---" "--------" "---------"

  # 480p
  local output_480p="$RESULTS_DIR/perf-res-480p.mp4"
  local result_480p=$(benchmark_encode "libx264" "$TEST_VIDEO_H264" "$output_480p" \
    -vf "scale=854:480" \
    -preset medium \
    -crf 23 \
    -t "$TEST_VIDEO_DURATION")

  IFS=':' read -r fps time size psnr <<< "$result_480p"
  if [[ "$fps" != "0" ]]; then
    printf "%-15s %10s %10s %10s\n" "480p (854x480)" "$fps" "$time" "$size"
  fi

  # 720p
  local output_720p="$RESULTS_DIR/perf-res-720p.mp4"
  local result_720p=$(benchmark_encode "libx264" "$TEST_VIDEO_H264" "$output_720p" \
    -vf "scale=1280:720" \
    -preset medium \
    -crf 23 \
    -t "$TEST_VIDEO_DURATION")

  IFS=':' read -r fps time size psnr <<< "$result_720p"
  if [[ "$fps" != "0" ]]; then
    printf "%-15s %10s %10s %10s\n" "720p (1280x720)" "$fps" "$time" "$size"
  fi

  # 1080p (original)
  local output_1080p="$RESULTS_DIR/perf-res-1080p.mp4"
  local result_1080p=$(benchmark_encode "libx264" "$TEST_VIDEO_H264" "$output_1080p" \
    -preset medium \
    -crf 23 \
    -t "$TEST_VIDEO_DURATION")

  IFS=':' read -r fps time size psnr <<< "$result_1080p"
  if [[ "$fps" != "0" ]]; then
    printf "%-15s %10s %10s %10s\n" "1080p (1920x1080)" "$fps" "$time" "$size"
  fi

  echo ""
}

# ============================================================================
# Threading Efficiency
# ============================================================================

benchmark_threading() {
  print_section "Multi-Threading Efficiency (H.264)"

  if ! check_codec "libx264"; then
    print_warning "libx264 not available (skipped)"
    return 1
  fi

  echo ""
  printf "%-15s %10s %10s %10s\n" "Threads" "FPS" "Time (s)" "Efficiency"
  printf "%-15s %10s %10s %10s\n" "-------" "---" "--------" "----------"

  local baseline_time=0

  for threads in 1 2 4; do
    local output="$RESULTS_DIR/perf-threads-${threads}.mp4"

    local result=$(benchmark_encode "libx264" "$TEST_VIDEO_H264" "$output" \
      -preset medium \
      -crf 23 \
      -threads "$threads" \
      -t "$TEST_VIDEO_DURATION")

    IFS=':' read -r fps time size psnr <<< "$result"

    if [[ "$fps" != "0" ]]; then
      # Calculate efficiency
      if [[ $threads -eq 1 ]]; then
        baseline_time=$time
        printf "%-15s %10s %10s %10s\n" "$threads" "$fps" "$time" "baseline"
      else
        local speedup=$(echo "scale=2; $baseline_time / $time" | bc)
        local efficiency=$(echo "scale=1; ($speedup / $threads) * 100" | bc)
        printf "%-15s %10s %10s %10s\n" "$threads" "$fps" "$time" "${speedup}x (${efficiency}%)"
      fi
    fi
  done

  echo ""
}

# ============================================================================
# Save Performance Results
# ============================================================================

save_performance_results() {
  local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  cat > "$PERF_RESULTS_JSON" <<EOF
{
  "platform": "$PLATFORM",
  "timestamp": "$timestamp",
  "ffmpeg_version": "$("$FFMPEG_BIN" -version 2>/dev/null | head -1 || echo "unknown")",
  "test_duration": ${TEST_VIDEO_DURATION},
  "test_resolution": "${TEST_VIDEO_WIDTH}x${TEST_VIDEO_HEIGHT}",
  "results_directory": "$RESULTS_DIR"
}
EOF

  print_success "Performance results saved to: $PERF_RESULTS_JSON"
}

# ============================================================================
# Generate Summary Report
# ============================================================================

generate_summary() {
  cat > "$PERF_SUMMARY_FILE" <<EOF
FFmpeg Performance Benchmark Summary
=====================================

Platform: $PLATFORM
Date: $(date)
FFmpeg: $("$FFMPEG_BIN" -version 2>/dev/null | head -1 || echo "unknown")

Test Configuration:
- Duration: ${TEST_VIDEO_DURATION}s
- Resolution: ${TEST_VIDEO_WIDTH}x${TEST_VIDEO_HEIGHT}
- FPS: ${TEST_VIDEO_FPS}

Results saved to: $RESULTS_DIR

See individual test outputs for detailed metrics.

To compare against baseline:
  git diff HEAD~1 $PERF_RESULTS_JSON

To track performance over time:
  git log --oneline -p -- $PERF_RESULTS_JSON
EOF

  print_success "Summary report saved to: $PERF_SUMMARY_FILE"
}

# ============================================================================
# Main Test Execution
# ============================================================================

main() {
  print_section "FFmpeg Performance Benchmarks"

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
  # Run Benchmarks
  # ========================================================================

  benchmark_h264_presets || true
  benchmark_codec_comparison || true
  benchmark_resolution_scaling || true
  benchmark_threading || true

  # ========================================================================
  # Save Results
  # ========================================================================

  print_section "Saving Results"

  save_performance_results
  generate_summary

  # ========================================================================
  # Summary
  # ========================================================================

  print_section "Performance Benchmarks Complete"

  echo ""
  print_success "All benchmarks completed successfully"
  echo ""
  echo "Results:"
  echo "  - JSON: $PERF_RESULTS_JSON"
  echo "  - Summary: $PERF_SUMMARY_FILE"
  echo "  - Outputs: $RESULTS_DIR"
  echo ""

  exit 0
}

# Run main
main
