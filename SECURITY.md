# Security Policy

## Supported Versions

| Version | Supported |
|---------|-----------|
| Latest release | Yes |
| Previous releases | No |

We recommend always using the latest release.

## Reporting a Vulnerability

**Do not report security vulnerabilities through public GitHub issues.**

Instead, please use [GitHub's private vulnerability reporting](https://github.com/pproenca/webcodecs-ffmpeg/security/advisories/new).

### What to include

- Description of the vulnerability
- Steps to reproduce
- Potential impact
- Any suggested fixes (optional)

### Response timeline

- **Acknowledgment**: Within 72 hours
- **Initial assessment**: Within 1 week
- **Resolution**: Depends on severity and complexity

## Scope

This project builds and packages FFmpeg binaries. Security issues may include:

- Build script vulnerabilities
- Dependency vulnerabilities in codec libraries
- Supply chain issues in the npm packages

For vulnerabilities in FFmpeg itself, please report to the
[FFmpeg security team](https://ffmpeg.org/security.html).
