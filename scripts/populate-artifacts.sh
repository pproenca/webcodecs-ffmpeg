#!/usr/bin/env bash
#
# populate-artifacts.sh - Copy build artifacts to npm packages
#
# Usage: ./scripts/populate-artifacts.sh
#
# Copies lib/, pkgconfig/, and include/ from build artifacts to npm packages.
# Does NOT modify package.json files - those are committed to git and updated
# by bump-version.sh.
#
# Reads from: artifacts/<platform>-<tier>/
# Writes to:  npm/<package>/lib/, npm/dev/include/

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
readonly PROJECT_ROOT
readonly NPM_DIR="${PROJECT_ROOT}/npm"
readonly ARTIFACTS_DIR="${PROJECT_ROOT}/artifacts"

readonly TIERS=(free non-free)

declare -Ar PLATFORM_MAP=(
  ["darwin-arm64"]="darwin-arm64"
  ["darwin-x64"]="darwin-x64"
  ["linux-arm64"]="linux-arm64"
  ["linux-x64"]="linux-x64"
  ["linuxmusl-x64"]="linux-x64-musl"
)

#######################################
# Logging functions
#######################################
log_info() {
  printf "\033[0;32m[INFO]\033[0m %s\n" "$*"
}

log_warn() {
  printf "\033[1;33m[WARN]\033[0m %s\n" "$*"
}

log_error() {
  printf "\033[0;31m[ERROR]\033[0m %s\n" "$*" >&2
}

#######################################
# FFmpeg libraries in reverse dependency order (for static linking)
#######################################
readonly FFMPEG_LIBS="-lavfilter -lswscale -lswresample -lavformat -lavdevice -lavcodec -lavutil"

# Free tier codecs (LGPL-safe)
readonly CODECS_FREE="-lSvtAv1Enc -laom -ldav1d -lvpx -lopus -lvorbisenc -lvorbis -logg -lmp3lame"

# Non-free tier adds GPL codecs
readonly CODECS_NON_FREE="-lx265 -lx264"

# Platform-specific system libraries
readonly SYSTEM_DARWIN="-lpthread -lm -lz -lbz2 -liconv -lc++"
readonly SYSTEM_LINUX="-lpthread -lm -lz -lbz2 -ldl -lstdc++"
readonly SYSTEM_LINUX_MUSL="-lpthread -lm -lz -lbz2 -lstdc++"

# macOS frameworks
readonly FRAMEWORKS_DARWIN="-framework VideoToolbox -framework AudioToolbox -framework CoreMedia -framework CoreVideo -framework CoreFoundation -framework CoreServices -framework Security"

#######################################
# Query link flags from pkg-config .pc files.
# Uses the .pc files we ship to get accurate dependency information.
# Arguments:
#   $1 - pkg-config directory path
#   $2 - platform (darwin-arm64, linux-x64, linuxmusl-x64, etc.)
# Outputs: space-separated link flags to stdout (without -L prefix)
# Returns: 0 on success, 1 if pkg-config fails
#######################################
query_link_flags_from_pkgconfig() {
  local pc_dir="$1"
  local platform="$2"

  # Check if pkg-config is available
  if ! command -v pkg-config &>/dev/null; then
    return 1
  fi

  # Query FFmpeg libraries using pkg-config
  local ffmpeg_libs
  ffmpeg_libs=$(PKG_CONFIG_LIBDIR="${pc_dir}" pkg-config --static --libs \
    libavfilter libavformat libavdevice libavcodec libswresample libswscale libavutil 2>/dev/null)

  if [[ -z "${ffmpeg_libs}" ]]; then
    return 1
  fi

  # Remove any -L flags (we'll add our own)
  # Use a loop since bash parameter expansion can't handle this pattern well
  local cleaned=""
  for flag in ${ffmpeg_libs}; do
    [[ "${flag}" != -L* ]] && cleaned="${cleaned} ${flag}"
  done
  ffmpeg_libs="${cleaned# }"

  # Add platform-specific system libs and frameworks
  case "${platform}" in
    darwin-*)
      echo "${ffmpeg_libs} ${SYSTEM_DARWIN} ${FRAMEWORKS_DARWIN}"
      ;;
    linuxmusl-*)
      echo "${ffmpeg_libs} ${SYSTEM_LINUX_MUSL}"
      ;;
    linux-*)
      echo "${ffmpeg_libs} ${SYSTEM_LINUX}"
      ;;
    *)
      echo "${ffmpeg_libs}"
      ;;
  esac
}

