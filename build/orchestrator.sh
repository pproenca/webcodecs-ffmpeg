#!/usr/bin/env bash
#
# FFmpeg Prebuilds Build Orchestrator
# Delegates platform builds to specialized scripts
#
# Usage: ./build/orchestrator.sh <platform>
# Platforms: darwin-x64, darwin-arm64, linux-x64-glibc, linux-x64-musl

set -euo pipefail

PLATFORM="${1:-}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

if [[ -z "$PLATFORM" ]]; then
  echo "ERROR: Platform argument required"
  echo ""
  echo "Usage: $0 <platform>"
  echo ""
  echo "Supported platforms:"
  echo "  darwin-x64         - macOS Intel (x86_64)"
  echo "  darwin-arm64       - macOS Apple Silicon (arm64)"
  echo "  linux-x64-glibc    - Linux x64 with glibc (for .node linking)"
  echo "  linux-x64-musl     - Linux x64 with musl (fully static)"
  echo ""
  exit 1
fi

# Load versions from versions.properties
VERSIONS_FILE="$PROJECT_ROOT/versions.properties"
if [[ ! -f "$VERSIONS_FILE" ]]; then
  echo "ERROR: versions.properties not found at $VERSIONS_FILE"
  exit 1
fi

echo "Loading versions from $VERSIONS_FILE..."
while IFS='=' read -r key value; do
  # Skip comments and empty lines
  [[ "$key" =~ ^#.*$ || -z "$key" ]] && continue
  # Remove leading/trailing whitespace
  key="$(echo "$key" | xargs)"
  value="$(echo "$value" | xargs)"
  # Export for environment access
  export "$key=$value"
  echo "  $key=$value"
done < "$VERSIONS_FILE"

# Validate required versions
: "${FFMPEG_VERSION:?ERROR: FFMPEG_VERSION not set in versions.properties}"
: "${X264_VERSION:?ERROR: X264_VERSION not set in versions.properties}"
: "${X265_VERSION:?ERROR: X265_VERSION not set in versions.properties}"
: "${NASM_VERSION:?ERROR: NASM_VERSION not set in versions.properties}"

echo ""
echo "=========================================="
echo "Building FFmpeg Prebuilds"
echo "=========================================="
echo "Platform: $PLATFORM"
echo "FFmpeg:   $FFMPEG_VERSION"
echo "x264:     $X264_VERSION"
echo "x265:     $X265_VERSION"
echo "libvpx:   $LIBVPX_VERSION"
echo "libaom:   $LIBAOM_VERSION"
echo "=========================================="
echo ""

# Isolate pkg-config to only use our locally-built dependencies
# This prevents the build from accidentally using system libraries
export PKG_CONFIG_LIBDIR="${PROJECT_ROOT}/artifacts/${PLATFORM}/lib/pkgconfig"
unset PKG_CONFIG_PATH  # Don't use system packages

# Platform routing
case "$PLATFORM" in
  darwin-x64|darwin-arm64)
    echo "Executing macOS build script..."
    exec "$SCRIPT_DIR/macos.sh" "$PLATFORM"
    ;;
  linux-x64-glibc|linux-x64-musl)
    echo "Executing Linux Docker build script..."
    exec "$SCRIPT_DIR/linux.sh" "$PLATFORM"
    ;;
  *)
    echo "ERROR: Unknown platform '$PLATFORM'"
    echo "Supported: darwin-x64, darwin-arm64, linux-x64-glibc, linux-x64-musl"
    exit 1
    ;;
esac
