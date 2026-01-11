/**
 * Resolves platform-specific package paths for binding.gyp.
 * @module resolve
 *
 * @example
 * // In binding.gyp:
 * "library_dirs": ["<!(node -p \"require('@pproenca/webcodecs-ffmpeg/resolve').lib\")"]
 * "PKG_CONFIG_PATH": "<!(node -p \"require('@pproenca/webcodecs-ffmpeg/resolve').pkgconfig\")"
 */

'use strict';

const os = require('os');
const fs = require('fs');
const path = require('path');

// ----- Constants -----

const TIER_SUFFIX = '';
const PACKAGE_SCOPE = '@pproenca/webcodecs-ffmpeg';

// ----- Platform Detection -----

/**
 * Detects if the current system uses musl libc (Alpine Linux, etc.)
 * @returns {boolean} True if running on musl libc
 */
function isMusl() {
  if (os.platform() !== 'linux') return false;
  try {
    const muslArch = os.arch() === 'x64' ? 'x86_64' : os.arch();
    return fs.existsSync(`/lib/ld-musl-${muslArch}.so.1`);
  } catch {
    return false;
  }
}

/** @type {string | null} */
let cachedPkgPath = null;

/**
 * Resolves the platform-specific package path
 * @returns {string} Absolute path to the platform package directory
 * @throws {Error} If no suitable platform package is found
 */
function getPlatformPkgPath() {
  if (cachedPkgPath) return cachedPkgPath;

  const platform = os.platform();
  const arch = os.arch();

  // Try musl-specific package first on Linux x64
  if (platform === 'linux' && arch === 'x64' && isMusl()) {
    const muslPkg = `${PACKAGE_SCOPE}-linux-x64-musl${TIER_SUFFIX}`;
    try {
      cachedPkgPath = path.dirname(require.resolve(`${muslPkg}/lib`));
      return cachedPkgPath;
    } catch {
      // Fall through to glibc package
    }
  }

  const pkgName = `${PACKAGE_SCOPE}-${platform}-${arch}${TIER_SUFFIX}`;
  try {
    cachedPkgPath = path.dirname(require.resolve(`${pkgName}/lib`));
    return cachedPkgPath;
  } catch {
    throw new Error(
      `Platform package not found: ${pkgName}. Install it with: npm install ${pkgName}`
    );
  }
}

// ----- Exports -----

module.exports = {
  /**
   * Path to the lib directory containing FFmpeg static libraries
   * @type {string}
   */
  get lib() {
    return path.join(getPlatformPkgPath(), 'lib');
  },

  /**
   * Path to the pkgconfig directory for pkg-config integration
   * @type {string}
   */
  get pkgconfig() {
    return path.join(getPlatformPkgPath(), 'lib', 'pkgconfig');
  },
};
