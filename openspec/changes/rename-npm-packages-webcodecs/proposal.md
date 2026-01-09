# Change: Rename npm packages to webcodecs-ffmpeg namespace

## Why

The current package names (`@pproenca/ffmpeg`, `@pproenca/ffmpeg-non-free`) don't reflect their relationship to the main `webcodecs` package they support. The FFmpeg prebuilts are optionalDependencies for the `node-webcodecs` package (WebCodecs API implementation for Node.js). Renaming to `webcodecs-ffmpeg-*` makes the relationship clear and provides proper FFmpeg attribution in the package names.

## What Changes

**Package renames (10 packages):**

| Current | New |
|---------|-----|
| `@pproenca/ffmpeg` | `@pproenca/webcodecs-ffmpeg` |
| `@pproenca/ffmpeg-non-free` | `@pproenca/webcodecs-ffmpeg-non-free` |
| `@pproenca/ffmpeg-darwin-arm64` | `@pproenca/webcodecs-ffmpeg-darwin-arm64` |
| `@pproenca/ffmpeg-darwin-arm64-non-free` | `@pproenca/webcodecs-ffmpeg-darwin-arm64-non-free` |
| `@pproenca/ffmpeg-darwin-x64` | `@pproenca/webcodecs-ffmpeg-darwin-x64` |
| `@pproenca/ffmpeg-darwin-x64-non-free` | `@pproenca/webcodecs-ffmpeg-darwin-x64-non-free` |
| `@pproenca/ffmpeg-linux-arm64` | `@pproenca/webcodecs-ffmpeg-linux-arm64` |
| `@pproenca/ffmpeg-linux-arm64-non-free` | `@pproenca/webcodecs-ffmpeg-linux-arm64-non-free` |
| `@pproenca/ffmpeg-linux-x64` | `@pproenca/webcodecs-ffmpeg-linux-x64` |
| `@pproenca/ffmpeg-linux-x64-non-free` | `@pproenca/webcodecs-ffmpeg-linux-x64-non-free` |

**Related external rename:**
- `node-webcodecs` → `@pproenca/webcodecs` (separate repo, not part of this change)

**Files affected:**
- `npm/*/package.json` - Package names and optionalDependencies references
- `openspec/project.md` - Update package references
- `CLAUDE.md` - Update package references
- `.github/workflows/*.yml` - Update any package name references
- `README.md` - Update documentation

## Impact

- **Breaking change for existing users** - Must update dependency names
- **npm registry** - New packages will be published; old names deprecated
- **CI/CD** - Workflow references need updating
- **Documentation** - All references need updating

## Rationale

1. **Clear ecosystem relationship** - `webcodecs-ffmpeg-*` shows these are FFmpeg prebuilts for the webcodecs package
2. **FFmpeg attribution** - Keeping "ffmpeg" in the name provides clear attribution as recommended by open source best practices
3. **License clarity** - `free` vs `non-free` naming (Ubuntu/Debian convention) signals commercial usability to developers
4. **Scoped namespace** - All packages under `@pproenca/webcodecs-*` creates a cohesive product family
