#!/usr/bin/env tsx
/**
 * Fetch Latest Dependency Versions
 *
 * Fetches latest versions from release-monitoring.org (Anitya) and
 * validates SHA256 checksums by downloading tarballs.
 *
 * Usage:
 *   tsx scripts/fetch-versions.ts          # Dry-run (preview changes)
 *   tsx scripts/fetch-versions.ts --write  # Update versions.properties
 */

import {writeFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {join} from 'node:path';
import {
  parseVersionsFile,
  updateVersionsFile,
  compareVersions,
  isPrereleaseTag,
  selectLatestStableTag,
  VersionsMap,
} from './lib/versions.ts';
import {DEPENDENCIES, DependencyMetadata} from './lib/dependencies.ts';
import {getScriptDir, isMainModule} from './lib/paths.ts';

const __dirname = getScriptDir(import.meta.url);

// ============================================================================
// Types
// ============================================================================

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
        const delay = Math.pow(2, i) * 1000;
        await new Promise((resolve) => {
          setTimeout(resolve, delay);
        });
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
    for (;;) {
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
 * Fetch latest version from release-monitoring.org (Anitya) by project ID
 */
export async function fetchAnityaLatest(projectId: number): Promise<string> {
  const url = `https://release-monitoring.org/api/project/${projectId}`;
  const response = await fetchWithRetry(url);

  if (!response.ok) {
    throw new Error(`Anitya API error: ${response.status} for project ${projectId}`);
  }

  const project = (await response.json()) as {
    name: string;
    stable_versions: string[];
  };

  const stableVersions = project.stable_versions || [];
  if (stableVersions.length === 0) {
    throw new Error(`No stable versions for project ${projectId}`);
  }

  return stableVersions[0]; // Most recent stable
}

/**
 * Fetch latest version for a dependency based on its fetch source
 */
async function fetchLatestVersion(dep: DependencyMetadata): Promise<string> {
  const source = dep.fetchSource;

  switch (source.type) {
    case 'static':
      return source.version;

    case 'anitya':
      return fetchAnityaLatest(source.projectId);

    default: {
      const exhaustiveCheck: never = source;
      throw new Error(`Unknown fetch source type: ${exhaustiveCheck}`);
    }
  }
}

// ============================================================================
// Main Logic
// ============================================================================

/**
 * Check for version updates
 */
async function checkForUpdates(currentVersions: VersionsMap): Promise<UpdateResult[]> {
  console.log('Checking for updates...\n');

  const results = await Promise.all(
    DEPENDENCIES.map(async (dep): Promise<UpdateResult> => {
      try {
        const currentVersion = currentVersions[dep.versionKey] || 'unknown';
        console.log(`  Checking ${dep.name} (current: ${currentVersion})...`);

        const latestVersion = await fetchLatestVersion(dep);
        // Apply tag prefix for comparison (currentVersion in file has prefix)
        const latestWithPrefix = dep.tagPrefix
          ? `${dep.tagPrefix}${latestVersion}`
          : latestVersion;
        const updated = currentVersion !== latestWithPrefix;

        let sha256: string | undefined;
        if (updated && dep.downloadUrl && dep.sha256Key) {
          console.log(`    Downloading to verify checksum...`);
          const url = dep.downloadUrl(latestVersion);
          sha256 = await downloadAndChecksum(url);
        }

        if (updated) {
          console.log(`    ⚠ Update available: ${currentVersion} → ${latestWithPrefix}`);
        } else {
          console.log(`    ✓ Up to date`);
        }

        return {
          name: dep.name,
          currentVersion,
          latestVersion: latestWithPrefix, // Prefixed version for display and writing
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

  const summary = updates.map((u) => `- **${u.name}**: ${u.currentVersion} → ${u.latestVersion}`).join('\n');

  const output = [`updates_available=${hasUpdates}`, 'update_summary<<EOF', summary || 'No updates available', 'EOF'].join(
    '\n',
  );

  writeFile(githubOutput, output + '\n', {flag: 'a'}).catch((err: unknown) => {
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
    const currentVersions = await parseVersionsFile(VERSIONS_FILE);
    const results = await checkForUpdates(currentVersions);

    console.log('\n========================================');
    console.log('Summary');
    console.log('========================================\n');

    const updates = results.filter((r) => r.updated);
    const errors = results.filter((r) => r.error);

    if (updates.length > 0) {
      console.log(`⚠ ${updates.length} update(s) available:\n`);
      for (const update of updates) {
        console.log(`  - ${update.name}: ${update.currentVersion} → ${update.latestVersion}`);
      }
    } else {
      console.log('✓ All dependencies up to date');
    }

    if (errors.length > 0) {
      console.log(`\n✗ ${errors.length} error(s) occurred:\n`);
      for (const err of errors) {
        console.log(`  - ${err.name}: ${err.error}`);
      }
    }

    if (writeMode && updates.length > 0) {
      console.log('\n========================================');
      console.log('Writing updates to versions.properties');
      console.log('========================================\n');

      const updatesToWrite: VersionsMap = {};

      for (const update of updates) {
        const dep = DEPENDENCIES.find((d) => d.name === update.name);
        if (!dep) continue;

        // latestVersion already includes tag prefix from checkForUpdates
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

    generateGitHubOutput(results);

    process.exit(errors.length > 0 ? 1 : 0);
  } catch (error) {
    console.error('\n❌ Fatal error:');
    console.error(error);
    process.exit(1);
  }
}

if (isMainModule(import.meta.url)) {
  main();
}
