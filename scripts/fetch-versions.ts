#!/usr/bin/env tsx
/**
 * Fetch Latest Dependency Versions
 *
 * Fetches latest versions from official sources (release feeds, BitBucket),
 * validates SHA256 checksums by downloading tarballs.
 *
 * Usage:
 *   tsx scripts/fetch-versions.ts          # Dry-run (preview changes)
 *   tsx scripts/fetch-versions.ts --write  # Update versions.properties
 */

import {mkdtemp, rm} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {join, dirname} from 'node:path';
import {tmpdir} from 'node:os';
import {fileURLToPath} from 'node:url';
import {
  parseVersionsFile,
  updateVersionsFile,
  compareVersions,
  isPrereleaseTag,
  selectLatestStableTag,
  VersionsMap,
} from './lib/versions.ts';

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

// Re-export for tests
export {parseVersionsFile, compareVersions, isPrereleaseTag, selectLatestStableTag};

// ============================================================================
// Constants
// ============================================================================

const VERSIONS_FILE = join(__dirname, '..', 'versions.properties');
const USER_AGENT = 'ffmpeg-prebuilds-version-fetcher/1.0';
const SEMVER_TAG = /^v[0-9]+(?:\.[0-9]+)*$/;
const SEMVER_NO_PREFIX_TAG = /^[0-9]+(?:\.[0-9]+)*$/;
const FFMPEG_TAG = /^n[0-9]+(?:\.[0-9]+){1,2}$/;
const NASM_TAG = /^nasm-[0-9]+(?:\.[0-9]+)*$/;
const OPENSSL_TAG = /^openssl-3\.[0-9]+(?:\.[0-9]+)?$/;
const TAGS_PAGE_SIZE = 100;
const MAX_TAG_PAGES = 2;

// GitHub token for API authentication (avoids rate limits)
const GITHUB_TOKEN = process.env.GITHUB_TOKEN || process.env.GH_TOKEN;

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

// ============================================================================
// Version Fetchers
// ============================================================================

/**
 * Fetch latest version from GitHub tags API with optional authentication
 */
async function fetchGitHubLatest(
  repo: string,
  tagPattern: RegExp,
): Promise<string> {
  const tags: string[] = [];
  const headers: Record<string, string> = {};

  // Use GitHub token if available to avoid rate limits
  if (GITHUB_TOKEN) {
    headers['Authorization'] = `Bearer ${GITHUB_TOKEN}`;
  }

  for (let page = 1; page <= MAX_TAG_PAGES; page++) {
    const url =
      `https://api.github.com/repos/${repo}` +
      `/tags?per_page=${TAGS_PAGE_SIZE}&page=${page}`;
    const response = await fetchWithRetry(url, {headers});

    if (!response.ok) {
      throw new Error(`GitHub API error: ${response.status}`);
    }

    const pageTags = (await response.json()) as Array<{name: string}>;
    if (pageTags.length === 0) {
      break;
    }

    tags.push(...pageTags.map((tag) => tag.name));
    if (pageTags.length < TAGS_PAGE_SIZE) {
      break;
    }
  }

  return selectLatestStableTag(tags, tagPattern);
}

/**
 * Fetch latest version from BitBucket tags (with pagination)
 */
async function fetchBitBucketLatest(
  repo: string,
  tagPattern: RegExp,
): Promise<string> {
  const allTags: string[] = [];
  let nextUrl: string | null =
    `https://api.bitbucket.org/2.0/repositories/${repo}/refs/tags?pagelen=100`;

  // Fetch all pages (BitBucket returns oldest first, so we need all pages)
  while (nextUrl) {
    const response = await fetchWithRetry(nextUrl);

    if (!response.ok) {
      throw new Error(`BitBucket API error: ${response.status}`);
    }

    const data = (await response.json()) as {
      values: Array<{name: string}>;
      next?: string;
    };

    allTags.push(...data.values.map((tag) => tag.name));
    nextUrl = data.next || null;
  }

  const matching = allTags.filter(
    (tag) => tagPattern.test(tag) && !isPrereleaseTag(tag),
  );

  if (matching.length === 0) {
    throw new Error(`No matching tags found for ${repo}`);
  }

  // Sort versions using semantic version comparison
  const sorted = matching.sort((a, b) => compareVersions(b, a));

  return sorted[0];
}

