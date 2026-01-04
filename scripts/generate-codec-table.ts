#!/usr/bin/env tsx
/**
 * Codec Table Generator
 *
 * Generates markdown tables for codec support from presets/full.json
 * (single source of truth for codec configurations).
 */

import {readFileSync} from 'node:fs';
import {join} from 'node:path';
import {getScriptDir, isMainModule} from './lib/paths.ts';

const __dirname = getScriptDir(import.meta.url);

interface Codec {
  enabled: boolean;
  library: string;
  license: string;
  description: string;
  configure_flag?: string;
  build_dependency?: string;
  notes?: string;
}

interface FullPreset {
  codecs: {
    video: Record<string, Codec>;
    audio: Record<string, Codec>;
  };
}

// Load full preset JSON
function loadFullPreset(): FullPreset {
  const presetPath = join(__dirname, '..', 'presets', 'full.json');
  const content = readFileSync(presetPath, 'utf-8');
  return JSON.parse(content) as FullPreset;
}

const fullPreset = loadFullPreset();

/**
 * Generate a markdown table for codecs
 */
function generateCodecTable(codecs: Record<string, Codec>): string {
  const entries = Object.entries(codecs).filter(([_, codec]) => codec.enabled);
  const rows = entries.map(([id, codec]) =>
    `| ${id.toUpperCase()} | ${codec.library} | ${codec.license} | ${codec.description} |`
  );
  return [
    '| Codec | Library | License | Description |',
    '|-------|---------|---------|-------------|',
    ...rows
  ].join('\n');
}

/**
 * Generate video codec table for README.md
 */
export const generateVideoCodecTable = (): string => generateCodecTable(fullPreset.codecs.video);

/**
 * Generate audio codec table for README.md
 */
export const generateAudioCodecTable = (): string => generateCodecTable(fullPreset.codecs.audio);

/**
 * Format detailed information for a single codec
 */
function formatCodecDetails(id: string, codec: Codec): string {
  let output = `### ${id.toUpperCase()} - ${codec.description}\n\n`;
  output += `- **Library:** ${codec.library}\n`;
  output += `- **License:** ${codec.license}\n`;
  output += `- **Status:** ${codec.enabled ? '✅ Enabled' : '❌ Disabled'}\n`;

  if (codec.configure_flag) {
    output += `- **Configure Flag:** \`${codec.configure_flag}\`\n`;
  }
  if (codec.build_dependency) {
    output += `- **Build Dependency:** ${codec.build_dependency}\n`;
  }
  if (codec.notes) {
    output += `- **Notes:** ${codec.notes}\n`;
  }

  return output + '\n';
}

/**
 * Generate detailed codec list for CODECS.md
 */
export function generateDetailedCodecList(): string {
  const videoDetails = Object.entries(fullPreset.codecs.video)
    .map(([id, codec]) => formatCodecDetails(id, codec))
    .join('');
  const audioDetails = Object.entries(fullPreset.codecs.audio)
    .map(([id, codec]) => formatCodecDetails(id, codec))
    .join('');

  return `## Video Codecs\n\n${videoDetails}## Audio Codecs\n\n${audioDetails}`;
}

// If run directly, output all tables
if (isMainModule(import.meta.url)) {
  console.log('Video Codec Table:');
  console.log('=================\n');
  console.log(generateVideoCodecTable());

  console.log('\n\nAudio Codec Table:');
  console.log('=================\n');
  console.log(generateAudioCodecTable());

  console.log('\n\nDetailed Codec List:');
  console.log('===================\n');
  console.log(generateDetailedCodecList());
}
