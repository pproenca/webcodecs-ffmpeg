#!/usr/bin/env tsx
/**
 * Platform Table Generator
 *
 * Generates markdown tables for platform support from the shared PLATFORMS module.
 */

import {
  PLATFORMS,
  DEPRECATED_PLATFORMS,
  getStandardPlatforms,
  getHwAccelPlatforms,
} from './lib/platforms.ts';
import {isMainModule} from './lib/paths.ts';

const standardPlatforms = getStandardPlatforms();
const hwPlatforms = getHwAccelPlatforms();

/**
 * Generate markdown table for README.md (standard platforms)
 */
export function generateStandardTable(): string {
  const rows = standardPlatforms.map((p) => {
    const platformName = `${p.os}-${p.cpu}${p.libc ? ` (${p.libc})` : ''}`;
    const runtimePkg = `\`@pproenca/ffmpeg-${p.name}\``;
    const devPkg = p.name === 'darwin' ? '`@pproenca/ffmpeg-dev-darwin`' : 'N/A';

    return `| ${platformName} | ${runtimePkg} | ${devPkg} |`;
  });

  return [
    '| Platform | Runtime Package | Dev Package |',
    '|----------|----------------|-------------|',
    ...rows,
  ].join('\n');
}

/**
 * Generate markdown table for HARDWARE.md (hardware acceleration platforms)
 */
export function generateHwTable(): string {
  const rows = hwPlatforms.map((p) => {
    const platformName = `${p.os}-${p.cpu}${p.libc ? ` (${p.libc})` : ''}`;
    const packageName = `\`@pproenca/ffmpeg-${p.name}\``;
    const hwAccel = p.hwAccel ?? 'N/A';

    return `| ${platformName} | ${packageName} | ${hwAccel} |`;
  });

  return [
    '| Platform | Package | Hardware Acceleration |',
    '|----------|---------|----------------------|',
    ...rows,
  ].join('\n');
}

if (isMainModule(import.meta.url)) {
  console.log('Standard Platforms Table:');
  console.log('========================\n');
  console.log(generateStandardTable());

  console.log('\n\nHardware Acceleration Platforms Table:');
  console.log('======================================\n');
  console.log(generateHwTable());
}