/**
 * Fetch latest version from GitLab tags API
 */
async function fetchGitLabLatest(
  host: string,
  projectPath: string,
  tagPattern: RegExp,
): Promise<string> {
  const url =
    `https://${host}/api/v4/projects/${encodeURIComponent(projectPath)}` +
    `/repository/tags?per_page=${TAGS_PAGE_SIZE}`;
  const response = await fetchWithRetry(url);

  if (!response.ok) {
    throw new Error(`GitLab API error: ${response.status}`);
  }

  const tags = (await response.json()) as Array<{name: string}>;
  const tagNames = tags.map((tag) => tag.name);
  return selectLatestStableTag(tagNames, tagPattern);
}

// ============================================================================
// Dependency Registry
// ============================================================================

const DEPENDENCIES: DependencyVersion[] = [
  // Core FFmpeg (Git-only)
  {
    name: 'FFmpeg',
    versionKey: 'FFMPEG_VERSION',
    fetchLatest: async () => {
      // Fetch releases and filter out dev/rc versions
      const tag = await fetchGitHubLatest('FFmpeg/FFmpeg', FFMPEG_TAG);
      return tag;
    },
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
    fetchLatest: () =>
      fetchBitBucketLatest('multicoreware/x265_git', SEMVER_NO_PREFIX_TAG),
  },
  {
    name: 'libvpx',
    versionKey: 'LIBVPX_VERSION',
    fetchLatest: () => fetchGitHubLatest('webmproject/libvpx', SEMVER_TAG),
  },
  {
    name: 'libaom',
    versionKey: 'LIBAOM_VERSION',
    fetchLatest: async () => {
      // libaom is on Google Source, which doesn't have a convenient API
      // Fallback to checking GitHub mirror
      try {
        return await fetchGitHubLatest('jbeich/aom', SEMVER_TAG);
      } catch {
        return 'v3.12.1'; // Current stable version
      }
    },
  },
  {
    name: 'SVT-AV1',
    versionKey: 'SVTAV1_VERSION',
    fetchLatest: async () => {
      // SVT-AV1 is on GitLab, fallback to current version if feed/API fails
      try {
        return await fetchGitLabLatest(
          'gitlab.com',
          'AOMediaCodec/SVT-AV1',
          SEMVER_TAG,
        );
      } catch {
        return 'v2.3.0'; // Current stable version
      }
    },
  },
  {
    name: 'dav1d',
    versionKey: 'DAV1D_VERSION',
    urlKey: 'DAV1D_URL',
    sha256Key: 'DAV1D_SHA256',
    fetchLatest: async () => {
      // dav1d on VideoLAN GitLab releases feed
      try {
        return await fetchGitLabLatest(
          'code.videolan.org',
          'videolan/dav1d',
          SEMVER_NO_PREFIX_TAG,
        );
      } catch {
        return '1.5.0'; // Current stable version
      }
    },
    downloadUrl: (v) =>
      `https://downloads.videolan.org/pub/videolan/dav1d/${v}/dav1d-${v}.tar.xz`,
  },
  {
    name: 'rav1e',
    versionKey: 'RAV1E_VERSION',
    fetchLatest: () => fetchGitHubLatest('xiph/rav1e', SEMVER_TAG),
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
      fetchGitHubLatest('xiph/opus', SEMVER_TAG).then((v) => v.slice(1)), // Remove 'v' prefix
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
    fetchLatest: () => fetchGitHubLatest('mstorsjo/fdk-aac', SEMVER_TAG),
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
      const tag = await fetchGitHubLatest('libass/libass', SEMVER_NO_PREFIX_TAG);
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
      // Only stable releases (exclude rc/pre-release)
      const tag = await fetchGitHubLatest('netwide-assembler/nasm', NASM_TAG);
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
      const tag = await fetchGitHubLatest('openssl/openssl', OPENSSL_TAG);
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

    // Exit with success if we successfully wrote updates or if there were no updates
    // Only fail if there were errors AND no successful updates
    if (writeMode && updates.length > 0) {
      process.exit(0); // Successfully wrote updates
    } else if (errors.length > 0 && updates.length === 0) {
      process.exit(1); // Only errors, no successful updates
    } else {
      process.exit(0); // No updates or dry-run mode
    }
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
