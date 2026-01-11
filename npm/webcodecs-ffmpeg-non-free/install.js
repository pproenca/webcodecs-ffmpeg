#!/usr/bin/env node
/**
 * Fallback installer for when optionalDependencies are disabled.
 * @module install
 */

'use strict';

const os = require('os');
const fs = require('fs');

// ----- Type Definitions -----

/**
 * @typedef {Object} PlatformInfo
 * @property {string} os
 * @property {string} cpu
 * @property {string} [libc]
 */

/** @typedef {'darwin-arm64' | 'darwin-x64' | 'linux-x64' | 'linux-x64-musl' | 'linux-arm64' | 'win32-x64' | 'win32-arm64'} PlatformKey */

// ----- Constants -----

const TIER_SUFFIX = '-non-free';
const PACKAGE_SCOPE = '@pproenca/webcodecs-ffmpeg';

/** @type {Record<PlatformKey, PlatformInfo>} */
const PLATFORMS = {
  'darwin-arm64': { os: 'darwin', cpu: 'arm64' },
  'darwin-x64': { os: 'darwin', cpu: 'x64' },
  'linux-x64': { os: 'linux', cpu: 'x64' },
  'linux-x64-musl': { os: 'linux', cpu: 'x64', libc: 'musl' },
  'linux-arm64': { os: 'linux', cpu: 'arm64' },
  'win32-x64': { os: 'win32', cpu: 'x64' },
  'win32-arm64': { os: 'win32', cpu: 'arm64' },
};

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

/**
 * Gets the platform key for the current system
 * @returns {string} Platform key (e.g., 'darwin-arm64', 'linux-x64-musl')
 */
function getPlatformKey() {
  const platform = os.platform();
  const arch = os.arch();
  if (platform === 'linux' && arch === 'x64' && isMusl()) {
    return 'linux-x64-musl';
  }
  return `${platform}-${arch}`;
}

/**
 * Gets the package name for a platform key
 * @param {string} platformKey
 * @returns {string} Full package name
 */
function getPackageName(platformKey) {
  return `${PACKAGE_SCOPE}-${platformKey}${TIER_SUFFIX}`;
}

/**
 * Checks if a package is installed
 * @param {string} packageName
 * @returns {boolean} True if the package can be resolved
 */
function checkInstalled(packageName) {
  try {
    require.resolve(packageName);
    return true;
  } catch {
    return false;
  }
}

// ----- Main -----

function main() {
  const platformKey = getPlatformKey();

  if (!PLATFORMS[platformKey]) {
    console.warn(`[ffmpeg] Warning: Unsupported platform: ${platformKey}`);
    console.warn('[ffmpeg] Prebuilt binaries may not be available for your system.');
    process.exit(0);
  }

  const packageName = getPackageName(platformKey);

  if (checkInstalled(packageName)) {
    process.exit(0);
  }

  console.warn(`[ffmpeg] Warning: Platform package not found: ${packageName}`);
  console.warn('[ffmpeg] This usually happens when --no-optional or --ignore-optional is used.');
  console.warn(`[ffmpeg] To install manually: npm install ${packageName}`);
  process.exit(0);
}

main();
