/**
 * Resolves platform-specific package paths for binding.gyp.
 *
 * Usage in binding.gyp:
 *   "library_dirs": ["<!(node -p \"require('@pproenca/webcodecs-ffmpeg/resolve').lib\")"]
 *   PKG_CONFIG_PATH: "<!(node -p \"require('@pproenca/webcodecs-ffmpeg/resolve').pkgconfig\")"
 */
const os = require('os');
const fs = require('fs');
const path = require('path');

const TIER_SUFFIX = '';

/**
 * Detect if running on musl libc (Alpine Linux, etc.)
 */
function isMusl() {
  if (os.platform() !== 'linux') return false;
  try {
    const arch = os.arch() === 'x64' ? 'x86_64' : os.arch();
    return fs.existsSync(`/lib/ld-musl-${arch}.so.1`);
  } catch {
    return false;
  }
}

function getPlatformPkgPath() {
  const platform = os.platform();
  const arch = os.arch();

  // Try musl-specific package first on Linux x64
  if (platform === 'linux' && arch === 'x64' && isMusl()) {
    const muslPkg = `@pproenca/webcodecs-ffmpeg-linux-x64-musl${TIER_SUFFIX}`;
    try {
      return path.dirname(require.resolve(`${muslPkg}/lib`));
    } catch {
      // Fall through to glibc package
    }
  }

  const pkgName = `@pproenca/webcodecs-ffmpeg-${platform}-${arch}${TIER_SUFFIX}`;
  try {
    return path.dirname(require.resolve(`${pkgName}/lib`));
  } catch (e) {
    throw new Error(`Platform package not found: ${pkgName}. Install it with: npm install ${pkgName}`);
  }
}

module.exports = {
  get lib() {
    return path.join(getPlatformPkgPath(), 'lib');
  },
  get pkgconfig() {
    return path.join(getPlatformPkgPath(), 'lib', 'pkgconfig');
  }
};
