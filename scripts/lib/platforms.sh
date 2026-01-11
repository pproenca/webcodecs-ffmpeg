#!/usr/bin/env bash
# =============================================================================
# Shared Platform Definitions
# =============================================================================
# Centralized platform and license tier definitions used across build scripts.
#
# Usage:
#   source "${PROJECT_ROOT}/scripts/lib/platforms.sh"
# =============================================================================

# shellcheck disable=SC2034  # Variables are used by sourcing scripts

# Prevent double-sourcing
if [[ -n "${__PLATFORMS_SH_SOURCED:-}" ]]; then
  return 0
fi
readonly __PLATFORMS_SH_SOURCED=1

# =============================================================================
# Platform Definitions
# =============================================================================

# All supported build platforms
readonly PLATFORMS=(
  "darwin-arm64"
  "darwin-x64"
  "linux-arm64"
  "linux-x64"
  "linuxmusl-x64"
)

# Maps artifact platform names to npm package suffixes
# Key: artifact directory name (e.g., artifacts/linuxmusl-x64-free/)
# Value: npm package suffix (e.g., webcodecs-ffmpeg-linux-x64-musl)
declare -Ar PLATFORM_MAP=(
  ["darwin-arm64"]="darwin-arm64"
  ["darwin-x64"]="darwin-x64"
  ["linux-arm64"]="linux-arm64"
  ["linux-x64"]="linux-x64"
  ["linuxmusl-x64"]="linux-x64-musl"
)

# =============================================================================
# License Tier Definitions
# =============================================================================

# All supported license tiers
readonly LICENSE_TIERS=("free" "non-free")

# Maps tier names to SPDX license identifiers
declare -Ar LICENSE_MAP=(
  ["free"]="LGPL-2.1-or-later"
  ["non-free"]="GPL-2.0-or-later"
)

# Maps tier names to license file names in licenses/ directory
declare -Ar LICENSE_FILE_MAP=(
  ["free"]="LGPL-2.1.txt"
  ["non-free"]="GPL-2.0.txt"
)

# Human-readable descriptions for each tier
declare -Ar TIER_DESC=(
  ["free"]="LGPL-safe codecs (VP8/9, AV1, Opus, Vorbis, MP3)"
  ["non-free"]="all codecs including GPL x264/x265"
)

# =============================================================================
# Derived Constants
# =============================================================================

# Expected artifact count (platforms × license tiers)
readonly EXPECTED_ARTIFACT_COUNT=$(( ${#PLATFORMS[@]} * ${#LICENSE_TIERS[@]} ))
