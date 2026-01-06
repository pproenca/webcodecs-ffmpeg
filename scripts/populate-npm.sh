#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# populate-npm.sh - Populate npm packages from build artifacts
# =============================================================================
# Usage: ./scripts/populate-npm.sh [--version VERSION]
#
# Reads from: artifacts/<platform>-<tier>/
# Writes to:  npm/<platform>[-tier]/
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
readonly PROJECT_ROOT
readonly NPM_DIR="${PROJECT_ROOT}/npm"
readonly ARTIFACTS_DIR="${PROJECT_ROOT}/artifacts"

readonly FFMPEG_VERSION="${FFMPEG_VERSION:-7.1.0}"

readonly TIERS=(bsd lgpl gpl)

declare -Ar PLATFORM_MAP=(
  ["darwin-arm64"]="darwin-arm64"
  # Future platforms:
  # ["darwin-x64"]="darwin-x64"
  # ["linux-x64"]="linux-x64"
  # ["linux-arm64"]="linux-arm64"
)

declare -Ar LICENSE_MAP=(
  ["bsd"]="BSD-3-Clause"
  ["lgpl"]="LGPL-2.1-or-later"
  ["gpl"]="GPL-2.0-or-later"
)

declare -Ar TIER_DESC=(
  ["bsd"]="BSD codecs (VP8/9, AV1, Opus, Vorbis)"
  ["lgpl"]="BSD + LGPL codecs (adds MP3)"
  ["gpl"]="All codecs including x264/x265"
)

# =============================================================================
# Functions
# =============================================================================

#######################################
# Log an informational message.
# Arguments:
#   $1 - Message to display
# Outputs:
#   Writes green-prefixed message to stdout
#######################################
log_info() {
  printf "\033[0;32m[INFO]\033[0m %s\n" "$1"
}

#######################################
# Log a warning message.
# Arguments:
#   $1 - Message to display
# Outputs:
#   Writes yellow-prefixed message to stdout
#######################################
log_warn() {
  printf "\033[1;33m[WARN]\033[0m %s\n" "$1"
}

#######################################
# Log an error message.
# Arguments:
#   $1 - Message to display
# Outputs:
#   Writes red-prefixed message to stdout
#######################################
log_error() {
  printf "\033[0;31m[ERROR]\033[0m %s\n" "$1"
}

#######################################
# Generate an index.js that exports the directory path.
# Arguments:
#   $1 - Directory path where index.js will be created
# Outputs:
#   Creates index.js file in the specified directory
#######################################
generate_index_js() {
  local dir="$1"
  mkdir -p "${dir}"
  cat >"${dir}/index.js" <<'EOF'
module.exports = __dirname;
EOF
}

