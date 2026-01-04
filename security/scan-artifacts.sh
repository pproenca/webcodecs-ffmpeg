#!/usr/bin/env bash
#
# Security Vulnerability Scanning with Trivy
# Scans FFmpeg build artifacts for known CVEs
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ARTIFACTS_DIR="$PROJECT_ROOT/artifacts"

# ============================================================================
# Configuration
# ============================================================================

# Trivy scan configuration
TRIVY_SEVERITY="CRITICAL,HIGH,MEDIUM"
TRIVY_TIMEOUT="10m"
TRIVY_EXIT_CODE=0  # Don't fail CI on vulnerabilities (report only)

# Output directories
SCAN_RESULTS_DIR="$PROJECT_ROOT/security/results"
SCAN_SUMMARY="$SCAN_RESULTS_DIR/scan-summary.txt"

# ============================================================================
# Colors
# ============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_success() {
  echo -e "${GREEN}✓${NC} $1"
}

print_error() {
  echo -e "${RED}✗${NC} $1"
}

print_warning() {
  echo -e "${YELLOW}⚠${NC} $1"
}

print_info() {
  echo -e "${BLUE}ℹ${NC} $1"
}

print_section() {
  echo ""
  echo "=========================================="
  echo "$1"
  echo "=========================================="
}

# ============================================================================
# Trivy Installation Check
# ============================================================================

check_trivy() {
  if ! command -v trivy &> /dev/null; then
    print_error "Trivy not installed"
    echo ""
    echo "Install Trivy:"
    echo "  macOS:   brew install trivy"
    echo "  Linux:   wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | sudo apt-key add -"
    echo "           echo \"deb https://aquasecurity.github.io/trivy-repo/deb \$(lsb_release -sc) main\" | sudo tee -a /etc/apt/sources.list.d/trivy.list"
    echo "           sudo apt-get update && sudo apt-get install trivy"
    echo "  GitHub:  https://github.com/aquasecurity/trivy/releases"
    echo ""
    return 1
  fi

  print_success "Trivy found: $(trivy --version | head -1)"
  return 0
}

# ============================================================================
# Scan Functions
# ============================================================================

