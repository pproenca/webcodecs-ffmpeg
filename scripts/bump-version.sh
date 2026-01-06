#!/usr/bin/env bash
set -euo pipefail

die() { echo "error: $*" >&2; exit 1; }

[[ "${1:-}" =~ ^(major|minor|patch)$ ]] || die "usage: $0 <major|minor|patch>"
[[ -z "$(git status --porcelain)" ]] || die "working directory not clean"

BUMP_TYPE="$1"
CURRENT=$(jq -r '.version' npm/ffmpeg/package.json)
IFS='.' read -r MAJ MIN PAT <<< "$CURRENT"

case "$BUMP_TYPE" in
    major) MAJ=$((MAJ + 1)); MIN=0; PAT=0 ;;
    minor) MIN=$((MIN + 1)); PAT=0 ;;
    patch) PAT=$((PAT + 1)) ;;
esac
NEW="${MAJ}.${MIN}.${PAT}"

echo "$CURRENT → $NEW"

for pkg in npm/ffmpeg npm/ffmpeg-lgpl npm/ffmpeg-gpl; do
    jq --arg v "$NEW" '.version = $v | .optionalDependencies |= with_entries(.value = $v)' \
        "$pkg/package.json" > "$pkg/package.json.tmp"
    mv "$pkg/package.json.tmp" "$pkg/package.json"
done

git add npm/*/package.json
git commit -m "chore(release): v$NEW"
git tag "v$NEW"

echo "Tagged v$NEW — run: git push origin master --tags"
