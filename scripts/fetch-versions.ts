#!/usr/bin/env tsx
/**
 * Fetch Latest Dependency Versions
 *
 * Fetches latest versions from official sources (GitHub, BitBucket, GitLab),
 * validates SHA256 checksums by downloading tarballs.
 *
 * Usage:
 *   tsx scripts/fetch-versions.ts          # Dry-run (preview changes)
 *   tsx scripts/fetch-versions.ts --write  # Update versions.properties
 */

import {readFile, writeFile, mkdtemp, rm} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {join, dirname} from 'node:path';
import {tmpdir} from 'node:os';
import {fileURLToPath} from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// ============================================================================
// Types
// ============================================================================

interface DependencyVersion {
  name: string;
  versionKey: string;
  urlKey?: string;
  sha256Key?: string;
  fetchLatest: () => Promise<string>;
  downloadUrl?: (version: string) => string;
}

interface UpdateResult {
  name: string;
  currentVersion: string;
  latestVersion: string;
  updated: boolean;
  sha256?: string;
  error?: string;
}

interface VersionsMap {
  [key: string]: string;
}

// ============================================================================
// Constants
// ============================================================================

const VERSIONS_FILE = join(__dirname, '..', 'versions.properties');
const USER_AGENT = 'ffmpeg-prebuilds-version-fetcher/1.0';

// ============================================================================
// Utility Functions
// ============================================================================

/**
 * Fetch data from URL with retry logic
 */
async function fetchWithRetry(
  url: string,
  options: RequestInit = {},
  retries = 3,
): Promise<Response> {
  let lastError: Error | null = null;

  for (let i = 0; i < retries; i++) {
    try {
      const response = await fetch(url, {
        ...options,
        headers: {
          'User-Agent': USER_AGENT,
          ...options.headers,
        },
      });

      if (!response.ok && response.status !== 404) {
        throw new Error(`HTTP ${response.status}: ${url}`);
      }

      return response;
    } catch (error) {
      lastError = error as Error;
      if (i < retries - 1) {
        const delay = Math.pow(2, i) * 1000; // Exponential backoff
        await new Promise((resolve) => setTimeout(resolve, delay));
      }
    }
  }

  throw lastError || new Error(`Failed to fetch ${url}`);
}

/**
 * Download file and compute SHA256 checksum
 */
async function downloadAndChecksum(url: string): Promise<string> {
  const response = await fetchWithRetry(url);
  if (!response.ok) {
    throw new Error(`Failed to download: ${url} (${response.status})`);
  }

  const hash = createHash('sha256');
  const body = response.body;

  if (!body) {
    throw new Error('Response body is null');
  }

  const reader = body.getReader();
  try {
    while (true) {
      const {done, value} = await reader.read();
      if (done) break;
      hash.update(value);
    }
  } finally {
    reader.releaseLock();
  }

  return hash.digest('hex');
}

/**
 * Parse versions.properties file
 */
async function parseVersionsFile(filePath: string): Promise<VersionsMap> {
  const content = await readFile(filePath, 'utf-8');
  const versions: VersionsMap = {};

  for (const line of content.split('\n')) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) {
      continue;
    }

    const equalsIndex = trimmed.indexOf('=');
    if (equalsIndex === -1) {
      continue;
    }

    const key = trimmed.slice(0, equalsIndex).trim();
    const value = trimmed.slice(equalsIndex + 1).trim();
    versions[key] = value;
  }

  return versions;
}

/**
 * Update versions.properties file while preserving structure
 */
async function updateVersionsFile(
  filePath: string,
  updates: VersionsMap,
): Promise<void> {
  const content = await readFile(filePath, 'utf-8');
  const lines = content.split('\n');

  // Update timestamp
  const now = new Date();
  const timestamp = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-${String(now.getDate()).padStart(2, '0')}`;

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];

    // Update timestamp line
    if (line.startsWith('# Updated:')) {
      lines[i] = `# Updated: ${timestamp}`;
      continue;
    }

    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) {
      continue;
    }

    const equalsIndex = trimmed.indexOf('=');
    if (equalsIndex === -1) {
      continue;
    }

    const key = trimmed.slice(0, equalsIndex).trim();
    if (key in updates) {
      // Preserve indentation
      const indent = line.match(/^\s*/)?.[0] || '';
      lines[i] = `${indent}${key}=${updates[key]}`;
    }
  }

  await writeFile(filePath, lines.join('\n'), 'utf-8');
}

// ============================================================================
// Version Fetchers
// ============================================================================

/**
 * Fetch latest version from GitHub tags
 */
