#!/usr/bin/env tsx
/**
 * Documentation Validator
 *
 * Validates that documentation is up-to-date and consistent with source code.
 * Checks:
 * - Auto-generated markers exist
 * - Platform tables are complete
 * - Codec tables are complete
 * - Timestamps match versions.properties
 */

import {readFileSync} from 'node:fs';
import {join, dirname} from 'node:path';
import {fileURLToPath} from 'node:url';
import {PLATFORMS, DEPRECATED_PLATFORMS} from './lib/platforms.ts';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

let hasErrors = false;

/**
 * Load codec information from full.json preset
 */
function loadCodecInfo(): {
  videoCodecs: Array<{id: string; library: string; enabled: boolean}>;
  audioCodecs: Array<{id: string; library: string; enabled: boolean}>;
} {
  const presetPath = join(__dirname, '..', 'presets', 'full.json');
  const content = JSON.parse(readFileSync(presetPath, 'utf-8'));

  const videoCodecs = Object.entries(content.codecs.video).map(([id, codec]: [string, any]) => ({
    id,
    library: codec.library,
    enabled: codec.enabled,
  }));

  const audioCodecs = Object.entries(content.codecs.audio).map(([id, codec]: [string, any]) => ({
    id,
    library: codec.library,
    enabled: codec.enabled,
  }));

  return {videoCodecs, audioCodecs};
}

/**
 * Validate that auto-generated markers exist in all required files
 */
function validateMarkers(): void {
  const readme = readFileSync(join(__dirname, '..', 'README.md'), 'utf-8');
  const hardware = readFileSync(join(__dirname, '..', 'HARDWARE.md'), 'utf-8');
  const codecs = readFileSync(join(__dirname, '..', 'CODECS.md'), 'utf-8');

  const requiredMarkers = [
    {
      file: 'README.md',
      content: readme,
      markers: ['platform-table', 'video-codec-table', 'audio-codec-table'],
    },
    {file: 'HARDWARE.md', content: hardware, markers: ['hw-platform-table', 'timestamp']},
    {file: 'CODECS.md', content: codecs, markers: ['codec-list', 'timestamp']},
  ];

  for (const {file, content, markers} of requiredMarkers) {
    for (const marker of markers) {
      const start = `<!-- AUTO-GENERATED:${marker}:START -->`;
      const end = `<!-- AUTO-GENERATED:${marker}:END -->`;

      if (!content.includes(start) || !content.includes(end)) {
        console.error(`✗ ${file} missing auto-generated markers for ${marker}`);
        hasErrors = true;
      }
    }
  }

  if (!hasErrors) {
    console.log('✓ Marker validation passed');
  }
}

/**
 * Validate that all active platforms are documented
 */
function validatePlatformTables(): void {
  const readme = readFileSync(join(__dirname, '..', 'README.md'), 'utf-8');
  const hardware = readFileSync(join(__dirname, '..', 'HARDWARE.md'), 'utf-8');

  // Check that all non-deprecated platforms are mentioned
  const activePlatforms = PLATFORMS.filter(
    (p) => !DEPRECATED_PLATFORMS.includes(p.name as typeof DEPRECATED_PLATFORMS[number])
  );

  for (const platform of activePlatforms) {
    const pkgName = `@pproenca/ffmpeg-${platform.name}`;

    if (!readme.includes(pkgName) && !hardware.includes(pkgName)) {
      console.error(`✗ Platform ${platform.name} not documented in README.md or HARDWARE.md`);
      hasErrors = true;
    }
  }

  if (!hasErrors) {
    console.log('✓ Platform table validation passed');
  }
}

/**
 * Validate that enabled codecs are documented
 */
function validateCodecTables(): void {
  const readme = readFileSync(join(__dirname, '..', 'README.md'), 'utf-8');
  const codecsDoc = readFileSync(join(__dirname, '..', 'CODECS.md'), 'utf-8');

  const {videoCodecs, audioCodecs} = loadCodecInfo();

  const enabledVideoCodecs = videoCodecs.filter((c) => c.enabled);
  const enabledAudioCodecs = audioCodecs.filter((c) => c.enabled);

  for (const codec of enabledVideoCodecs) {
    if (!readme.includes(codec.library) && !codecsDoc.includes(codec.library)) {
      console.error(`✗ Video codec ${codec.id} (${codec.library}) not documented`);
      hasErrors = true;
    }
  }

  for (const codec of enabledAudioCodecs) {
    if (!readme.includes(codec.library) && !codecsDoc.includes(codec.library)) {
      console.error(`✗ Audio codec ${codec.id} (${codec.library}) not documented`);
      hasErrors = true;
    }
  }

  if (!hasErrors) {
    console.log('✓ Codec table validation passed');
  }
}

/**
 * Validate that timestamps match versions.properties
 */
function validateTimestamps(): void {
  const versionsContent = readFileSync(join(__dirname, '..', 'versions.properties'), 'utf-8');
  const hardware = readFileSync(join(__dirname, '..', 'HARDWARE.md'), 'utf-8');
  const codecsDoc = readFileSync(join(__dirname, '..', 'CODECS.md'), 'utf-8');

  const dateMatch = versionsContent.match(/# Updated: (\d{4}-\d{2}-\d{2})/);
  const expectedDate = dateMatch ? dateMatch[1] : null;

  if (expectedDate) {
    if (!hardware.includes(expectedDate)) {
      console.error(`✗ HARDWARE.md timestamp doesn't match versions.properties (${expectedDate})`);
      hasErrors = true;
    }

    if (!codecsDoc.includes(expectedDate)) {
      console.error(`✗ CODECS.md timestamp doesn't match versions.properties (${expectedDate})`);
      hasErrors = true;
    }
  }

  if (!hasErrors) {
    console.log('✓ Timestamp validation passed');
  }
}

/**
 * Main entry point
 */
function main(): void {
  console.log('Validating documentation...\n');

  try {
    validateMarkers();
    validatePlatformTables();
    validateCodecTables();
    validateTimestamps();

    if (hasErrors) {
      console.error('\n❌ Documentation validation failed');
      console.error('\nTo fix: npm run gen');
      process.exit(1);
    }

    console.log('\n✅ All documentation validation checks passed!');
  } catch (error) {
    console.error('\n❌ Error during validation:');
    console.error(error);
    process.exit(1);
  }
}

// Run if invoked directly
if (import.meta.url === `file://${process.argv[1]}`) {
  main();
}
