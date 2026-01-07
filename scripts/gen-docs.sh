#!/usr/bin/env bash
#
# gen-docs.sh - Extract configure help output for FFmpeg and codecs
#
# Downloads each dependency source and extracts its configure help documentation.
# Supports: Autoconf, CMake, Meson build systems
#
# Usage: ./gen-docs.sh
# Output: .claude/references/configure-help/<platform>/

set -euo pipefail

#######################################
# Cleanup handler for EXIT trap
# Globals:
#   WORK_DIR
# Arguments:
#   None
#######################################
cleanup() {
  local exit_code=$?
  if [[ -d "${WORK_DIR:-}" ]]; then
    rm -rf "${WORK_DIR}"
  fi
  exit "${exit_code}"
}
trap cleanup EXIT

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
readonly PROJECT_ROOT

# Output directories
readonly OUTPUT_BASE="${PROJECT_ROOT}/.claude/references/configure-help"
readonly PLATFORM="darwin-arm64"
readonly OUTPUT_DIR="${OUTPUT_BASE}/${PLATFORM}"
readonly CODECS_DIR="${OUTPUT_DIR}/codecs"

# Temp directory for downloads
WORK_DIR="${PROJECT_ROOT}/build/configure-help-tmp"

# Versions (from shared/versions.mk)
readonly FFMPEG_VERSION="n7.1"
readonly LIBVPX_VERSION="v1.15.0"
readonly AOM_VERSION="v3.12.0"
readonly DAV1D_VERSION="1.5.0"
readonly SVTAV1_VERSION="v2.3.0"
readonly OPUS_VERSION="v1.5.2"
readonly OGG_VERSION="v1.3.5"
readonly VORBIS_VERSION="v1.3.7"
readonly LAME_VERSION="3.100"
readonly X264_VERSION="stable"
readonly X264_REPO="https://code.videolan.org/videolan/x264.git"
readonly X265_VERSION="4.0"

#######################################
# Logging functions
# Arguments:
#   $* - Message to log
# Outputs:
#   Writes message to stdout (or stderr for log_error)
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
# Download and extract a tarball.
# Arguments:
#   $1 - Name identifier for the download
#   $2 - URL to download from
#   $3 - Destination directory
# Returns:
#   0 on success, 1 on download failure
#######################################
download_extract() {
  local name="$1"
  local url="$2"
  local dest="$3"

  log_info "Downloading ${name} from ${url}..."
  mkdir -p "${dest}"

  if ! curl -fSL --retry 3 -o "${dest}/${name}.tar.gz" "${url}"; then
    log_error "Failed to download ${name}"
    return 1
  fi

  tar -xzf "${dest}/${name}.tar.gz" -C "${dest}"
  rm -f "${dest}/${name}.tar.gz"
}

#######################################
# Shallow clone a git repository.
# Arguments:
#   $1 - Name identifier for the clone
#   $2 - Repository URL
#   $3 - Branch or tag to checkout
#   $4 - Destination directory
#######################################
git_clone_shallow() {
  local name="$1"
  local repo="$2"
  local branch="$3"
  local dest="$4"

  log_info "Cloning ${name} at ${branch}..."
  git clone --depth 1 --branch "${branch}" "${repo}" "${dest}/${name}"
}

#######################################
# Extract Autoconf configure help output.
# Arguments:
#   $1 - Project name
#   $2 - Source directory containing configure
#   $3 - Output file path
# Outputs:
#   Writes configure --help output to file
#######################################
extract_autoconf_help() {
  local name="$1"
  local src_dir="$2"
  local output_file="$3"

  log_info "Extracting ${name} configure help (Autoconf)..."

  {
    echo "# ${name} Configure Options"
    echo "# Build system: Autoconf"
    echo "# Generated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    echo ""
  } > "${output_file}"

  if [[ -x "${src_dir}/configure" ]]; then
    "${src_dir}/configure" --help >> "${output_file}" 2>&1 || true
  elif [[ -f "${src_dir}/configure.ac" ]] || [[ -f "${src_dir}/configure.in" ]]; then
    log_warn "${name}: Running autoreconf..."
    # shellcheck disable=SC2015  # Intentional: always succeed
    (cd "${src_dir}" && autoreconf -fi 2>/dev/null || true)
    if [[ -x "${src_dir}/configure" ]]; then
      "${src_dir}/configure" --help >> "${output_file}" 2>&1 || true
    else
      echo "# Configure script generation failed" >> "${output_file}"
    fi
  else
    echo "# No configure script found" >> "${output_file}"
  fi
}

