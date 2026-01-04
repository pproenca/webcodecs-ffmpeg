# Contributing to FFmpeg Prebuilds

Thank you for your interest in contributing! This project follows the [sharp-libvips](https://github.com/lovell/sharp-libvips) distribution model.

## Quick Start

1. Fork the repository
2. Clone your fork: `git clone https://github.com/YOUR_USERNAME/ffmpeg-prebuilds.git`
3. Create a branch: `git checkout -b feature/your-feature`
4. Make your changes
5. Test locally (see below)
6. Commit and push
7. Open a Pull Request

## Development Workflow

### Testing Local Builds

```bash
# Install dependencies
npm install

# Build for your platform
./build/orchestrator.sh darwin-arm64  # macOS Apple Silicon
./build/orchestrator.sh darwin-x64    # macOS Intel
./build/orchestrator.sh linux-x64-glibc  # Linux (Docker)

# Verify build
./build/verify.sh darwin-arm64

# Check artifacts
ls -lh artifacts/darwin-arm64/
```

### Creating NPM Packages

```bash
# After building all platforms
npm run package

# Check output
ls -lh npm-dist/@pproenca/
```

### Testing NPM Package Installation

```bash
cd /tmp
mkdir test-install && cd test-install
npm init -y
npm install /path/to/ffmpeg-prebuilds/npm-dist/@pproenca/ffmpeg-darwin-arm64

# Verify binary works
node -e "console.log(require('@pproenca/ffmpeg').ffmpegPath)"
```

## Updating Codec Versions

All codec versions are managed in `versions.properties`:

```properties
FFMPEG_VERSION=n8.0
X264_VERSION=stable
X265_VERSION=3.6
# ... etc
```

### Steps to Update:

1. **Edit `versions.properties`**:
   - Update version numbers
   - Update SHA256 checksums for downloaded tarballs
   - Increment `CACHE_VERSION` to invalidate CI caches

2. **Test locally**:
   ```bash
   ./build/orchestrator.sh darwin-arm64
   ./build/verify.sh darwin-arm64
   ```

3. **Update SHA256 checksums**:
   ```bash
   # For tarball downloads (Opus, LAME, etc.)
   curl -sL https://downloads.xiph.org/releases/opus/opus-1.5.2.tar.gz | shasum -a 256
   ```

4. **Create PR** with updated versions

5. **CI will test** all platforms automatically

## Pull Request Guidelines

### PR Title Format

Use [Conventional Commits](https://www.conventionalcommits.org/):

- `feat: add Windows support`
- `fix: correct x265 CMake configuration`
- `chore: update FFmpeg to 8.1`
- `docs: improve build instructions`

### PR Checklist

- [ ] Code follows existing style
- [ ] Tested locally on at least one platform
- [ ] Updated `versions.properties` if changing dependencies
- [ ] Updated `README.md` if adding features
- [ ] CI passes (all platforms build successfully)

## Adding New Platforms

To add support for a new platform (e.g., Windows, ARM Linux):

1. **Create platform directory**:
   ```bash
   mkdir -p platforms/windows-x64
   ```

2. **Add Dockerfile or build instructions**:
   ```dockerfile
   # platforms/windows-x64/Dockerfile
   FROM mcr.microsoft.com/windows/servercore:ltsc2022
   # ... build steps
   ```

3. **Update build scripts**:
   - Add platform routing in `build/orchestrator.sh`
   - Create platform-specific script if needed

4. **Update packaging**:
   - Add platform to `scripts/package-npm.ts` `PLATFORMS` array
   - Update main package `optionalDependencies`

5. **Add CI job**:
   ```yaml
   # .github/workflows/build.yml
   - platform: windows-x64
     runner: windows-2022
     uses_docker: false
   ```

6. **Test end-to-end**:
   - Build locally
   - Create packages
   - Test installation

## Reporting Issues

### Bug Reports

Include:

- Platform (macOS/Linux, architecture, libc variant)
- FFmpeg version (from `versions.properties`)
- Full error output
- Steps to reproduce

### Feature Requests

Describe:

- Use case
- Expected behavior
- Proposed implementation (if any)

## Release Process

**Only maintainers can create releases.**

1. **Update version** in `package.json` and `scripts/package-npm.ts`
2. **Create git tag**: `git tag v8.0.1`
3. **Push tag**: `git push --tags`
4. **GitHub Actions** will:
   - Build all platforms
   - Create npm packages
   - Publish to npm
   - Create GitHub Release

## Code Style

- **Shell scripts**: Follow existing style (ShellCheck clean)
- **TypeScript**: Use project's ESLint config
- **Dockerfiles**: Multi-stage builds, cleanup layers
- **Comments**: Explain *why*, not *what*

## Testing

### Manual Testing Checklist

Before submitting PR:

- [ ] Builds complete successfully
- [ ] Binaries run (`ffmpeg -version`)
- [ ] Static libraries have correct permissions
- [ ] pkg-config files resolve correctly
- [ ] No unexpected dynamic dependencies (otool/ldd)

### CI Testing

All PRs trigger:

- Matrix builds (all platforms)
- Verification scripts
- Package creation

## Getting Help

- **Issues**: [GitHub Issues](https://github.com/pproenca/ffmpeg-prebuilds/issues)
- **Discussions**: [GitHub Discussions](https://github.com/pproenca/ffmpeg-prebuilds/discussions)
- **Reference**: [sharp-libvips](https://github.com/lovell/sharp-libvips) (similar project)

## License

By contributing, you agree that your contributions will be licensed under GPL-2.0-or-later.
