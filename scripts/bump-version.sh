#!/usr/bin/env bash
#
# bump-version.sh - Bump package version across all npm packages
#
# Usage: ./bump-version.sh <major|minor|patch>
#
# Bumps the version in all npm/ffmpeg* packages, commits the change,
# and creates a git tag. Requires a clean working directory.

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
  local current
  current=$(jq -r '.version' npm/ffmpeg/package.json)

  local maj min pat
  IFS='.' read -r maj min pat <<< "${current}"

  case "${bump_type}" in
    major) maj=$((maj + 1)); min=0; pat=0 ;;
    minor) min=$((min + 1)); pat=0 ;;
    patch) pat=$((pat + 1)) ;;
  esac

  readonly new="${maj}.${min}.${pat}"

  echo "${current} → ${new}"

  local pkg
  for pkg in npm/ffmpeg npm/ffmpeg-lgpl npm/ffmpeg-gpl; do
    jq --arg v "${new}" \
      '.version = $v | .optionalDependencies |= with_entries(.value = $v)' \
      "${pkg}/package.json" > "${pkg}/package.json.tmp"
    mv "${pkg}/package.json.tmp" "${pkg}/package.json"
  done

  git add npm/*/package.json
  git commit -m "chore(release): v${new}"
  git tag "v${new}"

  echo "Tagged v${new} — run: git push origin master --tags"
}

main "$@"
