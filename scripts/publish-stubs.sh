#!/usr/bin/env bash
#
# publish-stubs.sh - Publish stub npm packages to reserve names
#
# Usage: ./scripts/publish-stubs.sh
#
# This creates minimal package.json files and publishes them to npm.
# Run once to initialize packages, then real releases will update them.

set -euo pipefail

VERSION="0.0.1"

PLATFORMS=(
  "darwin-arm64"
  "darwin-arm64-non-free"
  "darwin-x64"
  "darwin-x64-non-free"
  "linux-arm64"
  "linux-arm64-non-free"
  "linux-x64"
  "linux-x64-non-free"
)

cd "$(dirname "$0")/../npm"

# Platform packages
for platform in "${PLATFORMS[@]}"; do
  echo "Creating stub for webcodecs-ffmpeg-$platform..."
  mkdir -p "webcodecs-ffmpeg-$platform"

  # Determine license
  if [[ "$platform" == *"-non-free" ]]; then
    license="GPL-2.0-or-later"
    base="${platform%-non-free}"
  else
    license="LGPL-2.1-or-later"
    base="$platform"
  fi

  os="${base%%-*}"
  cpu="${base##*-}"

  cat > "webcodecs-ffmpeg-$platform/package.json" <<EOF
{
  "name": "@pproenca/webcodecs-ffmpeg-${platform}",
  "version": "${VERSION}",
  "description": "Prebuilt FFmpeg for ${platform} (stub - real binaries published on release)",
  "author": "Pedro Proenca",
  "license": "${license}",
  "repository": {
    "type": "git",
    "url": "git+https://github.com/pproenca/ffmpeg-prebuilds.git"
  },
  "publishConfig": {
    "access": "public"
  },
  "os": ["${os}"],
  "cpu": ["${cpu}"]
}
EOF

  echo "  Publishing @pproenca/webcodecs-ffmpeg-${platform}..."
  pnpm publish --filter "@pproenca/webcodecs-ffmpeg-${platform}" --access public || echo "  (may already exist)"
  sleep 5
done

# Dev package
echo "Creating stub for webcodecs-ffmpeg-dev..."
mkdir -p dev
cat > "dev/package.json" <<EOF
{
  "name": "@pproenca/webcodecs-ffmpeg-dev",
  "version": "${VERSION}",
  "description": "FFmpeg headers for native addon development (stub)",
  "author": "Pedro Proenca",
  "license": "MIT",
  "repository": {
    "type": "git",
    "url": "git+https://github.com/pproenca/ffmpeg-prebuilds.git"
  },
  "publishConfig": {
    "access": "public"
  }
}
EOF
pnpm publish --filter "@pproenca/webcodecs-ffmpeg-dev" --access public || echo "  (may already exist)"
sleep 5

# Meta packages
for tier in "" "-non-free"; do
  name="webcodecs-ffmpeg${tier}"
  echo "Creating stub for $name..."
  mkdir -p "$name"

  if [[ -z "$tier" ]]; then
    license="LGPL-2.1-or-later"
  else
    license="GPL-2.0-or-later"
  fi

  cat > "$name/package.json" <<EOF
{
  "name": "@pproenca/${name}",
  "version": "${VERSION}",
  "description": "Prebuilt FFmpeg - auto-selects platform (stub)",
  "author": "Pedro Proenca",
  "license": "${license}",
  "repository": {
    "type": "git",
    "url": "git+https://github.com/pproenca/ffmpeg-prebuilds.git"
  },
  "publishConfig": {
    "access": "public"
  }
}
EOF
  pnpm publish --filter "@pproenca/${name}" --access public || echo "  (may already exist)"
  sleep 5
done

echo "Done! Stub packages published."
