#!/usr/bin/env tsx
/**
 * NPM Package Creation Script for FFmpeg Prebuilds
 *
 * Creates two types of packages per platform:
 * 1. Runtime packages: @pproenca/ffmpeg-<platform> (binaries only)
 * 2. Dev packages: @pproenca/ffmpeg-dev-<platform> (libs + headers)
 * 3. Main package: @pproenca/ffmpeg (meta-package with optionalDependencies)
 */
import {copyFileSync, existsSync, mkdirSync, readdirSync, statSync, writeFileSync} from 'node:fs';
import {join, resolve} from 'node:path';
import {execFileSync} from 'node:child_process';

interface Platform {
  name: string;
  os: string;
  cpu: string;
  libc?: 'glibc' | 'musl';
}

const PLATFORMS: Platform[] = [
  { name: 'darwin-x64', os: 'darwin', cpu: 'x64' },
  { name: 'darwin-arm64', os: 'darwin', cpu: 'arm64' },
  { name: 'linux-x64-glibc', os: 'linux', cpu: 'x64', libc: 'glibc' },
  { name: 'linux-x64-musl', os: 'linux', cpu: 'x64', libc: 'musl' },
];

const PROJECT_ROOT = resolve(__dirname, '..');
const ARTIFACTS_DIR = join(PROJECT_ROOT, 'artifacts');
const NPM_DIST_DIR = join(PROJECT_ROOT, 'npm-dist');
const VERSION = '8.0.0'; // Should match package.json

function ensureDir(pathname: string): void {
  mkdirSync(pathname, {recursive: true});
}

function copyRecursive(src: string, dest: string): void {
  if (!existsSync(src)) {
    return;
  }

  const stat = statSync(src);
  if (stat.isDirectory()) {
    ensureDir(dest);
    for (const entry of readdirSync(src)) {
      copyRecursive(join(src, entry), join(dest, entry));
    }
  } else {
    copyFileSync(src, dest);
  }
}

//=============================================================================
// Create Runtime Package (binaries only)
//=============================================================================
function createRuntimePackage(platform: Platform): string | null {
  const artifactDir = join(ARTIFACTS_DIR, platform.name);
  const binDir = join(artifactDir, 'bin');

  // Runtime packages only make sense if binaries exist
  if (!existsSync(binDir)) {
    console.log(`⚠  Skipping runtime package for ${platform.name} (no bin/ directory)`);
    return null;
  }

  const pkgName = `@pproenca/ffmpeg-${platform.name}`;
  const pkgDir = join(NPM_DIST_DIR, pkgName);

  console.log(`Creating runtime package: ${pkgName}`);

  // Create package structure
  ensureDir(join(pkgDir, 'bin'));

  // Copy binaries
  copyRecursive(binDir, join(pkgDir, 'bin'));

  // Create package.json
  const pkgJson: Record<string, unknown> = {
    name: pkgName,
    version: VERSION,
    description: `FFmpeg static binary for ${platform.os} ${platform.cpu}`,
    os: [platform.os],
    cpu: [platform.cpu],
    files: ['bin/'],
    license: 'GPL-2.0-or-later',
    repository: {
      type: 'git',
      url: 'https://github.com/pproenca/ffmpeg-prebuilds',
    },
    keywords: ['ffmpeg', 'video', 'audio', 'binary', platform.os, platform.cpu],
  };

  if (platform.libc) {
    pkgJson.libc = [platform.libc];
  }

  writeFileSync(join(pkgDir, 'package.json'), JSON.stringify(pkgJson, null, 2) + '\n');

  // Create minimal README
  writeFileSync(
    join(pkgDir, 'README.md'),
    `# ${pkgName}

FFmpeg static binary for ${platform.os} ${platform.cpu}${platform.libc ? ` (${platform.libc})` : ''}.

## Installation

\`\`\`bash
npm install ${pkgName}
\`\`\`

## Usage

\`\`\`javascript
const path = require('path');
const pkgPath = require.resolve('${pkgName}/package.json');
const ffmpegPath = path.join(path.dirname(pkgPath), 'bin', 'ffmpeg');
const ffprobePath = path.join(path.dirname(pkgPath), 'bin', 'ffprobe');

console.log('FFmpeg:', ffmpegPath);
console.log('ffprobe:', ffprobePath);
\`\`\`

Or use the main package \`@pproenca/ffmpeg\` for automatic platform detection.

## License

GPL-2.0-or-later
`
  );

  console.log(`✓ Created runtime package: ${pkgDir}`);
  return pkgDir;
}

