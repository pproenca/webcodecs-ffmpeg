#!/usr/bin/env node
/**
 * Fallback installer for when optionalDependencies are disabled.
 * Attempts to locate the platform-specific package or provides guidance.
 */

const os = require('os');

const TIER_SUFFIX = '-gpl';

const PLATFORMS = {
  'darwin-arm64': { os: 'darwin', cpu: 'arm64' },
  'darwin-x64': { os: 'darwin', cpu: 'x64' },
  'linux-x64': { os: 'linux', cpu: 'x64' },
  'linux-arm64': { os: 'linux', cpu: 'arm64' },
  'win32-x64': { os: 'win32', cpu: 'x64' },
  'win32-arm64': { os: 'win32', cpu: 'arm64' },
};

function getPlatformKey() {
  const platform = os.platform();
  const arch = os.arch();
  return `${platform}-${arch}`;
}

function getPackageName(platformKey) {
  return `@pproenca/ffmpeg-${platformKey}-gpl`;
}

function checkInstalled(packageName) {
  try {
    require.resolve(packageName);
    return true;
  } catch {
    return false;
  }
}

function main() {
  const platformKey = getPlatformKey();

  if (!PLATFORMS[platformKey]) {
    console.warn(`[ffmpeg] Warning: Unsupported platform: ${platformKey}`);
    console.warn('[ffmpeg] Prebuilt binaries may not be available for your system.');
    process.exit(0);
  }

  const packageName = getPackageName(platformKey);

  if (checkInstalled(packageName)) {
    // Package was installed via optionalDependencies - all good
    process.exit(0);
  }

  // Package not found - provide guidance
  console.warn(`[ffmpeg] Warning: Platform package not found: ${packageName}`);
  console.warn('[ffmpeg] This usually happens when --no-optional or --ignore-optional is used.');
  console.warn(`[ffmpeg] To install manually: npm install ${packageName}`);
  process.exit(0);
}

main();
