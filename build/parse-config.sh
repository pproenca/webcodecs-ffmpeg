#!/usr/bin/env bash
#
# Parse build-config.json and generate FFmpeg configure flags
#
# Usage: ./parse-config.sh [config-file]
#   config-file: Path to build config JSON (default: ../build-config.json)
#
# Output: Space-separated configure flags for FFmpeg
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Get config file path (default to build-config.json, or use preset from presets/)
CONFIG_FILE="${1:-$PROJECT_ROOT/build-config.json}"

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "ERROR: Config file not found: $CONFIG_FILE" >&2
  echo "" >&2
  echo "Available presets:" >&2
  find "$PROJECT_ROOT/presets" -name "*.json" -type f -print0 2>/dev/null | xargs -0 -n1 basename >&2 || true
  exit 1
fi

# Check for jq dependency
if ! command -v jq &> /dev/null; then
  echo "ERROR: jq is required to parse build configuration" >&2
  echo "Install: apt-get install jq (Ubuntu) or brew install jq (macOS)" >&2
  exit 1
fi

echo "Parsing build configuration: $CONFIG_FILE" >&2
echo "" >&2

# Initialize flags array
CONFIGURE_FLAGS=()

# ============================================================================
# License flags (must come first)
# ============================================================================
echo "License configuration:" >&2

if jq -e '.license.gpl.enabled == true' "$CONFIG_FILE" &>/dev/null; then
  CONFIGURE_FLAGS+=("--enable-gpl")
  echo "  ✓ GPL enabled (x264, x265, xvid)" >&2
else
  echo "  ✗ GPL disabled (LGPL-only build)" >&2
fi

if jq -e '.license.version3.enabled == true' "$CONFIG_FILE" &>/dev/null; then
  CONFIGURE_FLAGS+=("--enable-version3")
  echo "  ✓ Version 3 licenses enabled" >&2
fi

if jq -e '.license.nonfree.enabled == true' "$CONFIG_FILE" &>/dev/null; then
  CONFIGURE_FLAGS+=("--enable-nonfree")
  echo "  ✓ Non-free enabled (fdk-aac)" >&2
fi

echo "" >&2

# ============================================================================
# Build configuration (static linking, etc.)
# ============================================================================
echo "Build configuration:" >&2

if jq -e '.build.static_linking.enabled == true' "$CONFIG_FILE" &>/dev/null; then
  CONFIGURE_FLAGS+=("--enable-static" "--disable-shared")
  echo "  ✓ Static linking enabled" >&2
fi

if jq -e '.build.debug_symbols.enabled == true' "$CONFIG_FILE" &>/dev/null; then
  CONFIGURE_FLAGS+=("--enable-debug=3")
  echo "  ✓ Debug symbols enabled" >&2
else
  CONFIGURE_FLAGS+=("--disable-debug")
  echo "  ✗ Debug symbols disabled" >&2
fi

# Always disable ffplay and doc
CONFIGURE_FLAGS+=("--disable-ffplay" "--disable-doc")

echo "" >&2

# ============================================================================
# Video codecs
# ============================================================================
echo "Video codecs:" >&2

ENABLED_VIDEO=0

# Process each video codec
for codec in h264 h265 vp8 vp9 av1 svt-av1 dav1d rav1e theora xvid; do
  if jq -e ".codecs.video.\"$codec\".enabled == true" "$CONFIG_FILE" &>/dev/null; then
    FLAG=$(jq -r ".codecs.video.\"$codec\".configure_flag" "$CONFIG_FILE")
    if [[ -n "$FLAG" && "$FLAG" != "null" ]]; then
      # Extract just the --enable-* flags (skip --enable-nonfree which is handled separately)
      for f in $FLAG; do
        if [[ "$f" == --enable-lib* ]]; then
          CONFIGURE_FLAGS+=("$f")
        fi
      done
      LIBRARY=$(jq -r ".codecs.video.\"$codec\".library" "$CONFIG_FILE")
      echo "  ✓ $codec ($LIBRARY)" >&2
      ENABLED_VIDEO=$((ENABLED_VIDEO + 1))
    fi
  fi
done

if [[ $ENABLED_VIDEO -eq 0 ]]; then
  echo "  ⚠ No video codecs enabled" >&2
fi

echo "" >&2

# ============================================================================
# Audio codecs
# ============================================================================
echo "Audio codecs:" >&2

ENABLED_AUDIO=0

