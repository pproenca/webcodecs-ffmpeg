# Security Scanning

Automated vulnerability scanning for FFmpeg prebuilds using Aqua Security Trivy.

## Overview

This directory contains security scanning tools to detect known vulnerabilities (CVEs) in:
- Compiled FFmpeg binaries
- Build dependencies (FFmpeg, codecs, libraries)
- Supply chain integrity (version pinning, checksum verification)

## Quick Start

### Local Scanning

```bash
# Install Trivy (if not already installed)
# macOS
brew install trivy

# Linux (Debian/Ubuntu)
wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | sudo apt-key add -
echo "deb https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main" | sudo tee -a /etc/apt/sources.list.d/trivy.list
sudo apt-get update && sudo apt-get install trivy

# Run security scan
./security/scan-artifacts.sh
```

### CI Integration

Security scanning runs automatically in GitHub Actions after builds:

```yaml
- name: Security Scan
  run: ./security/scan-artifacts.sh
```

Results are uploaded as artifacts and included in the build summary.

## What Gets Scanned

### 1. Binary Vulnerability Scanning

Scans compiled `ffmpeg` and `ffprobe` binaries for:
- Known CVEs in linked libraries
- Vulnerable runtime dependencies
- Security issues in statically-linked components

**Platforms scanned:**
- darwin-x64, darwin-arm64 (macOS)
- linux-x64-glibc, linux-x64-musl (Linux x64)
- linux-arm64-glibc, linux-arm64-musl (Linux ARM64)
- linux-armv7-glibc (Linux ARMv7)
- windows-x64 (Windows MinGW)

### 2. Dependency Version Checking

Reviews `versions.properties` against CVE databases:

| Dependency | CVE Database |
|------------|--------------|
| FFmpeg | https://www.cvedetails.com/product/6315/FFmpeg-Ffmpeg.html |
| x264 | https://www.cvedetails.com/product/49586/ |
| x265 | https://www.cvedetails.com/product/49587/ |
| libvpx | https://www.cvedetails.com/vulnerability-list/vendor_id-1224/product_id-18792/ |
| libaom | https://github.com/advisories?query=aom |

### 3. Supply Chain Security

Verifies:
- ✅ All dependencies pinned to specific versions
- ✅ SHA256 checksums verified during builds
- ✅ Docker base images from official sources
- ✅ No dynamic downloads from untrusted sources

## Scan Results

### Directory Structure

```
security/
├── scan-artifacts.sh         # Scan script
├── results/                   # Scan results (gitignored)
│   ├── scan-summary.txt       # Overall summary
│   ├── darwin-x64-ffmpeg.txt  # Per-platform text reports
│   ├── darwin-x64-ffmpeg.json # Per-platform JSON reports
│   └── dependencies.txt       # Dependency version check
└── README.md                  # This file
```

### Understanding Results

#### Clean Scan
```
Platform: darwin-arm64
✓ ffmpeg: No vulnerabilities found
✓ ffprobe: No vulnerabilities found
✓ darwin-arm64: All binaries clean
```

#### Vulnerabilities Found
```
Platform: linux-x64-glibc
⚠ ffmpeg: 3 vulnerabilities found
           Report: security/results/linux-x64-glibc-ffmpeg.txt
```

Open the report file to see CVE details:
```
CVE-2024-XXXXX (HIGH): Buffer overflow in libavcodec
  Affected: libavcodec 6.0
  Fixed in: libavcodec 6.1
  Impact: Remote code execution via crafted video file
```

### Interpreting Vulnerabilities

**Critical questions to ask:**

1. **Does this affect our build?**
   - Static builds may not be affected by runtime library CVEs
   - Check if vulnerable code path is compiled in
   - Review if feature is disabled in our build config

2. **What's the attack vector?**
   - Remote input (video file, network stream)?
   - Local privilege escalation?
   - Requires specific codec/feature?

3. **Is there a fix available?**
   - Check upstream release notes
   - Determine if backport is needed
   - Assess patch availability

4. **What's the risk?**
   - CVSS score (0-10 scale)
   - Exploitability in our use case
   - Exposure (public-facing vs. internal tool)

## Responding to Vulnerabilities

### 1. Assess Severity

Use CVSS scoring:
- **Critical (9.0-10.0)**: Immediate action required
- **High (7.0-8.9)**: Update within 7 days
- **Medium (4.0-6.9)**: Update in next release
- **Low (0.1-3.9)**: Monitor, update opportunistically

### 2. Update Dependencies

```bash
# Edit versions.properties
vim versions.properties

# Update FFmpeg version
FFMPEG_VERSION=n8.1  # ← Change to patched version

# Rebuild
./build/orchestrator.sh darwin-arm64

# Re-scan
./security/scan-artifacts.sh
```

### 3. Document Accepted Risks

If a vulnerability cannot be fixed (e.g., no patch available, false positive):

