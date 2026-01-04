#!/usr/bin/env bash
#
# Check for dependency updates
# Queries upstream repositories for new versions and updates versions.properties
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
VERSIONS_FILE="$PROJECT_ROOT/versions.properties"

# ============================================================================
# Colors
# ============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

# ============================================================================
# Version Comparison
# ============================================================================

# Compare semantic versions (returns 0 if v2 > v1, 1 otherwise)
version_gt() {
  local v1="$1"
  local v2="$2"

  # Remove 'v' or 'n' prefix
  v1="${v1#v}"
  v1="${v1#n}"
  v2="${v2#v}"
  v2="${v2#n}"

  # Use sort -V for version comparison
  if [[ "$(printf '%s\n' "$v1" "$v2" | sort -V | head -1)" == "$v1" && "$v1" != "$v2" ]]; then
    return 0  # v2 > v1
  else
    return 1  # v1 >= v2
  fi
}

# ============================================================================
# Upstream Version Fetchers
# ============================================================================

get_ffmpeg_latest() {
  # FFmpeg uses git tags like 'nX.Y'
  local latest=$(curl -s https://api.github.com/repos/FFmpeg/FFmpeg/tags \
    | jq -r '.[].name' \
    | grep '^n[0-9]' \
    | head -1)

  echo "$latest"
}

get_x264_latest() {
  # x264 doesn't use semantic versioning, uses stable branch
  # Get latest commit on stable branch
  local latest=$(curl -s https://code.videolan.org/api/v4/projects/536/repository/branches/stable \
    | jq -r '.commit.id' \
    | cut -c1-7)

  echo "stable"  # We pin to 'stable' branch
}

get_x265_latest() {
  # x265 uses tags like '4.0'
  local latest=$(curl -s https://bitbucket.org/api/2.0/repositories/multicoreware/x265_git/refs/tags \
    | jq -r '.values[].name' \
    | grep -E '^[0-9]+\.[0-9]+$' \
    | sort -V \
    | tail -1)

  echo "$latest"
}

get_vpx_latest() {
  # libvpx uses tags like 'v1.14.0'
  local latest=$(curl -s https://api.github.com/repos/webmproject/libvpx/tags \
    | jq -r '.[].name' \
    | grep '^v[0-9]' \
    | head -1)

  echo "$latest"
}

get_aom_latest() {
  # libaom uses tags like 'v3.9.1'
  local latest=$(curl -s https://api.github.com/repos/jbeich/aom/tags \
    | jq -r '.[].name' \
    | grep '^v[0-9]' \
    | head -1)

  echo "$latest"
}

get_svtav1_latest() {
  # SVT-AV1 uses tags like 'v2.3.0'
  local latest=$(curl -s https://api.github.com/repos/AOMediaCodec/SVT-AV1/tags \
    | jq -r '.[].name' \
    | grep '^v[0-9]' \
    | head -1)

  echo "$latest"
}

get_opus_latest() {
  # opus uses tags like 'v1.5.2'
  local latest=$(curl -s https://api.github.com/repos/xiph/opus/tags \
    | jq -r '.[].name' \
    | grep '^v[0-9]' \
    | head -1)

  echo "$latest"
}

get_lame_latest() {
  # LAME uses SVN, version 3.100 is current stable
  # Check SourceForge releases
  echo "3.100"  # Hard-coded as LAME rarely updates
}

get_fdkaac_latest() {
  # fdk-aac uses tags like 'v2.0.3'
  local latest=$(curl -s https://api.github.com/repos/mstorsjo/fdk-aac/tags \
    | jq -r '.[].name' \
    | grep '^v[0-9]' \
    | head -1)

  echo "$latest"
}

get_nasm_latest() {
  # NASM uses tags like 'nasm-2.16.03'
  local latest=$(curl -s https://api.github.com/repos/netwide-assembler/nasm/tags \
    | jq -r '.[].name' \
    | grep '^nasm-[0-9]' \
    | head -1 \
    | sed 's/^nasm-//')

  echo "$latest"
}