# Process each audio codec
for codec in opus mp3 fdk-aac flac speex vorbis; do
  if jq -e ".codecs.audio.\"$codec\".enabled == true" "$CONFIG_FILE" &>/dev/null; then
    FLAG=$(jq -r ".codecs.audio.\"$codec\".configure_flag" "$CONFIG_FILE")
    if [[ -n "$FLAG" && "$FLAG" != "null" && "$FLAG" != "" ]]; then
      # Extract just the --enable-* flags
      for f in $FLAG; do
        if [[ "$f" == --enable-lib* ]]; then
          CONFIGURE_FLAGS+=("$f")
        fi
      done
      LIBRARY=$(jq -r ".codecs.audio.\"$codec\".library" "$CONFIG_FILE")
      echo "  ✓ $codec ($LIBRARY)" >&2
      ENABLED_AUDIO=$((ENABLED_AUDIO + 1))
    elif [[ "$codec" == "aac" ]]; then
      # Native AAC (no flag needed)
      echo "  ✓ $codec (native FFmpeg encoder)" >&2
      ENABLED_AUDIO=$((ENABLED_AUDIO + 1))
    fi
  fi
done

if [[ $ENABLED_AUDIO -eq 0 ]]; then
  echo "  ⚠ No audio codecs enabled" >&2
fi

echo "" >&2

# ============================================================================
# Features
# ============================================================================
echo "Features:" >&2

ENABLED_FEATURES=0

# Subtitle rendering
if jq -e '.features.subtitle_rendering.enabled == true' "$CONFIG_FILE" &>/dev/null; then
  CONFIGURE_FLAGS+=("--enable-libass" "--enable-libfreetype")
  echo "  ✓ Subtitle rendering (libass, libfreetype)" >&2
  ENABLED_FEATURES=$((ENABLED_FEATURES + 1))
fi

# Network protocols
if jq -e '.features.network.enabled == true' "$CONFIG_FILE" &>/dev/null; then
  # Extract configure flags from config
  FLAGS=$(jq -r '.features.network.configure_flags[]' "$CONFIG_FILE")
  for f in $FLAGS; do
    CONFIGURE_FLAGS+=("$f")
  done
  echo "  ✓ Network protocols enabled (OpenSSL, HTTPS, TLS)" >&2
  ENABLED_FEATURES=$((ENABLED_FEATURES + 1))
else
  CONFIGURE_FLAGS+=("--disable-network")
  echo "  ✗ Network protocols disabled" >&2
fi

if [[ $ENABLED_FEATURES -eq 0 ]]; then
  echo "  ℹ No additional features enabled" >&2
fi

echo "" >&2

# ============================================================================
# Optimizations
# ============================================================================
echo "Optimizations:" >&2

ENABLED_OPT=0

# Size optimization
if jq -e '.optimization.size.enabled == true' "$CONFIG_FILE" &>/dev/null; then
  CONFIGURE_FLAGS+=("--enable-small")
  echo "  ✓ Size optimization enabled (--enable-small)" >&2
  ENABLED_OPT=$((ENABLED_OPT + 1))
fi

# Speed optimization (runtime CPU detection)
if jq -e '.optimization.speed.enabled == true' "$CONFIG_FILE" &>/dev/null; then
  CONFIGURE_FLAGS+=("--enable-runtime-cpudetect")
  echo "  ✓ Speed optimization (runtime CPU detection)" >&2
  ENABLED_OPT=$((ENABLED_OPT + 1))
fi

# LTO
if jq -e '.optimization.lto.enabled == true' "$CONFIG_FILE" &>/dev/null; then
  CONFIGURE_FLAGS+=("--enable-lto")
  echo "  ✓ Link-Time Optimization enabled (+10-15 min build)" >&2
  ENABLED_OPT=$((ENABLED_OPT + 1))
fi

if [[ $ENABLED_OPT -eq 0 ]]; then
  echo "  ℹ No special optimizations enabled" >&2
fi

echo "" >&2

# ============================================================================
# PIC (Position Independent Code) - Always required for npm packages
# ============================================================================
CONFIGURE_FLAGS+=("--enable-pic")

# ============================================================================
# Output flags
# ============================================================================
echo "Generated configure flags:" >&2
echo "  ${CONFIGURE_FLAGS[*]}" >&2
echo "" >&2

# Output flags to stdout (for script consumption)
echo "${CONFIGURE_FLAGS[@]}"
