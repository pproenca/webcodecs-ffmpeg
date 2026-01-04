#!/usr/bin/env tsx
/**
 * Documentation Timestamp Updater
 *
 * Extracts version information and last updated date from versions.properties
 * to auto-generate timestamps for documentation files.
 */

import {readFileSync} from 'node:fs';
import {join, dirname} from 'node:path';
import {fileURLToPath} from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

interface VersionInfo {
  lastUpdated: string;
  ffmpegVersion: string;
}

/**
 * Parse versions.properties file to extract version information
 */
function parseVersionsProperties(): VersionInfo {
  const versionsPath = join(__dirname, '..', 'versions.properties');
  const content = readFileSync(versionsPath, 'utf-8');

  // Extract last updated date from comment
  const dateMatch = content.match(/# Updated: (\d{4}-\d{2}-\d{2})/);
  const lastUpdated = dateMatch ? dateMatch[1] : new Date().toISOString().split('T')[0];

  // Extract FFmpeg version
  const ffmpegMatch = content.match(/FFMPEG_VERSION=n(\S+)/);
  const ffmpegVersion = ffmpegMatch ? ffmpegMatch[1] : 'unknown';

  return {
    lastUpdated,
    ffmpegVersion,
  };
}

const versionInfo = parseVersionsProperties();

/**
 * Generate timestamp footer for documentation files
 */
export function generateTimestamp(): string {
  return `Last Updated: ${versionInfo.lastUpdated} | FFmpeg Version: ${versionInfo.ffmpegVersion}`;
}

/**
 * Export individual components
 */
export const lastUpdated = versionInfo.lastUpdated;
export const ffmpegVersion = versionInfo.ffmpegVersion;

// If run directly, output version info
if (import.meta.url === `file://${process.argv[1]}`) {
  console.log('Version Information:');
  console.log('===================\n');
  console.log(`Last Updated: ${lastUpdated}`);
  console.log(`FFmpeg Version: ${ffmpegVersion}`);
  console.log('\nTimestamp String:');
  console.log(`${generateTimestamp()}`);
}