#######################################
# Verify link flags against actual libraries in artifacts.
# Arguments:
#   $1 - lib directory path
#   $2 - space-separated list of -l flags
# Returns: 0 if all found, 1 if any missing
#######################################
verify_link_flags() {
  local lib_dir="$1"
  local flags="$2"
  local missing=0

  for flag in ${flags}; do
    # Skip non -l flags (frameworks, -L, etc.)
    [[ "${flag}" != -l* ]] && continue

    # Extract library name: -lfoo -> libfoo.a
    local lib_name="${flag#-l}"
    local lib_file="${lib_dir}/lib${lib_name}.a"

    if [[ ! -f "${lib_file}" ]]; then
      log_error "Link flag ${flag} has no matching library: ${lib_file}"
      missing=1
    fi
  done

  return ${missing}
}

#######################################
# Generate link-flags.js with platform-specific linker flags.
# Tries pkg-config first for accuracy, falls back to hardcoded constants.
# Arguments:
#   $1 - Output file path
#   $2 - Platform identifier (darwin-arm64, linux-x64, linuxmusl-x64, etc.)
#   $3 - Tier (free, non-free)
#######################################
generate_link_flags_js() {
  local output_file="$1"
  local platform="$2"
  local tier="$3"
  local lib_dir="${output_file%/*}/lib"
  local pc_dir="${lib_dir}/pkgconfig"

  local flags=""
  local source="hardcoded"

  # Try pkg-config first (preferred - uses actual .pc files)
  if [[ -d "${pc_dir}" ]]; then
    flags=$(query_link_flags_from_pkgconfig "${pc_dir}" "${platform}")
    if [[ -n "${flags}" ]]; then
      source="pkg-config"
      log_info "  Using pkg-config for link flags"
    fi
  fi

  # Fall back to hardcoded constants if pkg-config fails
  if [[ -z "${flags}" ]]; then
    log_warn "  pkg-config unavailable, using hardcoded flags"

    local system_libs=""
    local frameworks=""

    case "${platform}" in
      darwin-*)
        system_libs="${SYSTEM_DARWIN}"
        frameworks="${FRAMEWORKS_DARWIN}"
        ;;
      linuxmusl-*)
        system_libs="${SYSTEM_LINUX_MUSL}"
        ;;
      linux-*)
        system_libs="${SYSTEM_LINUX}"
        ;;
    esac

    local codecs="${CODECS_FREE}"
    if [[ "${tier}" == "non-free" ]]; then
      codecs="${CODECS_NON_FREE} ${CODECS_FREE}"
    fi

    flags="${FFMPEG_LIBS} ${codecs} ${system_libs} ${frameworks}"
  fi

  # Generate the JavaScript file
  cat >"${output_file}" <<EOF
// link-flags.js - Generated by populate-artifacts.sh (source: ${source})
const path = require('path');

const libDir = path.join(__dirname, 'lib');

