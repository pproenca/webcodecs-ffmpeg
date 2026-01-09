/**
 * Resolves platform-specific package paths for binding.gyp.
 *
 * Usage in binding.gyp:
 *   "library_dirs": ["<!(node -p \"require('@pproenca/webcodecs-ffmpeg/resolve').lib\")"]
 *   PKG_CONFIG_PATH: "<!(node -p \"require('@pproenca/webcodecs-ffmpeg/resolve').pkgconfig\")"
 */
const os = require('os');
const path = require('path');

const TIER_SUFFIX = '';

function getPlatformPkgPath() {
  const platform = os.platform();
  const arch = os.arch();
  const pkgName = `@pproenca/webcodecs-ffmpeg-${platform}-${arch}`;
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