//=============================================================================
// Create Development Package (libs + headers)
//=============================================================================
function createDevPackage(platform: Platform): string | null {
  const artifactDir = join(ARTIFACTS_DIR, platform.name);
  const libDir = join(artifactDir, 'lib');
  const includeDir = join(artifactDir, 'include');

  // Dev packages require lib and include
  if (!existsSync(libDir) || !existsSync(includeDir)) {
    console.log(`⚠  Skipping dev package for ${platform.name} (missing lib/ or include/)`);
    return null;
  }

  const pkgName = `@pproenca/ffmpeg-dev-${platform.name}`;
  const pkgDir = join(NPM_DIST_DIR, pkgName);

  console.log(`Creating dev package: ${pkgName}`);

  // Create package structure
  ensureDir(pkgDir);

  // Copy libraries and headers
  copyRecursive(libDir, join(pkgDir, 'lib'));
  copyRecursive(includeDir, join(pkgDir, 'include'));

  // Create package.json
  const pkgJson: Record<string, unknown> = {
    name: pkgName,
    version: VERSION,
    description: `FFmpeg development files (static libs + headers) for ${platform.os} ${platform.cpu}`,
    os: [platform.os],
    cpu: [platform.cpu],
    files: ['lib/', 'include/'],
    license: 'GPL-2.0-or-later',
    repository: {
      type: 'git',
      url: 'https://github.com/pproenca/ffmpeg-prebuilds',
    },
    keywords: ['ffmpeg', 'development', 'headers', 'static', platform.os, platform.cpu],
  };

  if (platform.libc) {
    pkgJson.libc = [platform.libc];
  }

  writeFileSync(join(pkgDir, 'package.json'), JSON.stringify(pkgJson, null, 2) + '\n');

  // Create README
  writeFileSync(
    join(pkgDir, 'README.md'),
    `# ${pkgName}

FFmpeg development files (static libraries + headers) for ${platform.os} ${platform.cpu}${platform.libc ? ` (${platform.libc})` : ''}.

## Installation

\`\`\`bash
npm install --save-dev ${pkgName}
\`\`\`

## Usage

Use with \`pkg-config\` for compiling native addons:

\`\`\`bash
export FFMPEG_ROOT="\$(npm root)/${pkgName}"
export PKG_CONFIG_PATH="\$FFMPEG_ROOT/lib/pkgconfig"

# Get include flags
pkg-config --cflags libavcodec libavformat libavutil

# Get library flags
pkg-config --libs --static libavcodec libavformat libavutil
\`\`\`

Or use in \`binding.gyp\` for Node.js native addons.

## License

GPL-2.0-or-later
`
  );

  console.log(`✓ Created dev package: ${pkgDir}`);
  return pkgDir;
}

