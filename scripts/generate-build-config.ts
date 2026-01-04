#!/usr/bin/env tsx
/**
 * Generate Build Configuration
 *
 * Reads template from presets/{name}.json, injects version info from
 * versions.properties, outputs to build-config.json.
 *
 * Usage:
 *   tsx scripts/generate-build-config.ts                    # Output to build-config.json
 *   tsx scripts/generate-build-config.ts --preset minimal   # Use presets/minimal.json
 *   tsx scripts/generate-build-config.ts --stdout           # Preview to stdout
 */

import {readFile, writeFile, access} from 'node:fs/promises';
import {join, dirname, basename} from 'node:path';
import {fileURLToPath} from 'node:url';
import {parseVersionsFile as parseVersionsFileRaw} from './lib/versions.ts';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// ============================================================================
// Types
// ============================================================================

interface CodecConfig {
  enabled: boolean;
  library: string;
  license: string;
  description: string;
  configure_flag?: string;
  build_dependency?: string;
  notes?: string;
}

interface FeatureConfig {
  enabled: boolean;
  description: string;
  dependencies?: string[];
  configure_flags?: string[];
  impact?: string;
  notes?: string;
}

interface OptimizationConfig {
  enabled: boolean;
  description: string;
  configure_flags?: string[];
  impact?: string;
  notes?: string;
}

interface BuildOption {
  enabled: boolean;
  description: string;
  configure_flags?: string[];
  impact?: string;
  notes?: string;
}

interface LicenseConfig {
  enabled: boolean;
  description: string;
  configure_flags?: string[];
  impact?: string;
  notes?: string;
}

interface MetadataConfig {
  preset: string;
  description: string;
  use_case: string;
  binary_size_estimate?: string;
  build_time_estimate?: string;
  versions?: Record<string, string>;
}

interface BuildConfig {
  $schema?: string;
  title?: string;
  description?: string;
  version?: string;
  codecs: {
    video: Record<string, CodecConfig>;
    audio: Record<string, CodecConfig>;
  };
  features: Record<string, FeatureConfig>;
  optimization: Record<string, OptimizationConfig>;
  build: Record<string, BuildOption>;
  license: Record<string, LicenseConfig>;
  metadata: MetadataConfig;
}

interface VersionsMap {
  [key: string]: string;
}

// ============================================================================
// Utility Functions
// ============================================================================

/**
 * Parse versions.properties and extract only _VERSION keys
 */
async function parseVersionsForConfig(filePath: string): Promise<VersionsMap> {
  try {
    const raw = await parseVersionsFileRaw(filePath);
    const versions: VersionsMap = {};

    for (const [key, value] of Object.entries(raw)) {
      if (key.endsWith('_VERSION')) {
        const simpleName = key.replace('_VERSION', '').toLowerCase();
        versions[simpleName] = value;
      }
    }

    return versions;
  } catch {
    console.warn('Warning: Could not parse versions.properties');
    return {};
  }
}

/**
 * Load preset from file
 */
async function loadPreset(presetName: string): Promise<BuildConfig> {
  const projectRoot = join(__dirname, '..');
  let presetPath: string;

  // Check if presetName is an absolute path
  if (presetName.startsWith('/')) {
    presetPath = presetName;
  }
  // Check if presetName is a relative path
  else if (presetName.includes('/')) {
    presetPath = join(process.cwd(), presetName);
  }
  // Otherwise, look in presets/ directory
  else {
    const presetFileName = presetName.endsWith('.json')
      ? presetName
      : `${presetName}.json`;
    presetPath = join(projectRoot, 'presets', presetFileName);
  }

  try {
    await access(presetPath);
  } catch {
    throw new Error(
      `Preset not found: ${presetPath}\nAvailable presets: full, minimal, streaming`,
    );
  }

  const content = await readFile(presetPath, 'utf-8');
  return JSON.parse(content) as BuildConfig;
}

/**
 * Inject version information into config
 */
function injectVersions(config: BuildConfig, versions: VersionsMap): BuildConfig {
  // Create a deep copy to avoid mutating the original
  const result: BuildConfig = JSON.parse(JSON.stringify(config));

  // Add versions to metadata
  if (!result.metadata.versions) {
    result.metadata.versions = {};
  }

  // Inject all version information
  Object.assign(result.metadata.versions, versions);

  return result;
}

/**
 * Validate basic config structure
 */