get_yasm_latest() {
  # Yasm uses tags like 'v1.3.0'
  local latest=$(curl -s https://api.github.com/repos/yasm/yasm/tags \
    | jq -r '.[].name' \
    | grep '^v[0-9]' \
    | head -1)

  echo "$latest"
}

get_cmake_latest() {
  # CMake uses tags like 'v3.30.5'
  local latest=$(curl -s https://api.github.com/repos/Kitware/CMake/tags \
    | jq -r '.[].name' \
    | grep '^v[0-9]' \
    | head -1)

  echo "$latest"
}

# ============================================================================
# Update Check
# ============================================================================

UPDATES_AVAILABLE=false
UPDATE_SUMMARY=""
UPDATED_COUNT=0

check_update() {
  local name="$1"
  local current_var="$2"
  local fetch_func="$3"

  # Get current version from versions.properties
  local current=$(grep "^${current_var}=" "$VERSIONS_FILE" | cut -d'=' -f2)

  if [[ -z "$current" ]]; then
    print_warning "$name: not found in versions.properties"
    return 1
  fi

  print_info "Checking $name (current: $current)..."

  # Get latest version
  local latest=$($fetch_func)

  if [[ -z "$latest" ]]; then
    print_error "$name: failed to fetch latest version"
    return 1
  fi

  # Compare versions
  if [[ "$current" == "$latest" ]]; then
    print_success "$name: up to date ($current)"
    return 0
  elif version_gt "$current" "$latest"; then
    print_warning "$name: update available: $current → $latest"

    # Update versions.properties
    sed -i.bak "s/^${current_var}=.*/${current_var}=${latest}/" "$VERSIONS_FILE"
    rm -f "${VERSIONS_FILE}.bak"

    # Add to summary
    UPDATE_SUMMARY="${UPDATE_SUMMARY}
- **$name**: $current → $latest"

    UPDATES_AVAILABLE=true
    UPDATED_COUNT=$((UPDATED_COUNT + 1))

    print_success "$name: updated to $latest"
    return 0
  else
    print_info "$name: current version is newer than upstream? ($current vs $latest)"
    return 0
  fi
}

# ============================================================================
# Main
# ============================================================================

main() {
  echo "=========================================="
  echo "Dependency Update Checker"
  echo "=========================================="
  echo ""

  # Check each dependency
  check_update "FFmpeg" "FFMPEG_VERSION" "get_ffmpeg_latest" || true
  check_update "x264" "X264_VERSION" "get_x264_latest" || true
  check_update "x265" "X265_VERSION" "get_x265_latest" || true
  check_update "libvpx" "VPX_VERSION" "get_vpx_latest" || true
  check_update "libaom" "AOM_VERSION" "get_aom_latest" || true
  check_update "SVT-AV1" "SVTAV1_VERSION" "get_svtav1_latest" || true
  check_update "Opus" "OPUS_VERSION" "get_opus_latest" || true
  check_update "LAME" "LAME_VERSION" "get_lame_latest" || true
  check_update "fdk-aac" "FDKAAC_VERSION" "get_fdkaac_latest" || true
  check_update "NASM" "NASM_VERSION" "get_nasm_latest" || true
  check_update "Yasm" "YASM_VERSION" "get_yasm_latest" || true
  check_update "CMake" "CMAKE_VERSION" "get_cmake_latest" || true

  echo ""
  echo "=========================================="
  echo "Summary"
  echo "=========================================="

  if [[ "$UPDATES_AVAILABLE" == "true" ]]; then
    print_warning "$UPDATED_COUNT update(s) available"
    echo ""
    echo "Updates:"
    echo "$UPDATE_SUMMARY"
    echo ""
    print_info "Updated versions.properties"

    # Set GitHub Actions output
    if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
      echo "updates_available=true" >> "$GITHUB_OUTPUT"
      {
        echo "update_summary<<EOF"
        echo "$UPDATE_SUMMARY"
        echo "EOF"
      } >> "$GITHUB_OUTPUT"
    fi

    exit 0
  else
    print_success "All dependencies up to date"

    # Set GitHub Actions output
    if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
      echo "updates_available=false" >> "$GITHUB_OUTPUT"
    fi

    exit 0
  fi
}

# Run main
main