#######################################
# Extract CMake cache variables and help.
# Arguments:
#   $1 - Project name
#   $2 - Source directory containing CMakeLists.txt
#   $3 - Output file path
# Outputs:
#   Writes cmake -LAH output to file
#######################################
extract_cmake_help() {
  local name="$1"
  local src_dir="$2"
  local output_file="$3"

  log_info "Extracting ${name} configure help (CMake)..."

  local build_dir="${src_dir}/_help_build"
  mkdir -p "${build_dir}"

  {
    echo "# ${name} CMake Options"
    echo "# Build system: CMake"
    echo "# Generated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    echo ""
  } > "${output_file}"

  # Run cmake -LAH to list all cache variables with help strings
  # shellcheck disable=SC2015  # Intentional: always succeed
  (cd "${build_dir}" && cmake -LAH "${src_dir}" 2>/dev/null || true) >> "${output_file}"

  rm -rf "${build_dir}"
}

#######################################
# Extract Meson project options.
# Arguments:
#   $1 - Project name
#   $2 - Source directory containing meson.build
#   $3 - Output file path
# Outputs:
#   Writes meson configure output to file
#######################################
extract_meson_help() {
  local name="$1"
  local src_dir="$2"
  local output_file="$3"

  log_info "Extracting ${name} configure help (Meson)..."

  local build_dir="${src_dir}/_help_build"

  {
    echo "# ${name} Meson Options"
    echo "# Build system: Meson"
    echo "# Generated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    echo ""
  } > "${output_file}"

  # Set up meson build directory to introspect options
  if (cd "${src_dir}" && meson setup "${build_dir}" 2>/dev/null); then
    meson configure "${build_dir}" >> "${output_file}" 2>&1 || true
    rm -rf "${build_dir}"
  else
    echo "# Meson setup failed - showing meson_options.txt if available" >> "${output_file}"
    if [[ -f "${src_dir}/meson_options.txt" ]]; then
      echo "" >> "${output_file}"
      cat "${src_dir}/meson_options.txt" >> "${output_file}"
    fi
  fi
}

