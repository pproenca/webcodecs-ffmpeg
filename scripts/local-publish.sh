#!/usr/bin/env bash
#
# local-publish.sh - Publish npm packages from local machine using GitHub CI artifacts
#
# Usage:
#   ./scripts/local-publish.sh --run-id 12345678 --version v0.1.0
#   ./scripts/local-publish.sh --latest --version v0.1.0
#   ./scripts/local-publish.sh --run-id 12345678 --version v0.1.0 --dry-run
#
# Prerequisites:
#   - gh CLI installed and authenticated
#   - pnpm installed (via mise)
#   - npm registry auth configured for @pproenca scope

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
readonly PROJECT_ROOT

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m' # No Color

log_info() { printf "${GREEN}[INFO]${NC} %s\n" "$*"; }
log_warn() { printf "${YELLOW}[WARN]${NC} %s\n" "$*"; }
log_error() { printf "${RED}[ERROR]${NC} %s\n" "$*" >&2; }

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Publish npm packages from GitHub CI artifacts.

Options:
  --run-id ID     Download artifacts from specific CI run ID
  --latest        Download artifacts from latest successful CI run on master
  --version VER   Version to publish (e.g., v0.1.0 or 0.1.0)
  --dry-run       Populate packages but don't publish to npm
  --help          Show this help message

Examples:
  $(basename "$0") --run-id 12345678 --version v0.1.0
  $(basename "$0") --latest --version v0.1.0 --dry-run
EOF
}

# Parse arguments
RUN_ID=""
USE_LATEST=false
VERSION=""
DRY_RUN=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --run-id)
      RUN_ID="$2"
      shift 2
      ;;
    --latest)
      USE_LATEST=true
      shift
      ;;
    --version)
      VERSION="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --help)
      usage
      exit 0
      ;;
    *)
      log_error "Unknown option: $1"
      usage
      exit 1
      ;;
  esac
done

# Validate arguments
if [[ -z "$VERSION" ]]; then
  log_error "Missing required --version"
  usage
  exit 1
fi

if [[ -z "$RUN_ID" ]] && [[ "$USE_LATEST" != "true" ]]; then
  log_error "Must specify either --run-id or --latest"
  usage
  exit 1
fi

if [[ -n "$RUN_ID" ]] && [[ "$USE_LATEST" == "true" ]]; then
  log_error "Cannot use both --run-id and --latest"
  usage
  exit 1
fi

# Check prerequisites
if ! command -v gh &>/dev/null; then
  log_error "gh CLI not found. Install from https://cli.github.com/"
  exit 1
fi

if ! gh auth status &>/dev/null; then
  log_error "gh CLI not authenticated. Run: gh auth login"
  exit 1
fi

# Resolve run ID if using --latest
if [[ "$USE_LATEST" == "true" ]]; then
  log_info "Finding latest successful CI run on master..."
  RUN_ID=$(gh api "repos/pproenca/ffmpeg-prebuilds/actions/workflows/ci.yml/runs?branch=master&status=success&per_page=1" \
    --jq ".workflow_runs[0].id" 2>/dev/null || echo "")

  if [[ -z "$RUN_ID" ]]; then
    log_error "No successful CI run found on master"
    exit 1
  fi
  log_info "Found CI run: $RUN_ID"
fi

# Verify artifacts exist
log_info "Checking artifacts in run $RUN_ID..."
ARTIFACT_COUNT=$(gh api "repos/pproenca/ffmpeg-prebuilds/actions/runs/$RUN_ID/artifacts" \
  --jq '[.artifacts[] | select(.name | startswith("ffmpeg-"))] | length')

if [[ "$ARTIFACT_COUNT" -lt 8 ]]; then
  log_error "Expected 8 artifacts, found $ARTIFACT_COUNT"
  log_error "Artifacts may have expired (30-day retention) or CI run incomplete"
  exit 1
fi
log_info "Found $ARTIFACT_COUNT artifacts"

# Setup directories
cd "$PROJECT_ROOT"
rm -rf artifacts-raw artifacts
mkdir -p artifacts-raw artifacts

# Download artifacts
log_info "Downloading artifacts from run $RUN_ID..."
gh run download "$RUN_ID" --dir artifacts-raw --pattern 'ffmpeg-*'

# Flatten directory structure (gh creates subdirs per artifact)
log_info "Flattening artifact structure..."
cd artifacts-raw
for dir in */; do
  if [[ -d "$dir" ]]; then
    mv "$dir"* . 2>/dev/null || true
    rmdir "$dir" 2>/dev/null || true
  fi
done
cd "$PROJECT_ROOT"

# Count tarballs
shopt -s nullglob
tarballs=(artifacts-raw/*.tar.gz)
if [[ ${#tarballs[@]} -ne 8 ]]; then
  log_error "Expected 8 tarballs, found ${#tarballs[@]}"
  ls -la artifacts-raw/
  exit 1
fi
log_info "Downloaded ${#tarballs[@]} tarballs"

# Verify checksums
log_info "Verifying checksums..."
cd artifacts-raw

# Handle macOS vs Linux sha256sum
if command -v sha256sum &>/dev/null; then
  SHASUM_CMD="sha256sum"
else
  SHASUM_CMD="shasum -a 256"
fi

for f in *.sha256; do
  if [[ -f "$f" ]]; then
    # sha256sum file format: "hash  filename"
    expected_hash=$(awk '{print $1}' "$f")
    filename=$(awk '{print $2}' "$f")
    actual_hash=$($SHASUM_CMD "$filename" | awk '{print $1}')
    if [[ "$expected_hash" != "$actual_hash" ]]; then
      log_error "Checksum mismatch for $filename"
      exit 1
    fi
    log_info "  ✓ $filename"
  fi
done
cd "$PROJECT_ROOT"

# Extract tarballs
log_info "Extracting tarballs..."
for tarball in artifacts-raw/*.tar.gz; do
  tar -xzf "$tarball" -C artifacts
done

# Verify extraction
extracted_dirs=(artifacts/*/)
log_info "Extracted ${#extracted_dirs[@]} platform directories:"
for d in "${extracted_dirs[@]}"; do
  log_info "  - $(basename "$d")"
done

# Strip 'v' prefix from version if present
CLEAN_VERSION="${VERSION#v}"

# Run populate-npm.sh
log_info "Populating npm packages with version $CLEAN_VERSION..."
export FFMPEG_VERSION="$CLEAN_VERSION"
./scripts/populate-npm.sh

# Publish
if [[ "$DRY_RUN" == "true" ]]; then
  log_warn "Dry run - skipping npm publish"
  log_info "To publish manually:"
  log_info "  cd npm && pnpm publish -r --access public"
else
  log_info "Publishing to npm..."
  cd npm
  pnpm publish -r --access public
  cd "$PROJECT_ROOT"
  log_info "Published version $CLEAN_VERSION to npm"
fi

# Cleanup
log_info "Cleaning up..."
rm -rf artifacts-raw

log_info "Done!"
if [[ "$DRY_RUN" == "true" ]]; then
  log_info "Artifacts are in: $PROJECT_ROOT/artifacts/"
  log_info "npm packages are in: $PROJECT_ROOT/npm/"
fi