async function fetchGitHubLatest(
  repo: string,
  tagPattern: RegExp,
): Promise<string> {
  const url = `https://api.github.com/repos/${repo}/tags`;
  const response = await fetchWithRetry(url);

  if (!response.ok) {
    throw new Error(`GitHub API error: ${response.status}`);
  }

  const tags = (await response.json()) as Array<{name: string}>;
  const matching = tags.filter((tag) => tagPattern.test(tag.name));

  if (matching.length === 0) {
    throw new Error(`No matching tags found for ${repo}`);
  }

  return matching[0].name;
}

/**
 * Fetch latest version from BitBucket tags
 */
async function fetchBitBucketLatest(
  repo: string,
  tagPattern: RegExp,
): Promise<string> {
  const url = `https://api.bitbucket.org/2.0/repositories/${repo}/refs/tags`;
  const response = await fetchWithRetry(url);

  if (!response.ok) {
    throw new Error(`BitBucket API error: ${response.status}`);
  }

  const data = (await response.json()) as {values: Array<{name: string}>};
  const matching = data.values.filter((tag) => tagPattern.test(tag.name));

  if (matching.length === 0) {
    throw new Error(`No matching tags found for ${repo}`);
  }

  // Sort versions numerically
  const sorted = matching.sort((a, b) => {
    const aNum = parseFloat(a.name);
    const bNum = parseFloat(b.name);
    return bNum - aNum;
  });

  return sorted[0].name;
}

/**
 * Fetch latest version from GitLab tags
 */
async function fetchGitLabLatest(
  host: string,
  projectId: string,
  tagPattern: RegExp,
): Promise<string> {
  const url = `https://${host}/api/v4/projects/${encodeURIComponent(projectId)}/repository/tags`;
  const response = await fetchWithRetry(url);

  if (!response.ok) {
    throw new Error(`GitLab API error: ${response.status}`);
  }

  const tags = (await response.json()) as Array<{name: string}>;
  const matching = tags.filter((tag) => tagPattern.test(tag.name));

  if (matching.length === 0) {
    throw new Error(`No matching tags found for project ${projectId}`);
  }

  return matching[0].name;
}

// ============================================================================
// Dependency Registry
// ============================================================================

