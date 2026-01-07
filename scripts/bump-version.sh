#!/usr/bin/env bash
#
# bump-version.sh - Create version tag for release
#
# Usage: ./bump-version.sh <major|minor|patch>
#
# Creates a git tag without modifying any files. The version is injected
# at publish time by populate-npm.sh using FFMPEG_VERSION from the tag.

set -euo pipefail

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
# Main entry point.
# Globals:
#   None
# Arguments:
#   $1 - Bump type: major, minor, or patch
# Outputs:
#   Writes version change and tag info to stdout
#######################################
main() {
  [[ "${1:-}" =~ ^(major|minor|patch)$ ]] || err "usage: $0 <major|minor|patch>"
  [[ -z "$(git status --porcelain)" ]] || err "working directory not clean"

  local bump_type="$1"

  # Get current version from latest tag
  local current
  current=$(git describe --tags --abbrev=0 2>/dev/null | sed 's/^v//' || echo "0.0.0")

  local maj min pat
  IFS='.' read -r maj min pat <<< "${current}"

  case "${bump_type}" in
    major) maj=$((maj + 1)); min=0; pat=0 ;;
    minor) min=$((min + 1)); pat=0 ;;
    patch) pat=$((pat + 1)) ;;
  esac

  local new="${maj}.${min}.${pat}"
  local tag="v${new}"

  echo "${current} → ${new}"

  # Create tag pointing to HEAD (no commit needed)
  git tag "${tag}"

  echo "Tagged ${tag}"
  echo ""
  echo "To release:"
  echo "  git push origin ${tag}"
  echo "  gh release create ${tag} --generate-notes"
}

main "$@"
