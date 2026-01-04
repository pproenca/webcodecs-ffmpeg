#!/usr/bin/env tsx
/**
 * Platform Table Generator
 *
 * Generates markdown tables for platform support from the PLATFORMS array
 * in package-npm.ts (single source of truth).
 */

interface Platform {
  name: string;
  os: string;
  cpu: string;
  libc?: 'glibc' | 'musl';
  hwAccel?: string;
}

// Import PLATFORMS array from package-npm.ts
// Note: We'll need to parse this from the file since it's not exported as a module
import {readFileSync} from 'node:fs';
import {join, dirname} from 'node:path';
import {fileURLToPath} from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

function parsePlatformsFromPackageNpm(): Platform[] {
  const packageNpmPath = join(__dirname, 'package-npm.ts');
  const content = readFileSync(packageNpmPath, 'utf-8');

  // Extract the PLATFORMS array using regex
  const platformsMatch = content.match(/const PLATFORMS: Platform\[\] = \[([\s\S]*?)\];/);

  if (!platformsMatch) {
    throw new Error('Could not find PLATFORMS array in package-npm.ts');
  }

  const platformsArrayStr = platformsMatch[1];

  // Parse each platform object
  const platformRegex = /\{\s*name:\s*'([^']+)',\s*os:\s*'([^']+)',\s*cpu:\s*'([^']+)'(?:,\s*libc:\s*'([^']+)')?(?:,\s*hwAccel:\s*'([^']+)')?\s*\}/g;

  const platforms: Platform[] = [];
  let match: RegExpExecArray | null;

  while ((match = platformRegex.exec(platformsArrayStr)) !== null) {
    const platform: Platform = {
      name: match[1],
      os: match[2],
      cpu: match[3],
    };

    if (match[4]) {
      platform.libc = match[4] as 'glibc' | 'musl';
    }

    if (match[5]) {
      platform.hwAccel = match[5];
    }

    platforms.push(platform);
  }

  return platforms;
}

// Get platforms from source
const PLATFORMS = parsePlatformsFromPackageNpm();

// Extract non-deprecated standard platforms
const standardPlatforms = PLATFORMS.filter(
  (p) => !p.hwAccel && !['darwin-x64', 'darwin-arm64'].includes(p.name)
);

// Extract hardware acceleration platforms
const hwPlatforms = PLATFORMS.filter((p) => p.hwAccel);

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

  return ['| Platform | Runtime Package | Dev Package |', '|----------|----------------|-------------|', ...rows].join(
    '\n'
  );
}

/**
 * Generate markdown table for HARDWARE.md (hardware acceleration platforms)
 */
export function generateHwTable(): string {
  const rows = hwPlatforms.map((p) => {
    const platformName = `${p.os}-${p.cpu}${p.libc ? ` (${p.libc})` : ''}`;
    const packageName = `\`@pproenca/ffmpeg-${p.name}\``;
    const hwAccel = p.hwAccel || 'N/A';

    return `| ${platformName} | ${packageName} | ${hwAccel} |`;
  });

  return ['| Platform | Package | Hardware Acceleration |', '|----------|---------|----------------------|', ...rows].join(
    '\n'
  );
}

// If run directly, output both tables
if (import.meta.url === `file://${process.argv[1]}`) {
  console.log('Standard Platforms Table:');
  console.log('========================\n');
  console.log(generateStandardTable());

  console.log('\n\nHardware Acceleration Platforms Table:');
  console.log('======================================\n');
  console.log(generateHwTable());
}