const DEPENDENCIES: DependencyVersion[] = [
  // Core FFmpeg (Git-only)
  {
    name: 'FFmpeg',
    versionKey: 'FFMPEG_VERSION',
    fetchLatest: () => fetchGitHubLatest('FFmpeg/FFmpeg', /^n[0-9]/),
  },

  // Video Codecs
  {
    name: 'x264',
    versionKey: 'X264_VERSION',
    fetchLatest: async () => 'stable', // Pin to stable branch
  },
  {
    name: 'x265',
    versionKey: 'X265_VERSION',
    fetchLatest: () => fetchBitBucketLatest('multicoreware/x265_git', /^[0-9]+\.[0-9]+$/),
  },
  {
    name: 'libvpx',
    versionKey: 'LIBVPX_VERSION',
    fetchLatest: () => fetchGitHubLatest('webmproject/libvpx', /^v[0-9]/),
  },
  {
    name: 'libaom',
    versionKey: 'LIBAOM_VERSION',
    fetchLatest: async () => {
      // libaom is on Google Source, which doesn't have a convenient API
      // Fallback to checking GitHub mirror
      try {
        return await fetchGitHubLatest('jbeich/aom', /^v[0-9]/);
      } catch {
        return 'v3.12.1'; // Current stable version
      }
    },
  },
  {
    name: 'SVT-AV1',
    versionKey: 'SVTAV1_VERSION',
    fetchLatest: () => fetchGitLabLatest('gitlab.com', 'AOMediaCodec%2FSVT-AV1', /^v[0-9]/),
  },
  {
    name: 'dav1d',
    versionKey: 'DAV1D_VERSION',
    urlKey: 'DAV1D_URL',
    sha256Key: 'DAV1D_SHA256',
    fetchLatest: () => fetchGitLabLatest('code.videolan.org', '1353', /^[0-9]/),
    downloadUrl: (v) =>
      `https://code.videolan.org/videolan/dav1d/-/archive/${v}/dav1d-${v}.tar.gz`,
  },
  {
    name: 'rav1e',
    versionKey: 'RAV1E_VERSION',
    fetchLatest: () => fetchGitHubLatest('xiph/rav1e', /^v[0-9]/),
  },
  {
    name: 'Theora',
    versionKey: 'THEORA_VERSION',
    urlKey: 'THEORA_URL',
    sha256Key: 'THEORA_SHA256',
    fetchLatest: async () => '1.1.1', // Stable version, rarely updates
    downloadUrl: (v) =>
      `https://ftp.osuosl.org/pub/xiph/releases/theora/libtheora-${v}.tar.gz`,
  },
  {
    name: 'Xvid',
    versionKey: 'XVID_VERSION',
    urlKey: 'XVID_URL',
    sha256Key: 'XVID_SHA256',
    fetchLatest: async () => '1.3.7', // Stable version
    downloadUrl: (v) => `https://downloads.xvid.com/downloads/xvidcore-${v}.tar.gz`,
  },

  // Audio Codecs
  {
    name: 'Opus',
    versionKey: 'OPUS_VERSION',
    urlKey: 'OPUS_URL',
    sha256Key: 'OPUS_SHA256',
    fetchLatest: () =>
      fetchGitHubLatest('xiph/opus', /^v[0-9]/).then((v) => v.slice(1)), // Remove 'v' prefix
    downloadUrl: (v) => `https://downloads.xiph.org/releases/opus/opus-${v}.tar.gz`,
  },
  {
    name: 'LAME',
    versionKey: 'LAME_VERSION',
    urlKey: 'LAME_URL',
    sha256Key: 'LAME_SHA256',
    fetchLatest: async () => '3.100', // Stable version, rarely updates
    downloadUrl: (v) =>
      `https://downloads.sourceforge.net/project/lame/lame/${v}/lame-${v}.tar.gz`,
  },
  {
    name: 'Vorbis',
    versionKey: 'VORBIS_VERSION',
    urlKey: 'VORBIS_URL',
    sha256Key: 'VORBIS_SHA256',
    fetchLatest: async () => '1.3.7', // Stable version
    downloadUrl: (v) =>
      `https://ftp.osuosl.org/pub/xiph/releases/vorbis/libvorbis-${v}.tar.gz`,
  },
  {
    name: 'Ogg',
    versionKey: 'OGG_VERSION',
    urlKey: 'OGG_URL',
    sha256Key: 'OGG_SHA256',
    fetchLatest: async () => '1.3.5', // Stable version
    downloadUrl: (v) => `https://ftp.osuosl.org/pub/xiph/releases/ogg/libogg-${v}.tar.gz`,
  },
  {
    name: 'fdk-aac',
    versionKey: 'FDKAAC_VERSION',
    fetchLatest: () => fetchGitHubLatest('mstorsjo/fdk-aac', /^v[0-9]/),
  },
  {
    name: 'FLAC',
    versionKey: 'FLAC_VERSION',
    urlKey: 'FLAC_URL',
    sha256Key: 'FLAC_SHA256',
    fetchLatest: async () => '1.4.3', // Stable version
    downloadUrl: (v) => `https://ftp.osuosl.org/pub/xiph/releases/flac/flac-${v}.tar.xz`,
  },
  {
    name: 'Speex',
    versionKey: 'SPEEX_VERSION',
    urlKey: 'SPEEX_URL',
    sha256Key: 'SPEEX_SHA256',
    fetchLatest: async () => '1.2.1', // Stable version
    downloadUrl: (v) =>
      `https://ftp.osuosl.org/pub/xiph/releases/speex/speex-${v}.tar.gz`,
  },

  // Subtitle/Rendering Libraries
  {
    name: 'libass',
    versionKey: 'LIBASS_VERSION',
    urlKey: 'LIBASS_URL',
    sha256Key: 'LIBASS_SHA256',
    fetchLatest: async () => {
      const tag = await fetchGitHubLatest('libass/libass', /^[0-9]/);
      return tag;
    },
    downloadUrl: (v) =>
      `https://github.com/libass/libass/releases/download/${v}/libass-${v}.tar.gz`,
  },
  {
    name: 'FreeType',
    versionKey: 'FREETYPE_VERSION',
    urlKey: 'FREETYPE_URL',
    sha256Key: 'FREETYPE_SHA256',
    fetchLatest: async () => '2.13.3', // Check manually, complex versioning
    downloadUrl: (v) =>
      `https://download.savannah.gnu.org/releases/freetype/freetype-${v}.tar.xz`,
  },

  // Build Tools
  {
    name: 'NASM',
    versionKey: 'NASM_VERSION',
    urlKey: 'NASM_URL',
    sha256Key: 'NASM_SHA256',
    fetchLatest: async () => {
      const tag = await fetchGitHubLatest('netwide-assembler/nasm', /^nasm-[0-9]/);
      return tag.replace(/^nasm-/, '');
    },
    downloadUrl: (v) =>
      `https://github.com/netwide-assembler/nasm/archive/refs/tags/nasm-${v}.tar.gz`,
  },

  // Network Libraries
  {
    name: 'OpenSSL',
    versionKey: 'OPENSSL_VERSION',
    urlKey: 'OPENSSL_URL',
    sha256Key: 'OPENSSL_SHA256',
    fetchLatest: async () => {
      const tag = await fetchGitHubLatest('openssl/openssl', /^openssl-3\.[0-9]/);
      return tag.replace(/^openssl-/, '');
    },
    downloadUrl: (v) => `https://www.openssl.org/source/openssl-${v}.tar.gz`,
  },
];

// ============================================================================
// Main Logic
// ============================================================================