#######################################
# Generate versions.json from artifacts or create a default one.
# Globals:
#   ARTIFACTS_DIR
#   FFMPEG_VERSION
# Arguments:
#   $1 - Output file path
#   $2 - Platform identifier (e.g., darwin-arm64)
#   $3 - Tier (bsd, lgpl, gpl)
# Outputs:
#   Creates versions.json at the specified path
#######################################
generate_versions_json() {
  local output_file="$1"
  local platform="$2"
  local tier="$3"
  local artifacts_json="${ARTIFACTS_DIR}/${platform}-${tier}/versions.json"

  if [[ -f "${artifacts_json}" ]]; then
    cp "${artifacts_json}" "${output_file}"
  else
    cat >"${output_file}" <<EOF
{
  "ffmpeg": "${FFMPEG_VERSION}",
  "platform": "${platform}",
  "tier": "${tier}",
  "built": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
  fi
}

#######################################
# Generate package.json for a platform-specific npm package.
# Globals:
#   LICENSE_MAP
#   TIER_DESC
#   FFMPEG_VERSION
# Arguments:
#   $1 - Directory where package.json will be created
#   $2 - Platform identifier (e.g., darwin-arm64)
#   $3 - Tier (bsd, lgpl, gpl)
# Outputs:
#   Creates package.json at the specified path
#######################################
generate_platform_package_json() {
  local dir="$1"
  local platform="$2"
  local tier="$3"

  local os="${platform%%-*}"  # darwin
  local cpu="${platform##*-}" # arm64
  local license="${LICENSE_MAP[$tier]}"
  local desc="${TIER_DESC[$tier]}"

  local pkg_name="@pproenca/ffmpeg-${platform}"
  local npm_subdir="${platform}"
  if [[ "${tier}" != "gpl" ]]; then
    pkg_name="${pkg_name}-${tier}"
    npm_subdir="${platform}-${tier}"
  fi

  cat >"${dir}/package.json" <<EOF
{
  "name": "${pkg_name}",
  "version": "${FFMPEG_VERSION}",
  "description": "Prebuilt FFmpeg with ${desc} for ${platform}",
  "author": "Pedro Proenca",
  "homepage": "https://github.com/pproenca/ffmpeg-prebuilds",
  "repository": {
    "type": "git",
    "url": "git+https://github.com/pproenca/ffmpeg-prebuilds.git",
    "directory": "npm/${npm_subdir}"
  },
  "license": "${license}",
  "preferUnplugged": true,
  "publishConfig": {
    "access": "public"
  },
  "files": [
    "lib",
    "include",
    "versions.json"
  ],
  "type": "commonjs",
  "exports": {
    "./lib": "./lib/index.js",
    "./include": "./include/index.js",
    "./package": "./package.json",
    "./versions": "./versions.json"
  },
  "os": [
    "${os}"
  ],
  "cpu": [
    "${cpu}"
  ]
}
EOF
}

#######################################
# Populate a platform-specific npm package from build artifacts.
# Globals:
#   ARTIFACTS_DIR
#   NPM_DIR
# Arguments:
#   $1 - Platform identifier (e.g., darwin-arm64)
#   $2 - Tier (bsd, lgpl, gpl)
# Returns:
#   0 on success or if artifacts not found (skipped)
#######################################
populate_platform() {
  local platform="$1"
  local tier="$2"
  local artifacts_src="${ARTIFACTS_DIR}/${platform}-${tier}"

  local npm_dir_name="${platform}"
  if [[ "${tier}" != "gpl" ]]; then
    npm_dir_name="${platform}-${tier}"
  fi
  local npm_dest="${NPM_DIR}/${npm_dir_name}"

  if [[ ! -d "${artifacts_src}" ]]; then
    log_warn "Artifacts not found: ${artifacts_src}, skipping"
    return 0
  fi

  log_info "Populating ${npm_dir_name} from ${artifacts_src}"

  rm -rf "${npm_dest:?}/lib" "${npm_dest:?}/include"
  mkdir -p "${npm_dest}/lib" "${npm_dest}/include"

  if [[ -d "${artifacts_src}/lib" ]]; then
    cp -a "${artifacts_src}/lib/"*.a "${npm_dest}/lib/" 2>/dev/null || true
  fi

  if [[ -d "${artifacts_src}/include" ]]; then
    cp -a "${artifacts_src}/include/"* "${npm_dest}/include/" 2>/dev/null || true
  fi

  generate_index_js "${npm_dest}/lib"
  generate_index_js "${npm_dest}/include"

  generate_versions_json "${npm_dest}/versions.json" "${platform}" "${tier}"

  generate_platform_package_json "${npm_dest}" "${platform}" "${tier}"

  log_info "  -> Populated ${npm_dir_name}"
}

#######################################
# Populate the dev npm package with FFmpeg headers.
# Searches for headers in any available tier's artifacts.
# Globals:
#   NPM_DIR
#   ARTIFACTS_DIR
#   PLATFORM_MAP
#   FFMPEG_VERSION
# Returns:
#   0 on success or if no headers found (skipped)
#######################################
populate_dev() {
  local dev_dir="${NPM_DIR}/dev"
  local header_src=""

  local tier
  local platform
  local src
  for tier in gpl lgpl bsd; do
    for platform in "${!PLATFORM_MAP[@]}"; do
      src="${ARTIFACTS_DIR}/${platform}-${tier}/include"
      if [[ -d "${src}" ]]; then
        header_src="${src}"
        break 2
      fi
    done
  done

  if [[ -z "${header_src}" ]]; then
    log_warn "No headers found for dev package"
    return 0
  fi

  log_info "Populating dev package from ${header_src}"

  rm -rf "${dev_dir:?}/include"
  mkdir -p "${dev_dir}/include"

  cp -a "${header_src}/"* "${dev_dir}/include/" 2>/dev/null || true
  generate_index_js "${dev_dir}/include"

  cat >"${dev_dir}/package.json" <<EOF
{
  "name": "@pproenca/ffmpeg-dev",
  "version": "${FFMPEG_VERSION}",
  "description": "FFmpeg headers for Node.js native addon development",
  "author": "Pedro Proenca",
  "homepage": "https://github.com/pproenca/ffmpeg-prebuilds",
  "repository": {
    "type": "git",
    "url": "git+https://github.com/pproenca/ffmpeg-prebuilds.git",
    "directory": "npm/dev"
  },
  "license": "MIT",
  "publishConfig": {
    "access": "public"
  },
  "files": [
    "include"
  ],
  "type": "commonjs",
  "exports": {
    "./include": "./include/index.js",
    "./package": "./package.json"
  }
}
EOF

  log_info "  -> Populated dev package"
}

# =============================================================================
# Main
# =============================================================================

#######################################
# Main entry point.
# Populates all npm packages from build artifacts for each
# platform and tier combination.
# Globals:
#   ARTIFACTS_DIR
#   NPM_DIR
#   FFMPEG_VERSION
#   PLATFORM_MAP
#   TIERS
#######################################
main() {
  log_info "Populating npm packages..."
  log_info "  Artifacts: ${ARTIFACTS_DIR}"
  log_info "  NPM dir:   ${NPM_DIR}"
  log_info "  Version:   ${FFMPEG_VERSION}"

  if [[ ! -f "${NPM_DIR}/package.json" ]]; then
    cat >"${NPM_DIR}/package.json" <<'EOF'
{
  "private": true,
  "workspaces": [
    "dev",
    "darwin-arm64",
    "darwin-arm64-lgpl",
    "darwin-arm64-bsd"
  ]
}
EOF
  fi

  local platform
  local tier
  for platform in "${!PLATFORM_MAP[@]}"; do
    for tier in "${TIERS[@]}"; do
      populate_platform "${platform}" "${tier}"
    done
  done

  populate_dev

  log_info "Done!"
}

main "$@"