function validateConfig(config: BuildConfig): void {
  if (!config.codecs || !config.codecs.video || !config.codecs.audio) {
    throw new Error('Invalid config: missing codecs section');
  }

  if (!config.features) {
    throw new Error('Invalid config: missing features section');
  }

  if (!config.optimization) {
    throw new Error('Invalid config: missing optimization section');
  }

  if (!config.build) {
    throw new Error('Invalid config: missing build section');
  }

  if (!config.license) {
    throw new Error('Invalid config: missing license section');
  }

  if (!config.metadata) {
    throw new Error('Invalid config: missing metadata section');
  }
}

/**
 * Generate build config with version info
 */
async function generateConfig(
  presetName: string,
  versionsFile: string,
  includeVersions: boolean,
): Promise<BuildConfig> {
  // Load preset template
  const config = await loadPreset(presetName);

  // Validate structure
  validateConfig(config);

  // Optionally inject versions
  if (includeVersions) {
    const versions = await parseVersionsForConfig(versionsFile);
    return injectVersions(config, versions);
  }

  return config;
}

/**
 * Format config as JSON string
 */
function formatConfig(config: BuildConfig): string {
  return JSON.stringify(config, null, 2) + '\n';
}

// ============================================================================
// Main Logic
// ============================================================================

/**
 * Main entry point
 */
async function main(): Promise<void> {
  const args = process.argv.slice(2);

  // Parse CLI arguments
  let presetName = 'full';
  let outputPath = join(__dirname, '..', 'build-config.json');
  let writeMode = true;
  let includeVersions = true;

  for (let i = 0; i < args.length; i++) {
    const arg = args[i];

    if (arg === '--preset' && i + 1 < args.length) {
      presetName = args[i + 1];
      i++;
    } else if (arg === '--output' && i + 1 < args.length) {
      outputPath = args[i + 1];
      i++;
    } else if (arg === '--stdout') {
      writeMode = false;
    } else if (arg === '--no-versions') {
      includeVersions = false;
    } else if (arg === '--help' || arg === '-h') {
      console.log(`
Generate Build Configuration

Usage:
  tsx scripts/generate-build-config.ts [options]

Options:
  --preset <name>     Preset name or path (default: full)
                      Available presets: full, minimal, streaming
  --output <path>     Output file path (default: build-config.json)
  --stdout            Output to stdout instead of file
  --no-versions       Don't inject version metadata
  --help, -h          Show this help message

Examples:
  tsx scripts/generate-build-config.ts
  tsx scripts/generate-build-config.ts --preset minimal
  tsx scripts/generate-build-config.ts --preset streaming --output custom.json
  tsx scripts/generate-build-config.ts --stdout
`);
      process.exit(0);
    }
  }

  console.log('========================================');
  console.log('Build Configuration Generator');
  console.log('========================================\n');

  try {
    const versionsFile = join(__dirname, '..', 'versions.properties');

    // Generate config
    console.log(`Loading preset: ${presetName}`);
    const config = await generateConfig(presetName, versionsFile, includeVersions);

    // Count enabled codecs
    const videoCount = Object.values(config.codecs.video).filter((c) => c.enabled).length;
    const audioCount = Object.values(config.codecs.audio).filter((c) => c.enabled).length;

    console.log(`  ✓ ${videoCount} video codecs enabled`);
    console.log(`  ✓ ${audioCount} audio codecs enabled`);

    if (includeVersions && config.metadata.versions) {
      const versionCount = Object.keys(config.metadata.versions).length;
      console.log(`  ✓ ${versionCount} version entries injected`);
    }

    // Format output
    const output = formatConfig(config);

    // Write or print
    if (writeMode) {
      await writeFile(outputPath, output, 'utf-8');
      console.log(`\n✓ Written to: ${outputPath}`);
    } else {
      console.log('\n========================================');
      console.log('Generated Configuration');
      console.log('========================================\n');
      console.log(output);
    }

    console.log('\nℹ Configuration details:');
    console.log(`  Preset: ${config.metadata.preset}`);
    console.log(`  Description: ${config.metadata.description}`);
    if (config.metadata.binary_size_estimate) {
      console.log(`  Binary size: ${config.metadata.binary_size_estimate}`);
    }
    if (config.metadata.build_time_estimate) {
      console.log(`  Build time: ${config.metadata.build_time_estimate}`);
    }

    process.exit(0);
  } catch (error) {
    console.error('\n❌ Error generating configuration:');
    console.error(error instanceof Error ? error.message : error);
    process.exit(1);
  }
}

// Run if invoked directly
if (import.meta.url === `file://${process.argv[1]}`) {
  main();
}