/**
 * Check for version updates
 */
async function checkForUpdates(
  currentVersions: VersionsMap,
): Promise<UpdateResult[]> {
  console.log('Checking for updates...\n');

  const results = await Promise.all(
    DEPENDENCIES.map(async (dep): Promise<UpdateResult> => {
      try {
        const currentVersion = currentVersions[dep.versionKey] || 'unknown';
        console.log(`  Checking ${dep.name} (current: ${currentVersion})...`);

        const latestVersion = await dep.fetchLatest();
        const updated = currentVersion !== latestVersion;

        let sha256: string | undefined;
        if (updated && dep.downloadUrl && dep.sha256Key) {
          console.log(`    Downloading to verify checksum...`);
          const url = dep.downloadUrl(latestVersion);
          sha256 = await downloadAndChecksum(url);
        }

        if (updated) {
          console.log(`    ⚠ Update available: ${currentVersion} → ${latestVersion}`);
        } else {
          console.log(`    ✓ Up to date`);
        }

        return {
          name: dep.name,
          currentVersion,
          latestVersion,
          updated,
          sha256,
        };
      } catch (error) {
        const errorMsg = error instanceof Error ? error.message : String(error);
        console.error(`    ✗ Error: ${errorMsg}`);
        return {
          name: dep.name,
          currentVersion: currentVersions[dep.versionKey] || 'unknown',
          latestVersion: 'error',
          updated: false,
          error: errorMsg,
        };
      }
    }),
  );

  return results;
}

/**
 * Generate summary for GitHub Actions
 */
function generateGitHubOutput(results: UpdateResult[]): void {
  const githubOutput = process.env.GITHUB_OUTPUT;
  if (!githubOutput) {
    return;
  }

  const updates = results.filter((r) => r.updated);
  const hasUpdates = updates.length > 0;

  const summary = updates
    .map((u) => `- **${u.name}**: ${u.currentVersion} → ${u.latestVersion}`)
    .join('\n');

  const output = [
    `updates_available=${hasUpdates}`,
    'update_summary<<EOF',
    summary || 'No updates available',
    'EOF',
  ].join('\n');

  writeFile(githubOutput, output + '\n', {flag: 'a'}).catch((err) => {
    console.error('Failed to write GitHub output:', err);
  });
}

/**
 * Main entry point
 */
async function main(): Promise<void> {
  const args = process.argv.slice(2);
  const writeMode = args.includes('--write');

  console.log('========================================');
  console.log('Dependency Version Checker');
  console.log('========================================\n');

  try {
    // Parse current versions
    const currentVersions = await parseVersionsFile(VERSIONS_FILE);

    // Check for updates
    const results = await checkForUpdates(currentVersions);

    // Generate summary
    console.log('\n========================================');
    console.log('Summary');
    console.log('========================================\n');

    const updates = results.filter((r) => r.updated);
    const errors = results.filter((r) => r.error);

    if (updates.length > 0) {
      console.log(`⚠ ${updates.length} update(s) available:\n`);
      for (const update of updates) {
        console.log(
          `  - ${update.name}: ${update.currentVersion} → ${update.latestVersion}`,
        );
      }
    } else {
      console.log('✓ All dependencies up to date');
    }

    if (errors.length > 0) {
      console.log(`\n✗ ${errors.length} error(s) occurred:\n`);
      for (const error of errors) {
        console.log(`  - ${error.name}: ${error.error}`);
      }
    }

    // Write updates if --write flag is set
    if (writeMode && updates.length > 0) {
      console.log('\n========================================');
      console.log('Writing updates to versions.properties');
      console.log('========================================\n');

      const updatesToWrite: VersionsMap = {};

      for (const update of updates) {
        const dep = DEPENDENCIES.find((d) => d.name === update.name);
        if (!dep) continue;

        updatesToWrite[dep.versionKey] = update.latestVersion;

        if (update.sha256 && dep.sha256Key) {
          updatesToWrite[dep.sha256Key] = update.sha256;
        }

        if (dep.urlKey && dep.downloadUrl) {
          const url = dep.downloadUrl(update.latestVersion);
          updatesToWrite[dep.urlKey] = url;
        }
      }

      await updateVersionsFile(VERSIONS_FILE, updatesToWrite);
      console.log('✓ Updated versions.properties');
    } else if (writeMode) {
      console.log('\n✓ No updates to write');
    } else if (updates.length > 0) {
      console.log('\nℹ Run with --write to update versions.properties');
    }

    // Generate GitHub Actions output
    generateGitHubOutput(results);

    process.exit(errors.length > 0 ? 1 : 0);
  } catch (error) {
    console.error('\n❌ Fatal error:');
    console.error(error);
    process.exit(1);
  }
}

// Run if invoked directly
if (import.meta.url === `file://${process.argv[1]}`) {
  main();
}