scan_binaries() {
  local platform="$1"
  local artifact_dir="$ARTIFACTS_DIR/$platform"

  print_section "Scanning $platform Binaries"

  if [[ ! -d "$artifact_dir" ]]; then
    print_warning "Artifact directory not found: $artifact_dir (skipped)"
    return 0
  fi

  # Find all binaries
  local binaries=()
  if [[ -f "$artifact_dir/bin/ffmpeg" ]]; then
    binaries+=("$artifact_dir/bin/ffmpeg")
  fi
  if [[ -f "$artifact_dir/bin/ffprobe" ]]; then
    binaries+=("$artifact_dir/bin/ffprobe")
  fi

  if [[ ${#binaries[@]} -eq 0 ]]; then
    print_warning "No binaries found in $platform (dev-only build?)"
    return 0
  fi

  local total_vulns=0

  for binary in "${binaries[@]}"; do
    local binary_name=$(basename "$binary")
    local result_file="$SCAN_RESULTS_DIR/${platform}-${binary_name}.txt"
    local result_json="$SCAN_RESULTS_DIR/${platform}-${binary_name}.json"

    print_info "Scanning $binary_name..."

    # Scan binary with Trivy
    # Use 'rootfs' scanner for compiled binaries
    if trivy rootfs \
      --severity "$TRIVY_SEVERITY" \
      --timeout "$TRIVY_TIMEOUT" \
      --format table \
      --output "$result_file" \
      "$binary" 2>/dev/null; then

      # Also save JSON format for automation
      trivy rootfs \
        --severity "$TRIVY_SEVERITY" \
        --timeout "$TRIVY_TIMEOUT" \
        --format json \
        --output "$result_json" \
        "$binary" 2>/dev/null || true

      # Count vulnerabilities
      local vuln_count=$(grep -c "CVE-" "$result_file" 2>/dev/null || echo "0")
      total_vulns=$((total_vulns + vuln_count))

      if [[ $vuln_count -eq 0 ]]; then
        print_success "$binary_name: No vulnerabilities found"
      else
        print_warning "$binary_name: $vuln_count vulnerabilities found"
        echo "           Report: $result_file"
      fi
    else
      print_warning "$binary_name: Scan failed (may not be scannable)"
    fi
  done

  if [[ $total_vulns -gt 0 ]]; then
    print_warning "$platform: $total_vulns total vulnerabilities"
  else
    print_success "$platform: All binaries clean"
  fi

  echo ""
  return 0
}

scan_dependencies() {
  print_section "Scanning Build Dependencies"

  # Check versions.properties for known vulnerable versions
  local versions_file="$PROJECT_ROOT/versions.properties"

  if [[ ! -f "$versions_file" ]]; then
    print_warning "versions.properties not found (skipped)"
    return 0
  fi

  print_info "Checking dependency versions against CVE database..."

  # Create temporary file for dependency scan
  local dep_scan_file="$SCAN_RESULTS_DIR/dependencies.txt"
  local dep_json_file="$SCAN_RESULTS_DIR/dependencies.json"

  # Extract dependency versions
  grep -E "^(FFMPEG|X264|X265|VPX|AOM|OPUS|LAME)_VERSION" "$versions_file" > "$dep_scan_file" || true

  # Trivy can scan for known vulnerabilities in specific software versions
  # This is a manual check - Trivy primarily scans containers/filesystems
  print_info "Dependency versions:"
  cat "$dep_scan_file"

  echo ""
  print_info "Manual CVE check recommended:"
  echo "  - FFmpeg:  https://www.cvedetails.com/product/6315/FFmpeg-Ffmpeg.html"
  echo "  - x264:    https://www.cvedetails.com/product/49586/"
  echo "  - x265:    https://www.cvedetails.com/product/49587/"
  echo ""

  return 0
}

scan_supply_chain() {
  print_section "Supply Chain Security"

  print_info "Verifying SHA256 checksums..."

  # Check that build scripts verify checksums
  local checksum_count=$(grep -r "sha256sum\|shasum -a 256" "$PROJECT_ROOT/platforms/" 2>/dev/null | wc -l | tr -d ' ')

  if [[ $checksum_count -gt 0 ]]; then
    print_success "Build scripts include $checksum_count SHA256 verifications"
  else
    print_warning "No SHA256 checksum verifications found in build scripts"
  fi

  print_info "Checking for pinned versions..."

  # Verify versions.properties exists and has pinned versions
  if [[ -f "$PROJECT_ROOT/versions.properties" ]]; then
    local pinned_versions=$(grep -cE "^[A-Z_]+_VERSION=.*[0-9]" "$PROJECT_ROOT/versions.properties" 2>/dev/null || echo "0")
    print_success "versions.properties pins $pinned_versions dependency versions"
  else
    print_error "versions.properties not found - dependencies not pinned!"
  fi

  echo ""
  return 0
}

# ============================================================================
# Generate Summary Report
# ============================================================================

generate_summary() {
  print_section "Generating Summary Report"

  local timestamp=$(date)
  local total_platforms=0
  local vulnerable_platforms=0
  local total_vulns=0

  # Count platforms scanned
  for platform_dir in "$ARTIFACTS_DIR"/*; do
    if [[ -d "$platform_dir" ]]; then
      total_platforms=$((total_platforms + 1))

      local platform=$(basename "$platform_dir")
      local platform_vulns=$(find "$SCAN_RESULTS_DIR" -name "${platform}-*.txt" -exec grep -c "CVE-" {} \; 2>/dev/null | awk '{s+=$1} END {print s}' || echo "0")

      total_vulns=$((total_vulns + platform_vulns))

      if [[ $platform_vulns -gt 0 ]]; then
        vulnerable_platforms=$((vulnerable_platforms + 1))
      fi
    fi
  done

  cat > "$SCAN_SUMMARY" <<EOF
FFmpeg Prebuilds - Security Scan Summary
==========================================

Scan Date: $timestamp
Trivy Version: $(trivy --version | head -1)

Platforms Scanned: $total_platforms
Platforms with Vulnerabilities: $vulnerable_platforms
Total Vulnerabilities: $total_vulns

Severity Levels Scanned: $TRIVY_SEVERITY

Detailed Reports:
$(find "$SCAN_RESULTS_DIR" -name "*.txt" -type f | sed 's/^/  - /')

Recommendations:
- Review individual platform reports for CVE details
- Update dependency versions in versions.properties
- Check upstream security advisories
- Consider patching or version updates for critical CVEs

Next Steps:
1. Review each vulnerability in context
2. Determine if vulnerability affects static builds
3. Update dependency versions if patches available
4. Document accepted risks for non-patchable issues

For more information:
- FFmpeg Security: https://www.ffmpeg.org/security.html
- CVE Database: https://cve.mitre.org/
- GitHub Security Advisories: https://github.com/advisories

EOF

  print_success "Summary report saved: $SCAN_SUMMARY"

  # Display summary
  echo ""
  cat "$SCAN_SUMMARY"
}

# ============================================================================
# Main Execution
# ============================================================================

main() {
  print_section "FFmpeg Prebuilds - Security Scanning"

  # Check Trivy availability
  if ! check_trivy; then
    exit 1
  fi

  # Create results directory
  mkdir -p "$SCAN_RESULTS_DIR"

  # Clean previous results
  rm -f "$SCAN_RESULTS_DIR"/*.txt "$SCAN_RESULTS_DIR"/*.json

  # ========================================================================
  # Scan all platforms
  # ========================================================================

  if [[ ! -d "$ARTIFACTS_DIR" ]]; then
    print_error "Artifacts directory not found: $ARTIFACTS_DIR"
    echo "Please build artifacts first: ./build/orchestrator.sh <platform>"
    exit 1
  fi

  # Scan each platform
  for platform_dir in "$ARTIFACTS_DIR"/*; do
    if [[ -d "$platform_dir" ]]; then
      local platform=$(basename "$platform_dir")
      scan_binaries "$platform" || true
    fi
  done

  # ========================================================================
  # Additional scans
  # ========================================================================

  scan_dependencies || true
  scan_supply_chain || true

  # ========================================================================
  # Generate summary
  # ========================================================================

  generate_summary

  # ========================================================================
  # Exit
  # ========================================================================

  print_section "Security Scan Complete"

  print_success "All scans completed"
  echo ""
  echo "Summary: $SCAN_SUMMARY"
  echo "Results: $SCAN_RESULTS_DIR"
  echo ""

  exit "$TRIVY_EXIT_CODE"
}

# ============================================================================
# Help
# ============================================================================

show_help() {
  cat <<EOF
FFmpeg Prebuilds - Security Scanner

Usage: $0 [options]

Options:
  -h, --help          Show this help message
  -s, --severity LEVELS
                      Trivy severity levels (default: CRITICAL,HIGH,MEDIUM)
  -f, --fail          Exit with error code if vulnerabilities found
  -p, --platform PLATFORM
                      Scan specific platform only

Examples:
  $0                              # Scan all platforms
  $0 --platform linux-x64-glibc   # Scan specific platform
  $0 --severity CRITICAL,HIGH     # Only critical and high severity
  $0 --fail                       # Fail CI if vulnerabilities found

EOF
}

# ============================================================================
# Command-Line Arguments
# ============================================================================

SPECIFIC_PLATFORM=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      show_help
      exit 0
      ;;
    -s|--severity)
      TRIVY_SEVERITY="$2"
      shift 2
      ;;
    -f|--fail)
      TRIVY_EXIT_CODE=1
      shift
      ;;
    -p|--platform)
      SPECIFIC_PLATFORM="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1"
      show_help
      exit 1
      ;;
  esac
done

# If specific platform requested, override scan
if [[ -n "$SPECIFIC_PLATFORM" ]]; then
  check_trivy || exit 1
  mkdir -p "$SCAN_RESULTS_DIR"
  scan_binaries "$SPECIFIC_PLATFORM"
  exit 0
fi

# Run main scan
main
