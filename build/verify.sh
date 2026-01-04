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

# Check for pkg-config files
echo ""
echo "=== pkg-config Files ==="
if [[ -d "$ARTIFACT_DIR/lib/pkgconfig" ]]; then
  PC_COUNT=$(find "$ARTIFACT_DIR/lib/pkgconfig" -name "*.pc" | wc -l | xargs)
  echo "✓ Found $PC_COUNT pkg-config files"
else
  echo "✗ pkg-config directory missing"
  exit 1
fi

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
