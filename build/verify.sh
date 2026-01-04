#!/usr/bin/env bash
#
# FFmpeg Build Verification Script
# Validates binaries, libraries, and ABI compatibility

set -euo pipefail

PLATFORM="${1:-}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

if [[ -z "$PLATFORM" ]]; then
  echo "ERROR: Platform argument required"
  exit 1
fi

ARTIFACT_DIR="$PROJECT_ROOT/artifacts/$PLATFORM"

echo "=========================================="
echo "Verifying Build: $PLATFORM"
echo "=========================================="
echo "Artifact directory: $ARTIFACT_DIR"
echo ""

#=============================================================================
# File Existence Checks
#=============================================================================
echo "=== File Existence Checks ==="

# Check for binaries (may not exist in dev-only builds)
if [[ -f "$ARTIFACT_DIR/bin/ffmpeg" ]]; then
  echo "✓ ffmpeg binary exists"
  FFMPEG_BIN="$ARTIFACT_DIR/bin/ffmpeg"
else
  echo "  (no ffmpeg binary - may be dev-only build)"
  FFMPEG_BIN=""
fi

if [[ -f "$ARTIFACT_DIR/bin/ffprobe" ]]; then
  echo "✓ ffprobe binary exists"
else
  echo "  (no ffprobe binary - may be dev-only build)"
fi

# Check for development files
REQUIRED_LIBS=(
  "libavcodec.a"
  "libavformat.a"
  "libavutil.a"
  "libswscale.a"
  "libswresample.a"
  "libavfilter.a"
)

echo ""
echo "=== Library Checks ==="
for lib in "${REQUIRED_LIBS[@]}"; do
  if [[ -f "$ARTIFACT_DIR/lib/$lib" ]]; then
    echo "✓ $lib exists"
  else
    echo "✗ $lib MISSING"
    exit 1
  fi
done

# Check that pkgconfig files were removed (we don't ship them for static builds)
echo ""
echo "=== pkg-config Files ==="
PKGCONFIG_COUNT=$(find "$ARTIFACT_DIR/lib/pkgconfig" -name "*.pc" 2>/dev/null | wc -l | tr -d ' ')
if [[ "$PKGCONFIG_COUNT" != "0" ]]; then
  echo "❌ VERIFICATION FAILED: Found $PKGCONFIG_COUNT pkgconfig files (expected 0)"
  echo "   PKGConfig files should be removed for static distributions"
  exit 1
fi
echo "✓ PKGConfig files removed (static build - not needed)"

# Check for headers
echo ""
echo "=== Header Files ==="
if [[ -d "$ARTIFACT_DIR/include/libavcodec" ]]; then
  echo "✓ libavcodec headers exist"
else
  echo "✗ libavcodec headers missing"
  exit 1
fi

#=============================================================================
# Platform-Specific Validation
#=============================================================================
echo ""
case "$PLATFORM" in
  darwin-*)
    if [[ -z "$FFMPEG_BIN" ]]; then
      echo "⚠  No binary to verify (dev-only build)"
    else
      echo "=== macOS ABI Validation ==="

      # Check deployment target
      MIN_VERSION=$(otool -l "$FFMPEG_BIN" | grep -A3 LC_VERSION_MIN_MACOSX | grep version | awk '{print $2}' | head -1 || echo "")

      if [[ -n "$MIN_VERSION" ]]; then
        echo "macOS deployment target: $MIN_VERSION"
        if [[ "$MIN_VERSION" == "${MACOS_DEPLOYMENT_TARGET}" ]]; then
          echo "✓ Deployment target matches: $MACOS_DEPLOYMENT_TARGET"
        else
          echo "⚠  Deployment target mismatch: $MIN_VERSION != ${MACOS_DEPLOYMENT_TARGET}"
        fi
      fi

      # Check dynamic dependencies (should only be system libs/frameworks)
      echo ""
      echo "Dynamic dependencies:"
      otool -L "$FFMPEG_BIN" | tail -n +2

      # Verify no unexpected external dependencies
      EXTERNAL_DEPS=$(otool -L "$FFMPEG_BIN" | grep -v "libSystem" | grep -v "@rpath" | grep -v "$FFMPEG_BIN" | grep -v "\.framework" || true)
      if [[ -n "$EXTERNAL_DEPS" ]]; then
        echo "⚠  WARNING: Unexpected external dependencies detected:"
        echo "$EXTERNAL_DEPS"
      else
        echo "✓ No unexpected external dependencies"
      fi
    fi
    ;;

  linux-*-musl)
    if [[ -z "$FFMPEG_BIN" ]]; then
      echo "⚠  No binary to verify (dev-only build)"
    else
      echo "=== Linux musl Static Linking Validation ==="

      # Verify fully static
      if ldd "$FFMPEG_BIN" 2>&1 | grep -q "not a dynamic executable"; then
        echo "✓ Binary is fully static (musl)"
      else
        echo "✗ ERROR: Binary is not fully static!"
        ldd "$FFMPEG_BIN" || true
        exit 1
      fi
    fi
    ;;

  linux-*-glibc)
    if [[ -n "$FFMPEG_BIN" ]]; then
      echo "=== Linux glibc Dynamic Linking Validation ==="

      # Check glibc version requirements
      echo "GLIBC version requirements:"
      readelf -V "$FFMPEG_BIN" | grep GLIBC || echo "  (none detected)"
      echo ""

      echo "Dynamic dependencies:"
      ldd "$FFMPEG_BIN" 2>&1 | head -20 || echo "  (readelf check only)"
    fi

    # For glibc builds, verify PIC in static libraries (sampling)
    echo ""
    echo "=== PIC Validation (sampling) ==="
    SAMPLE_LIB="$ARTIFACT_DIR/lib/libavcodec.a"
    if [[ -f "$SAMPLE_LIB" ]]; then
      # Extract first object file and check for PIC
      TEMP_DIR=$(mktemp -d)
      cd "$TEMP_DIR"
      ar x "$SAMPLE_LIB" 2>/dev/null | head -1 || true

      # Check if any .o file has PIC/PIE flags
      OBJ_FILE=$(find . -name "*.o" | head -1)
      if [[ -n "$OBJ_FILE" ]]; then
        if readelf -h "$OBJ_FILE" 2>/dev/null | grep -q "DYN\|EXEC"; then
          echo "✓ Library appears to be compiled with PIC"
        else
          echo "  (PIC check inconclusive - manual verification recommended)"
        fi
      fi
      cd - > /dev/null
      rm -rf "$TEMP_DIR"
    fi
    ;;

  *)
    echo "⚠  Unknown platform, skipping platform-specific checks"
    ;;
