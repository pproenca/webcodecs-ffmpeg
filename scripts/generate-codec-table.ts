#!/usr/bin/env tsx
/**
 * Codec Table Generator
 *
 * Generates markdown tables for codec support from presets/full.json
 * (single source of truth for codec configurations).
 */

import {readFileSync} from 'node:fs';
import {join, dirname} from 'node:path';
import {fileURLToPath} from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

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
 * Generate video codec table for README.md
 */
export function generateVideoCodecTable(): string {
  const videoCodecs = Object.entries(fullPreset.codecs.video).filter(([_, codec]) => codec.enabled);

  const rows = videoCodecs.map(([id, codec]) => {
    const codecName = id.toUpperCase();
    return `| ${codecName} | ${codec.library} | ${codec.license} | ${codec.description} |`;
  });

  return ['| Codec | Library | License | Description |', '|-------|---------|---------|-------------|', ...rows].join(
    '\n'
  );
}

/**
 * Generate audio codec table for README.md
 */
export function generateAudioCodecTable(): string {
  const audioCodecs = Object.entries(fullPreset.codecs.audio).filter(([_, codec]) => codec.enabled);

  const rows = audioCodecs.map(([id, codec]) => {
    const codecName = id.toUpperCase();
    return `| ${codecName} | ${codec.library} | ${codec.license} | ${codec.description} |`;
  });

  return ['| Codec | Library | License | Description |', '|-------|---------|---------|-------------|', ...rows].join(
    '\n'
  );
}

/**
 * Generate detailed codec list for CODECS.md
 */
export function generateDetailedCodecList(): string {
  const videoCodecs = Object.entries(fullPreset.codecs.video);
  const audioCodecs = Object.entries(fullPreset.codecs.audio);

  let output = '## Video Codecs\n\n';

  for (const [id, codec] of videoCodecs) {
    const codecName = id.toUpperCase();
    output += `### ${codecName} - ${codec.description}\n\n`;
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

    output += '\n';
  }

  output += '## Audio Codecs\n\n';

  for (const [id, codec] of audioCodecs) {
    const codecName = id.toUpperCase();
    output += `### ${codecName} - ${codec.description}\n\n`;
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

    output += '\n';
  }

  return output;
}

// If run directly, output all tables
if (import.meta.url === `file://${process.argv[1]}`) {
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