//=============================================================================
// Create Main Package (meta-package)
//=============================================================================
function createMainPackage(runtimePkgs: string[]): string {
  const pkgName = '@pproenca/ffmpeg';
  const pkgDir = join(NPM_DIST_DIR, pkgName);

  console.log(`Creating main package: ${pkgName}`);

  ensureDir(pkgDir);

  // Create optionalDependencies from runtime packages
  const optionalDependencies: Record<string, string> = {};
  for (const platform of PLATFORMS) {
    const depName = `@pproenca/ffmpeg-${platform.name}`;
    optionalDependencies[depName] = VERSION;
  }

  // Create package.json
  const pkgJson = {
    name: pkgName,
    version: VERSION,
    description: 'FFmpeg static binaries for Node.js - automatic platform detection',
    main: 'index.js',
    types: 'index.d.ts',
    scripts: {
      postinstall: 'node install.js || true',
    },
    optionalDependencies,
    license: 'GPL-2.0-or-later',
    repository: {
      type: 'git',
      url: 'https://github.com/pproenca/ffmpeg-prebuilds',
    },
    keywords: ['ffmpeg', 'video', 'audio', 'encoding', 'decoding', 'webcodecs', 'prebuilt'],
    engines: {
      node: '>=16.0.0',
    },
  };

  writeFileSync(join(pkgDir, 'package.json'), JSON.stringify(pkgJson, null, 2) + '\n');

  // Create index.js (binary path resolver)
  writeFileSync(
    join(pkgDir, 'index.js'),
    `const path = require('path');

const PLATFORMS = {
  'darwin-arm64': '@pproenca/ffmpeg-darwin-arm64',
  'darwin-x64': '@pproenca/ffmpeg-darwin-x64',
  'linux-x64-glibc': '@pproenca/ffmpeg-linux-x64-glibc',
  'linux-x64-musl': '@pproenca/ffmpeg-linux-x64-musl',
};

function getPlatformKey() {
  const platform = \`\${process.platform}-\${process.arch}\`;

  if (process.platform === 'linux') {
    // Detect musl vs glibc
    const isMusl = process.report?.getReport?.()?.header?.glibcVersionRuntime === undefined;
    return isMusl ? \`\${platform}-musl\` : \`\${platform}-glibc\`;
  }

  return platform;
}

function getBinaryPath(binary = 'ffmpeg') {
  const platformKey = getPlatformKey();
  const pkg = PLATFORMS[platformKey];

  if (!pkg) {
    throw new Error(
      \`Unsupported platform: \${platformKey}. \` +
      \`Supported: \${Object.keys(PLATFORMS).join(', ')}\`
    );
  }

  try {
    const pkgPath = require.resolve(\`\${pkg}/package.json\`);
    return path.join(path.dirname(pkgPath), 'bin', binary);
  } catch (e) {
    throw new Error(
      \`Binary package \${pkg} not found. \` +
      \`Run: npm install --include=optional\`
    );
  }
}

module.exports = {
  getBinaryPath,
  ffmpegPath: getBinaryPath('ffmpeg'),
  ffprobePath: getBinaryPath('ffprobe'),
};
`
  );

  // Create TypeScript definitions
  writeFileSync(
    join(pkgDir, 'index.d.ts'),
    `export function getBinaryPath(binary?: 'ffmpeg' | 'ffprobe'): string;
export const ffmpegPath: string;
export const ffprobePath: string;
`
  );

  // Create install.js (postinstall verification)
  writeFileSync(
    join(pkgDir, 'install.js'),
    `try {
  const { getBinaryPath } = require('./index');
  const { execSync } = require('child_process');

  const ffmpegPath = getBinaryPath('ffmpeg');
  const version = execSync(\`"\${ffmpegPath}" -version\`, { encoding: 'utf8' });
  console.log('✓ FFmpeg binary verified:', ffmpegPath);
  console.log(version.split('\\n')[0]);
} catch (e) {
  console.warn('⚠ FFmpeg binary not found for this platform');
  console.warn(e.message);
  console.warn('This is expected on unsupported platforms');
}
`
  );

  // Create README
  writeFileSync(
    join(pkgDir, 'README.md'),
    `# @pproenca/ffmpeg

FFmpeg static binaries for Node.js with automatic platform detection.

## Installation

\`\`\`bash
npm install @pproenca/ffmpeg
\`\`\`

## Usage

\`\`\`javascript
const { ffmpegPath, ffprobePath } = require('@pproenca/ffmpeg');

console.log('FFmpeg:', ffmpegPath);
console.log('ffprobe:', ffprobePath);

// Use with child_process
const { execSync } = require('child_process');
const output = execSync(\`"\${ffmpegPath}" -version\`, { encoding: 'utf8' });
console.log(output);
\`\`\`

## Supported Platforms

- macOS (x64, arm64)
- Linux (x64 with glibc or musl)

## Development Files

For native addon development, use the \`@pproenca/ffmpeg-dev-*\` packages:

\`\`\`bash
npm install --save-dev @pproenca/ffmpeg-dev-linux-x64-glibc
\`\`\`

## License

GPL-2.0-or-later (due to inclusion of x264 and x265)
`
  );

  console.log(`✓ Created main package: ${pkgDir}`);
  return pkgDir;
}

//=============================================================================
// Main
//=============================================================================
function main(): number {
  console.log('========================================');
  console.log('Creating NPM Packages');
  console.log('========================================');
  console.log('');

  // Clean dist directory
  ensureDir(NPM_DIST_DIR);

  const runtimePkgs: string[] = [];
  const devPkgs: string[] = [];

  // Create packages for each platform
  for (const platform of PLATFORMS) {
    console.log(`\n--- Platform: ${platform.name} ---`);

    const runtimePkg = createRuntimePackage(platform);
    if (runtimePkg) {
      runtimePkgs.push(runtimePkg);
    }

    const devPkg = createDevPackage(platform);
    if (devPkg) {
      devPkgs.push(devPkg);
    }
  }

  // Create main meta-package
  console.log('');
  createMainPackage(runtimePkgs);

  console.log('');
  console.log('========================================');
  console.log('Package Creation Complete');
  console.log('========================================');
  console.log(`Runtime packages: ${runtimePkgs.length}`);
  console.log(`Dev packages: ${devPkgs.length}`);
  console.log(`Output directory: ${NPM_DIST_DIR}`);
  console.log('');
  console.log('To publish:');
  console.log('  cd npm-dist');
  console.log('  npm publish @pproenca/ffmpeg-* --access public');
  console.log('  npm publish @pproenca/ffmpeg --access public');

  return 0;
}

// Run if invoked directly
if (require.main === module) {
  process.exit(main());
}