#######################################
# Main entry point.
# Globals:
#   PLATFORM, OUTPUT_DIR, CODECS_DIR, WORK_DIR
#   All version constants
# Arguments:
#   None
# Outputs:
#   Writes extraction progress and summary to stdout
#######################################
main() {
  log_info "Starting configure help extraction..."
  log_info "Platform: ${PLATFORM}"

  # Clean and create directories
  rm -rf "${WORK_DIR}" "${OUTPUT_DIR}"
  mkdir -p "${WORK_DIR}" "${CODECS_DIR}"

  # FFmpeg
  log_info "Processing FFmpeg ${FFMPEG_VERSION}..."
  local ffmpeg_url="https://github.com/FFmpeg/FFmpeg/archive/refs/tags/${FFMPEG_VERSION}.tar.gz"
  download_extract "ffmpeg" "${ffmpeg_url}" "${WORK_DIR}"
  local ffmpeg_src="${WORK_DIR}/FFmpeg-${FFMPEG_VERSION}"
  extract_autoconf_help "FFmpeg" "${ffmpeg_src}" "${OUTPUT_DIR}/ffmpeg.txt"

  # Autoconf-based codecs: libvpx
  log_info "Processing libvpx ${LIBVPX_VERSION}..."
  local libvpx_url="https://github.com/webmproject/libvpx/archive/refs/tags/${LIBVPX_VERSION}.tar.gz"
  download_extract "libvpx" "${libvpx_url}" "${WORK_DIR}"
  extract_autoconf_help "libvpx" "${WORK_DIR}/libvpx-${LIBVPX_VERSION#v}" "${CODECS_DIR}/libvpx.txt"

  # opus
  log_info "Processing opus ${OPUS_VERSION}..."
  local opus_url="https://downloads.xiph.org/releases/opus/opus-${OPUS_VERSION#v}.tar.gz"
  download_extract "opus" "${opus_url}" "${WORK_DIR}"
  extract_autoconf_help "opus" "${WORK_DIR}/opus-${OPUS_VERSION#v}" "${CODECS_DIR}/opus.txt"

  # ogg
  log_info "Processing ogg ${OGG_VERSION}..."
  local ogg_url="https://downloads.xiph.org/releases/ogg/libogg-${OGG_VERSION#v}.tar.gz"
  download_extract "ogg" "${ogg_url}" "${WORK_DIR}"
  extract_autoconf_help "ogg" "${WORK_DIR}/libogg-${OGG_VERSION#v}" "${CODECS_DIR}/ogg.txt"

  # vorbis
  log_info "Processing vorbis ${VORBIS_VERSION}..."
  local vorbis_url="https://downloads.xiph.org/releases/vorbis/libvorbis-${VORBIS_VERSION#v}.tar.gz"
  download_extract "vorbis" "${vorbis_url}" "${WORK_DIR}"
  extract_autoconf_help "vorbis" "${WORK_DIR}/libvorbis-${VORBIS_VERSION#v}" "${CODECS_DIR}/vorbis.txt"

  # lame
  log_info "Processing lame ${LAME_VERSION}..."
  local lame_url="https://downloads.sourceforge.net/project/lame/lame/${LAME_VERSION}/lame-${LAME_VERSION}.tar.gz"
  download_extract "lame" "${lame_url}" "${WORK_DIR}"
  extract_autoconf_help "lame" "${WORK_DIR}/lame-${LAME_VERSION}" "${CODECS_DIR}/lame.txt"

  # x264 (git clone)
  log_info "Processing x264 ${X264_VERSION}..."
  git_clone_shallow "x264" "${X264_REPO}" "${X264_VERSION}" "${WORK_DIR}"
  extract_autoconf_help "x264" "${WORK_DIR}/x264" "${CODECS_DIR}/x264.txt"

  # CMake-based codecs: aom
  log_info "Processing aom ${AOM_VERSION}..."
  local aom_url="https://storage.googleapis.com/aom-releases/libaom-${AOM_VERSION#v}.tar.gz"
  download_extract "aom" "${aom_url}" "${WORK_DIR}"
  extract_cmake_help "aom" "${WORK_DIR}/libaom-${AOM_VERSION#v}" "${CODECS_DIR}/aom.txt"

  # svt-av1
  log_info "Processing svt-av1 ${SVTAV1_VERSION}..."
  local svtav1_url="https://gitlab.com/AOMediaCodec/SVT-AV1/-/archive/${SVTAV1_VERSION}/SVT-AV1-${SVTAV1_VERSION}.tar.gz"
  download_extract "svt-av1" "${svtav1_url}" "${WORK_DIR}"
  extract_cmake_help "svt-av1" "${WORK_DIR}/SVT-AV1-${SVTAV1_VERSION}" "${CODECS_DIR}/svt-av1.txt"

  # x265
  log_info "Processing x265 ${X265_VERSION}..."
  local x265_url="https://bitbucket.org/multicoreware/x265_git/downloads/x265_${X265_VERSION}.tar.gz"
  download_extract "x265" "${x265_url}" "${WORK_DIR}"
  extract_cmake_help "x265" "${WORK_DIR}/x265_${X265_VERSION}/source" "${CODECS_DIR}/x265.txt"

  # Meson-based codecs: dav1d
  log_info "Processing dav1d ${DAV1D_VERSION}..."
  local dav1d_url="https://code.videolan.org/videolan/dav1d/-/archive/${DAV1D_VERSION}/dav1d-${DAV1D_VERSION}.tar.gz"
  download_extract "dav1d" "${dav1d_url}" "${WORK_DIR}"
  extract_meson_help "dav1d" "${WORK_DIR}/dav1d-${DAV1D_VERSION}" "${CODECS_DIR}/dav1d.txt"

  # Cleanup
  log_info "Cleaning up temporary files..."
  rm -rf "${WORK_DIR}"

  # Summary
  echo ""
  log_info "Configure help extraction complete!"
  echo ""
  echo "Output files:"
  local file size
  while read -r file; do
    size=$(wc -c < "${file}" | tr -d ' ')
    printf "  %-50s %s bytes\n" "${file#"${PROJECT_ROOT}"/}" "${size}"
  done < <(find "${OUTPUT_DIR}" -name "*.txt" | sort)
}

main "$@"
