#!/usr/bin/env bash
#
# bump-version.sh - Bump version in all package.json files
#
# Usage: ./bump-version.sh <major|minor|patch> [--dry-run]
#
# Updates all package.json files in the npm workspace, commits the changes,
# and creates a git tag. Package.json files are the source of truth for versions.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
readonly PROJECT_ROOT
readonly NPM_DIR="${PROJECT_ROOT}/npm"
readonly META_PACKAGE="${NPM_DIR}/webcodecs-ffmpeg/package.json"

DRY_RUN=false

#######################################
# Print error message and exit.
# Arguments:
#   $* - Error message
# Outputs:
#   Writes error to stderr
# Returns:
#   Exits with status 1
#######################################
err() {
  echo "error: $*" >&2
  exit 1
}

#######################################
# Print info message.
# Arguments:
#   $* - Message
# Outputs:
#   Writes message to stdout
#######################################
log() {
  echo "[bump] $*"
}

#######################################
# Get current version from meta package.json.
# Globals:
#   META_PACKAGE
# Outputs:
#   Writes version string to stdout
#######################################
get_current_version() {
  if [[ ! -f "${META_PACKAGE}" ]]; then
    err "Meta package not found: ${META_PACKAGE}"
  fi
  node -p "require('${META_PACKAGE}').version"
}

#######################################
# Verify all packages have the same version.
# Globals:
#   NPM_DIR
# Arguments:
#   $1 - Expected version
# Returns:
#   0 if all match, 1 if mismatch found
#######################################
verify_version_sync() {
  local expected="$1"
  local pkg version
  local has_error=false

  for pkg in "${NPM_DIR}"/*/package.json; do
    # Skip root package.json (private workspace root)
    [[ "$(basename "$(dirname "${pkg}")")" == "npm" ]] && continue

    version=$(node -p "require('${pkg}').version" 2>/dev/null || echo "MISSING")
    if [[ "${version}" != "${expected}" ]]; then
      echo "  Version mismatch: ${pkg} has ${version}, expected ${expected}" >&2
      has_error=true
    fi
  done

  [[ "${has_error}" == "false" ]]
}

#######################################
# Update version in a single package.json.
# Arguments:
#   $1 - Path to package.json
#   $2 - New version
#######################################
update_package_version() {
  local pkg="$1"
  local new_version="$2"

  # Use node to update version (handles JSON formatting)
  node -e "
    const fs = require('fs');
    const pkg = JSON.parse(fs.readFileSync('${pkg}', 'utf8'));
    pkg.version = '${new_version}';
    fs.writeFileSync('${pkg}', JSON.stringify(pkg, null, 2) + '\n');
  "
}

#######################################
# Update optionalDependencies in meta packages.
# Arguments:
#   $1 - Path to package.json
#   $2 - New version
#######################################
update_optional_deps() {
  local pkg="$1"
  local new_version="$2"

  node -e "
    const fs = require('fs');
    const pkg = JSON.parse(fs.readFileSync('${pkg}', 'utf8'));
    if (pkg.optionalDependencies) {
      for (const dep in pkg.optionalDependencies) {
        pkg.optionalDependencies[dep] = '${new_version}';
      }
    }
    fs.writeFileSync('${pkg}', JSON.stringify(pkg, null, 2) + '\n');
  "
}

#######################################
# Main entry point.
# Globals:
#   DRY_RUN
# Arguments:
#   $1 - Bump type: major, minor, or patch
#   $2 - Optional: --dry-run
#######################################
main() {
  local bump_type=""

  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      major|minor|patch)
        bump_type="$1"
        ;;
      --dry-run)
        DRY_RUN=true
        ;;
      *)
        err "usage: $0 <major|minor|patch> [--dry-run]"
        ;;
    esac
    shift
  done

  [[ -n "${bump_type}" ]] || err "usage: $0 <major|minor|patch> [--dry-run]"

  if [[ "${DRY_RUN}" == "false" ]]; then
    [[ -z "$(git status --porcelain)" ]] || err "working directory not clean"
  fi

  # Get current version from package.json (source of truth)
  local current
  current=$(get_current_version)
  log "Current version: ${current}"

  # Verify all packages are in sync before bumping
  if ! verify_version_sync "${current}"; then
    err "Package versions are out of sync. Fix manually before bumping."
  fi

  # Calculate new version
  local maj min pat
  IFS='.' read -r maj min pat <<< "${current}"

  case "${bump_type}" in
    major) maj=$((maj + 1)); min=0; pat=0 ;;
    minor) min=$((min + 1)); pat=0 ;;
    patch) pat=$((pat + 1)) ;;
  esac

  local new="${maj}.${min}.${pat}"
  local tag="v${new}"

  log "${current} → ${new}"

  if [[ "${DRY_RUN}" == "true" ]]; then
    log "[dry-run] Would update all package.json files to ${new}"
    log "[dry-run] Would commit: chore(release): ${tag}"
    log "[dry-run] Would create tag: ${tag}"
    return 0
  fi

  # Update all package.json files
  log "Updating package.json files..."
  local pkg
  for pkg in "${NPM_DIR}"/*/package.json; do
    # Skip root package.json
    [[ "$(basename "$(dirname "${pkg}")")" == "npm" ]] && continue

    update_package_version "${pkg}" "${new}"

    # Update optionalDependencies for meta packages
    local pkg_dir
    pkg_dir=$(dirname "${pkg}")
    if [[ "$(basename "${pkg_dir}")" == "webcodecs-ffmpeg" ]] || \
       [[ "$(basename "${pkg_dir}")" == "webcodecs-ffmpeg-non-free" ]]; then
      update_optional_deps "${pkg}" "${new}"
    fi
  done

  # Stage and commit
  log "Committing changes..."
  git add "${NPM_DIR}"/*/package.json
  git commit -m "chore(release): ${tag}"

  # Create tag
  log "Creating tag ${tag}..."
  git tag "${tag}"

  log ""
  log "Version bumped: ${current} → ${new}"
  log "Tag created: ${tag}"
  log ""
  log "To release:"
  log "  git push origin master ${tag}"
  log "  # Then run Release workflow from GitHub Actions"
}

main "$@"