```bash
# Create security exception
cat > security/exceptions/CVE-2024-XXXXX.md <<EOF
# CVE-2024-XXXXX - Accepted Risk

**Severity:** Medium
**Component:** libavcodec
**Status:** Accepted (false positive)

**Justification:**
- Vulnerability affects dynamic linking only
- Our static builds are not affected
- Code path not reachable in typical usage

**Mitigation:**
- None required

**Review Date:** 2026-06-01
EOF
```

## Automation

### Scheduled Scanning

Add to `.github/workflows/security-scan.yml`:

```yaml
name: Security Scan

on:
  schedule:
    - cron: '0 0 * * 0'  # Weekly on Sunday
  workflow_dispatch:

jobs:
  scan:
    runs-on: ubuntu-24.04
    steps:
      - uses: actions/checkout@v4

      # Download latest release artifacts
      - name: Download artifacts
        run: gh release download --pattern 'ffmpeg-*.tar.gz'

      # Extract and scan
      - name: Security scan
        run: |
          mkdir -p artifacts
          for f in ffmpeg-*.tar.gz; do tar -xzf "$f" -C artifacts/; done
          ./security/scan-artifacts.sh --fail

      # Create issue if vulnerabilities found
      - name: Create issue
        if: failure()
        uses: actions/github-script@v7
        with:
          script: |
            github.rest.issues.create({
              owner: context.repo.owner,
              repo: context.repo.repo,
              title: 'Security vulnerabilities detected',
              body: 'Automated scan found vulnerabilities. Review security/results/'
            })
```

### Dependency Update Monitoring

Use Dependabot or Renovate to monitor upstream releases:

**.github/dependabot.yml:**
```yaml
version: 2
updates:
  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "weekly"
```

**Manual monitoring:**
- Subscribe to FFmpeg security mailing list: https://lists.ffmpeg.org/mailman/listinfo/ffmpeg-devel
- Watch GitHub Security Advisories: https://github.com/advisories
- Monitor CVE databases for FFmpeg/codec CVEs

## Configuration

### Severity Levels

Customize which severity levels to scan:

```bash
# Only critical and high
./security/scan-artifacts.sh --severity CRITICAL,HIGH

# All levels
./security/scan-artifacts.sh --severity CRITICAL,HIGH,MEDIUM,LOW
```

### Fail on Vulnerabilities

Exit with error code if vulnerabilities found (for CI):

```bash
./security/scan-artifacts.sh --fail
```

### Platform-Specific Scanning

Scan only specific platform:

```bash
./security/scan-artifacts.sh --platform linux-x64-glibc
```

## Best Practices

### Development

1. **Scan before commits**
   ```bash
   ./security/scan-artifacts.sh
   git add -A && git commit
   ```

2. **Review dependency updates**
   - Read upstream changelogs
   - Check for security fixes
   - Test before deploying

3. **Pin versions strictly**
   - Use exact versions, not ranges
   - Verify checksums
   - Document why specific version chosen

### Production

1. **Automated scanning in CI**
   - Scan every build
   - Upload results as artifacts
   - Alert on new vulnerabilities

2. **Regular updates**
   - Monthly dependency review
   - Quarterly major version updates
   - Immediate critical security patches

3. **Incident response plan**
   - Define SLAs for each severity
   - Establish escalation process
   - Document communication channels

## False Positives

Trivy may report vulnerabilities that don't affect static builds:

### Common False Positives

1. **glibc CVEs in static builds**
   - Static musl builds: immune to glibc CVEs
   - Verify with: `ldd ffmpeg` (should say "not a dynamic executable")

2. **Runtime library issues**
   - Static linking eliminates runtime dependencies
   - Verify: check `ldd` or `otool -L` output

3. **Platform-specific issues**
   - Windows CVEs on Linux builds (and vice versa)
   - Check if vulnerability applies to target platform

### Handling False Positives

Document in `security/exceptions/`:

```markdown
# False Positive: CVE-YYYY-XXXXX

**Component:** glibc
**Reported in:** linux-x64-glibc build

**Reason for false positive:**
Static build does not use affected glibc runtime component.

**Verification:**
`ldd artifacts/linux-x64-glibc/bin/ffmpeg` shows only system libs.

**Action:** No fix required
```

## Trivy Database Updates

Trivy auto-updates its vulnerability database:

```bash
# Manual update
trivy image --download-db-only

# Check database version
trivy version

# Clear cache (force refresh)
trivy clean --all
```

## Resources

- **Trivy Documentation:** https://aquasecurity.github.io/trivy/
- **FFmpeg Security:** https://www.ffmpeg.org/security.html
- **CVE Search:** https://cve.mitre.org/cve/search_cve_list.html
- **NIST NVD:** https://nvd.nist.gov/
- **GitHub Security Advisories:** https://github.com/advisories

## See Also

- [Build Configuration](../BUILD-CONFIG.md) - Customize codec selection
- [Dependency Versions](../versions.properties) - Pinned versions
- [CI Workflow](../.github/workflows/build.yml) - Automated scanning
