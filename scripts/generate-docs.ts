#!/usr/bin/env tsx
/**
 * Main Documentation Generator
 *
 * Orchestrates all documentation generation scripts to update markdown files
 * with auto-generated content from single sources of truth.
 */

import {readFileSync, writeFileSync} from 'node:fs';
import {join, dirname} from 'node:path';
import {fileURLToPath} from 'node:url';
import {generateStandardTable, generateHwTable} from './generate-platform-table.js';
import {
  generateVideoCodecTable,
  generateAudioCodecTable,
  generateDetailedCodecList,
} from './generate-codec-table.js';
import {generateTimestamp} from './update-doc-timestamps.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// Marker format for auto-generated sections
const MARKER_START = (id: string) => `<!-- AUTO-GENERATED:${id}:START -->`;
const MARKER_END = (id: string) => `<!-- AUTO-GENERATED:${id}:END -->`;

/**
 * Replace content between markers in a file
 */
function replaceSection(content: string, markerId: string, newContent: string): string {
  const start = MARKER_START(markerId);
  const end = MARKER_END(markerId);

  const regex = new RegExp(`${start}[\\s\\S]*?${end}`, 'g');

  if (!regex.test(content)) {
    console.warn(`⚠  Warning: Markers for ${markerId} not found in content`);
    return content;
  }

  return content.replace(regex, `${start}\n${newContent}\n${end}`);
}

/**
 * Update README.md with auto-generated tables
 */
function updateReadme(): void {
  const readmePath = join(__dirname, '..', 'README.md');
  const readme = readFileSync(readmePath, 'utf-8');

  let updated = readme;
  updated = replaceSection(updated, 'platform-table', generateStandardTable());
  updated = replaceSection(updated, 'video-codec-table', generateVideoCodecTable());
  updated = replaceSection(updated, 'audio-codec-table', generateAudioCodecTable());

  writeFileSync(readmePath, updated);
  console.log('✓ Updated README.md');
}

/**
 * Update HARDWARE.md with auto-generated content
 */
function updateHardware(): void {
  const hardwarePath = join(__dirname, '..', 'HARDWARE.md');
  const hardware = readFileSync(hardwarePath, 'utf-8');

  let updated = hardware;
  updated = replaceSection(updated, 'hw-platform-table', generateHwTable());
  updated = replaceSection(updated, 'timestamp', generateTimestamp());

  writeFileSync(hardwarePath, updated);
  console.log('✓ Updated HARDWARE.md');
}

/**
 * Update CODECS.md with auto-generated content
 */
function updateCodecs(): void {
  const codecsPath = join(__dirname, '..', 'CODECS.md');
  const codecs = readFileSync(codecsPath, 'utf-8');

  let updated = codecs;
  updated = replaceSection(updated, 'codec-list', generateDetailedCodecList());
  updated = replaceSection(updated, 'timestamp', generateTimestamp());

  writeFileSync(codecsPath, updated);
  console.log('✓ Updated CODECS.md');
}

/**
 * Main entry point
 */
function main(): void {
  console.log('Generating documentation...\n');

  try {
    updateReadme();
    updateHardware();
    updateCodecs();

    console.log('\n✅ Documentation generation complete!');
    console.log('\nNext steps:');
    console.log('  1. Review the changes: git diff');
    console.log('  2. Run validation: npm run validate-docs');
    console.log('  3. Commit changes: git add -A && git commit -m "docs: auto-update documentation"');
  } catch (error) {
    console.error('\n❌ Error generating documentation:');
    console.error(error);
    process.exit(1);
  }
}

// Run if invoked directly
if (import.meta.url === `file://${process.argv[1]}`) {
  main();
}
