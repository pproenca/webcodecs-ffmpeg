# macOS x64 (Intel) Build

This platform uses **native macOS builds** on GitHub Actions `macos-15-intel` runners.

## Local Build

```bash
# Ensure you're on macOS (Intel architecture)
uname -m  # Should output: x86_64

# Run build script
./build/orchestrator.sh darwin-x64

# Artifacts will be in: artifacts/darwin-x64/
```

## Requirements

- macOS 11.0 (Big Sur) or later
- Xcode Command Line Tools
- Homebrew (for dependencies: autoconf, automake, libtool, cmake, pkg-config)

## Build Time

Approximately 25-30 minutes on GitHub Actions runners (parallel codec builds).

## Notes

- Deployment target is set to 11.0 for maximum compatibility
- Uses Clang with x86_64 architecture flag
- All libraries are static and include macOS system frameworks (VideoToolbox, AudioToolbox, etc.)
