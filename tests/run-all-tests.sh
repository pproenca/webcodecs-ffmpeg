#!/usr/bin/env bash
#
# FFmpeg Prebuilds - Test Suite Runner
# Executes all functional tests and generates summary report
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source test configuration
source "$SCRIPT_DIR/test-config.sh"

# ============================================================================
# Test Results Tracking
# ============================================================================

TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

declare -a FAILED_TESTS=()
declare -a SKIPPED_TESTS=()

# ============================================================================
# Test Execution Functions
# ============================================================================

run_test_script() {
  local test_name="$1"
  local test_script="$2"

  echo ""
  print_section "Running: $test_name"

  if [[ ! -f "$test_script" ]]; then
    print_warning "Test script not found: $test_script"
    TESTS_SKIPPED=$((TESTS_SKIPPED + 1))
    SKIPPED_TESTS+=("$test_name (script not found)")
    return 1
  fi

  if ! bash "$test_script"; then
    print_error "$test_name FAILED"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    FAILED_TESTS+=("$test_name")
    return 1
  else
    print_success "$test_name PASSED"
    TESTS_PASSED=$((TESTS_PASSED + 1))
    return 0
  fi
}

# ============================================================================
# Main Test Suite
# ============================================================================

main() {
  print_section "FFmpeg Prebuilds - Functional Test Suite"

  echo "Platform: $PLATFORM"
  echo "FFmpeg: $FFMPEG_BIN"
  echo ""

  # Check prerequisites
  if ! check_ffmpeg; then
    print_error "FFmpeg binary not available. Cannot run tests."
    exit 1
  fi

  check_ffprobe || print_warning "FFprobe not available. Some validations will be skipped."

  # Initialize test fixtures
  if [[ ! -f "$TEST_VIDEO_RAW" ]] || [[ ! -f "$TEST_VIDEO_H264" ]] || [[ ! -f "$TEST_AUDIO_WAV" ]]; then
    initialize_fixtures
  else
    print_info "Test fixtures already initialized"
  fi

  # Cleanup previous results
  cleanup_results

  # ========================================================================
  # Run Test Suites
  # ========================================================================

  START_TIME=$(date +%s)

  # 1. Encoding Tests
  run_test_script "Encoding Tests" "$SCRIPT_DIR/encode-tests.sh" || true

  # 2. Decoding Tests
  run_test_script "Decoding Tests" "$SCRIPT_DIR/decode-tests.sh" || true

  # 3. Performance Benchmarks
  run_test_script "Performance Benchmarks" "$SCRIPT_DIR/performance-tests.sh" || true

  END_TIME=$(date +%s)
  DURATION=$((END_TIME - START_TIME))

  # ========================================================================
  # Test Summary
  # ========================================================================

  print_section "Test Summary"

  echo ""
  echo "Total Tests: $((TESTS_PASSED + TESTS_FAILED + TESTS_SKIPPED))"
  print_success "Passed: $TESTS_PASSED"

  if [[ $TESTS_FAILED -gt 0 ]]; then
    print_error "Failed: $TESTS_FAILED"
    echo ""
    echo "Failed tests:"
    for test in "${FAILED_TESTS[@]}"; do
      echo "  - $test"
    done
  fi

  if [[ $TESTS_SKIPPED -gt 0 ]]; then
    print_warning "Skipped: $TESTS_SKIPPED"
    echo ""
    echo "Skipped tests:"
    for test in "${SKIPPED_TESTS[@]}"; do
      echo "  - $test"
    done
  fi

  echo ""
  echo "Duration: ${DURATION}s"

  # ========================================================================
  # Exit Code
  # ========================================================================

  if [[ $TESTS_FAILED -gt 0 ]]; then
    print_error "Test suite FAILED"
    exit 1
  elif [[ $TESTS_PASSED -eq 0 ]]; then
    print_warning "No tests executed"
    exit 1
  else
    print_success "Test suite PASSED"
    exit 0
  fi
}

# ============================================================================
# Help
# ============================================================================

show_help() {
  cat <<EOF
FFmpeg Prebuilds - Test Suite Runner

Usage: $0 [options]

Options:
  -h, --help          Show this help message
  -c, --clean         Clean test results before running
  -f, --fixtures      Regenerate test fixtures
  -p, --platform PLATFORM
                      Test specific platform (default: auto-detect)

Platforms:
  darwin-x64          macOS Intel
  darwin-arm64        macOS Apple Silicon
  linux-x64-glibc     Linux x64 (glibc)
  linux-x64-musl      Linux x64 (musl)
  linux-arm64-glibc   Linux ARM64 (glibc)
  linux-arm64-musl    Linux ARM64 (musl)
  linux-armv7-glibc   Linux ARMv7 (glibc)
  windows-x64         Windows x64

Examples:
  $0                              # Run all tests on auto-detected platform
  $0 --clean                      # Clean and run all tests
  $0 --platform linux-x64-glibc   # Test specific platform

EOF
}

# ============================================================================
# Command-Line Arguments
# ============================================================================

CLEAN_RESULTS=false
REGENERATE_FIXTURES=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      show_help
      exit 0
      ;;
    -c|--clean)
      CLEAN_RESULTS=true
      shift
      ;;
    -f|--fixtures)
      REGENERATE_FIXTURES=true
      shift
      ;;
    -p|--platform)
      PLATFORM="$2"
      PLATFORM_ARTIFACT_DIR="$ARTIFACTS_DIR/$PLATFORM"
      FFMPEG_BIN="$PLATFORM_ARTIFACT_DIR/bin/ffmpeg"
      FFPROBE_BIN="$PLATFORM_ARTIFACT_DIR/bin/ffprobe"
      shift 2
      ;;
    *)
      echo "Unknown option: $1"
      show_help
      exit 1
      ;;
  esac
done

# Apply options
if [[ "$CLEAN_RESULTS" == "true" ]]; then
  cleanup_results
fi

if [[ "$REGENERATE_FIXTURES" == "true" ]]; then
  rm -f "$TEST_VIDEO_RAW" "$TEST_VIDEO_H264" "$TEST_AUDIO_WAV"
  initialize_fixtures
fi

# Run main test suite
main