module.exports = {
  libDir,
  flags: \`-L\${libDir} ${flags}\`
};
EOF
}

#######################################
# Generate an index.js that exports the directory path.
# Arguments:
#   $1 - Directory path where index.js will be created
#######################################
generate_index_js() {
  local dir="$1"
  mkdir -p "${dir}"
  cat >"${dir}/index.js" <<'EOF'
module.exports = __dirname;
EOF
}

#######################################
# Generate versions.json with build metadata.
# Arguments:
#   $1 - Output file path
#   $2 - Platform identifier (e.g., darwin-arm64)
#   $3 - Tier (free, non-free)
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
  "platform": "${platform}",
  "tier": "${tier}",
  "built": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
  fi
}

#######################################
# Populate a platform-specific npm package from build artifacts.
# Arguments:
#   $1 - Platform identifier (e.g., darwin-arm64)
#   $2 - Tier (free, non-free)
#######################################
populate_platform() {
  local platform="$1"
  local tier="$2"
  local artifacts_src="${ARTIFACTS_DIR}/${platform}-${tier}"

  # Determine npm package directory
  local npm_dir_name="webcodecs-ffmpeg-${platform}"
  if [[ "${tier}" != "free" ]]; then
    npm_dir_name="webcodecs-ffmpeg-${platform}-${tier}"
  fi
  local npm_dest="${NPM_DIR}/${npm_dir_name}"

  if [[ ! -d "${artifacts_src}" ]]; then
    log_warn "Artifacts not found: ${artifacts_src}, skipping"
    return 0
  fi

  if [[ ! -d "${npm_dest}" ]]; then
    log_warn "Package directory not found: ${npm_dest}, skipping"
    return 0
  fi

  log_info "Populating ${npm_dir_name} from ${artifacts_src}"

  rm -rf "${npm_dest:?}/lib"
  mkdir -p "${npm_dest}/lib"

  # Copy static libraries if they exist
  if [[ -d "${artifacts_src}/lib" ]]; then
    local -a lib_files
    lib_files=("${artifacts_src}/lib/"*.a)
    if [[ -e "${lib_files[0]}" ]]; then
      cp -a "${lib_files[@]}" "${npm_dest}/lib/"
    fi
  fi

  # Copy pkg-config files for native addon development
  if [[ -d "${artifacts_src}/lib/pkgconfig" ]]; then
    local -a pc_files
    pc_files=("${artifacts_src}/lib/pkgconfig/"*.pc)
    if [[ -e "${pc_files[0]}" ]]; then
      mkdir -p "${npm_dest}/lib/pkgconfig"
      cp -a "${pc_files[@]}" "${npm_dest}/lib/pkgconfig/"
      generate_index_js "${npm_dest}/lib/pkgconfig"
    fi
  fi

  generate_index_js "${npm_dest}/lib"
  generate_versions_json "${npm_dest}/versions.json" "${platform}" "${tier}"
  generate_link_flags_js "${npm_dest}/link-flags.js" "${platform}" "${tier}"

  # Verify link flags match actual libraries
  local codecs="${CODECS_FREE}"
  if [[ "${tier}" == "non-free" ]]; then
    codecs="${CODECS_NON_FREE} ${CODECS_FREE}"
  fi
  if ! verify_link_flags "${npm_dest}/lib" "${FFMPEG_LIBS} ${codecs}"; then
    log_error "Link flags verification failed for ${npm_dir_name}"
    return 1
  fi

  log_info "  -> Populated ${npm_dir_name}"
}

#######################################
# Populate the dev npm package with FFmpeg headers.
#######################################
populate_dev() {
  local dev_dir="${NPM_DIR}/dev"
  local header_src=""

  # Find headers from any available tier's artifacts
  local tier platform src
  for tier in non-free free; do
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

  if [[ ! -d "${dev_dir}" ]]; then
    log_warn "Dev package directory not found: ${dev_dir}"
    return 0
  fi

  log_info "Populating dev package from ${header_src}"

  rm -rf "${dev_dir:?}/include"
  mkdir -p "${dev_dir}/include"

  # Copy headers if they exist
  local -a header_files
  header_files=("${header_src}/"*)
  if [[ -e "${header_files[0]}" ]]; then
    cp -a "${header_files[@]}" "${dev_dir}/include/"
  fi
  generate_index_js "${dev_dir}/include"

  log_info "  -> Populated dev package"
}

#######################################
# Main entry point.
#######################################
main() {
  log_info "Populating npm packages with build artifacts..."
  log_info "  Artifacts: ${ARTIFACTS_DIR}"
  log_info "  NPM dir:   ${NPM_DIR}"

  local platform tier
  for platform in "${!PLATFORM_MAP[@]}"; do
    for tier in "${TIERS[@]}"; do
      populate_platform "${platform}" "${tier}"
    done
  done

  populate_dev

  log_info "Done!"
}

main "$@"
