#!/usr/bin/env tsx
/**
 * Documentation Timestamp Updater
 *
 * Extracts version information and last updated date from versions.properties
 * to auto-generate timestamps for documentation files.
 */

import {join} from 'node:path';
import {getVersionMetadataSync} from './lib/versions.ts';
import {getScriptDir, isMainModule} from './lib/paths.ts';

const __dirname = getScriptDir(import.meta.url);

const versionsPath = join(__dirname, '..', 'versions.properties');
const versionInfo = getVersionMetadataSync(versionsPath);

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

if (isMainModule(import.meta.url)) {
  console.log('Version Information:');
  console.log('===================\n');
  console.log(`Last Updated: ${lastUpdated}`);
  console.log(`FFmpeg Version: ${ffmpegVersion}`);
  console.log('\nTimestamp String:');
  console.log(`${generateTimestamp()}`);
}
