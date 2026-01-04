# macOS ARM64 (Apple Silicon) Build

This platform uses **native macOS builds** on GitHub Actions `macos-15` runners (Apple Silicon).

## Local Build

```bash
# Ensure you're on macOS (Apple Silicon)
uname -m  # Should output: arm64

# Run build script
./build/orchestrator.sh darwin-arm64

# Artifacts will be in: artifacts/darwin-arm64/
```

## Requirements

- macOS 11.0 (Big Sur) or later
- Xcode Command Line Tools
- Homebrew (for dependencies: autoconf, automake, libtool, cmake, pkg-config)

## Build Time

Approximately 20-25 minutes on GitHub Actions runners (M-series CPUs are faster than Intel).

## Notes

- Deployment target is set to 11.0 for maximum compatibility
- Uses Clang with arm64 architecture flag
- All libraries are static and include macOS system frameworks (VideoToolbox, AudioToolbox, Metal, etc.)
- Hardware acceleration via VideoToolbox is available on Apple Silicon