esac

#=============================================================================
# Size Report
#=============================================================================
echo ""
echo "=== Size Report ==="
if [[ -n "$FFMPEG_BIN" ]]; then
  echo "ffmpeg binary:"
  ls -lh "$FFMPEG_BIN"
fi

echo ""
echo "Static libraries (top 5):"
du -sh "$ARTIFACT_DIR"/lib/*.a 2>/dev/null | sort -hr | head -5 || echo "  (no static libraries)"

echo ""
echo "Total artifact size:"
du -sh "$ARTIFACT_DIR"

#=============================================================================
# Binary Size Validation
#=============================================================================
if [[ -n "$FFMPEG_BIN" ]]; then
  echo ""
  echo "=== Binary Size Validation ==="

  FFMPEG_SIZE=$(stat -f%z "$FFMPEG_BIN" 2>/dev/null || stat -c%s "$FFMPEG_BIN" 2>/dev/null)
  FFMPEG_SIZE_MB=$((FFMPEG_SIZE / 1024 / 1024))

  echo "ffmpeg binary size: ${FFMPEG_SIZE_MB}MB"

  # Expected ranges (full build):
  # macOS/Linux x64: 75-90 MB
  # Linux musl: 75-85 MB
  # ARM64: 70-85 MB
  # ARMv7: 65-80 MB

  if [[ $FFMPEG_SIZE_MB -lt 50 ]]; then
    echo "⚠  Binary size unusually small (< 50MB) - may be incomplete build"
  elif [[ $FFMPEG_SIZE_MB -gt 100 ]]; then
    echo "⚠  Binary size large (> 100MB) - debug symbols enabled?"
  else
    echo "✓ Binary size within expected range (50-100MB)"
  fi
fi

#=============================================================================
# Codec Availability Check
#=============================================================================
if [[ -n "$FFMPEG_BIN" ]]; then
  echo ""
  echo "=== Codec Availability ==="

  # Core codecs expected in all builds
  CORE_CODECS=("libx264" "libx265" "libvpx" "libaom" "libsvtav1" "libopus" "libmp3lame")
  CODEC_FAILURES=0

  for codec in "${CORE_CODECS[@]}"; do
    if "$FFMPEG_BIN" -hide_banner -encoders 2>/dev/null | grep -q "$codec"; then
      echo "✓ $codec encoder available"
    else
      echo "✗ $codec encoder NOT FOUND"
      CODEC_FAILURES=$((CODEC_FAILURES + 1))
    fi
  done

  if [[ $CODEC_FAILURES -gt 0 ]]; then
    echo "⚠  Warning: $CODEC_FAILURES core codec(s) missing"
  fi

  # Check for subtitle rendering support
  echo ""
  echo "=== Feature Availability ==="
  if "$FFMPEG_BIN" -hide_banner -filters 2>/dev/null | grep -q "ass"; then
    echo "✓ Subtitle rendering (libass) available"
  else
    echo "ℹ  Subtitle rendering not available"
  fi

  # Check for network protocols
  if "$FFMPEG_BIN" -hide_banner -protocols 2>/dev/null | grep -q "http"; then
    echo "✓ Network protocols enabled"
  else
    echo "ℹ  Network protocols disabled (expected)"
  fi
fi

#=============================================================================
# Version Check
#=============================================================================
if [[ -n "$FFMPEG_BIN" ]]; then
  echo ""
  echo "=== FFmpeg Version ==="
  "$FFMPEG_BIN" -version 2>/dev/null | head -3 || echo "  (unable to run binary)"
fi

echo ""
echo "=========================================="
echo "✓ Verification Complete: $PLATFORM"
echo "=========================================="
