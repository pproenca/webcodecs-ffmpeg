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
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
NPM_DIR="${PROJECT_ROOT}/npm"
ARTIFACTS_DIR="${PROJECT_ROOT}/artifacts"

FFMPEG_VERSION="${FFMPEG_VERSION:-7.1.0}"

TIERS=(bsd lgpl gpl)

declare -A PLATFORM_MAP=(
  ["darwin-arm64"]="darwin-arm64"
  # Future platforms:
  # ["darwin-x64"]="darwin-x64"
  # ["linux-x64"]="linux-x64"
  # ["linux-arm64"]="linux-arm64"
)

# Tier to license mapping
declare -A LICENSE_MAP=(
  ["bsd"]="BSD-3-Clause"
  ["lgpl"]="LGPL-2.1-or-later"
  ["gpl"]="GPL-2.0-or-later"
)

# Tier descriptions
declare -A TIER_DESC=(
  ["bsd"]="BSD codecs (VP8/9, AV1, Opus, Vorbis)"
  ["lgpl"]="BSD + LGPL codecs (adds MP3)"
  ["gpl"]="All codecs including x264/x265"
)

# =============================================================================
# Functions
# =============================================================================

log_info() {
  printf "\033[0;32m[INFO]\033[0m %s\n" "$1"
}

log_warn() {
  printf "\033[1;33m[WARN]\033[0m %s\n" "$1"
}

log_error() {
  printf "\033[0;31m[ERROR]\033[0m %s\n" "$1"
}

generate_index_js() {
  local dir="$1"
  mkdir -p "${dir}"
  cat >"${dir}/index.js" <<'EOF'
module.exports = __dirname;
EOF
}

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

  rm -rf "${npm_dest}/lib" "${npm_dest}/include"
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

populate_dev() {
  local dev_dir="${NPM_DIR}/dev"
  local header_src=""

  for tier in gpl lgpl bsd; do
    for platform in "${!PLATFORM_MAP[@]}"; do
      local src="${ARTIFACTS_DIR}/${platform}-${tier}/include"
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

  rm -rf "${dev_dir}/include"
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

  for platform in "${!PLATFORM_MAP[@]}"; do
    for tier in "${TIERS[@]}"; do
      populate_platform "${platform}" "${tier}"
    done
  done

  populate_dev

  log_info "Done!"
}

main "$@"
