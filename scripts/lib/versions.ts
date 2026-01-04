/**
 * Version parsing and comparison utilities
 *
 * Single source of truth for reading versions.properties and comparing versions.
 */

import {readFile, writeFile} from 'node:fs/promises';
import {readFileSync} from 'node:fs';

export interface VersionsMap {
  [key: string]: string;
}

export interface VersionMetadata {
  lastUpdated: string;
  ffmpegVersion: string;
}

const VERSION_PREFIX_PATTERN = /^(v|n|nasm-|openssl-)/;
const NUMERIC_VERSION_PATTERN = /^[0-9]+(?:[.-][0-9]+)*$/;

function stripVersionPrefix(value: string): string {
  return value.replace(VERSION_PREFIX_PATTERN, '');
}

/**
 * Parse versions.properties file (async)
 */
export async function parseVersionsFile(filePath: string): Promise<VersionsMap> {
  const content = await readFile(filePath, 'utf-8');
  return parseVersionsContent(content);
}

/**
 * Parse versions.properties file (sync)
 */
export function parseVersionsFileSync(filePath: string): VersionsMap {
  const content = readFileSync(filePath, 'utf-8');
  return parseVersionsContent(content);
}

function parseVersionsContent(content: string): VersionsMap {
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

    if (key) {
      versions[key] = value;
    }
  }

  return versions;
}

/**
 * Update versions.properties file while preserving structure
 */
export async function updateVersionsFile(
  filePath: string,
  updates: VersionsMap,
): Promise<void> {
  const content = await readFile(filePath, 'utf-8');
  const lines = content.split('\n');

  const now = new Date();
  const timestamp = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-${String(now.getDate()).padStart(2, '0')}`;

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];

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
      const indent = line.match(/^\s*/)?.[0] ?? '';
      lines[i] = `${indent}${key}=${updates[key]}`;
    }
  }

  await writeFile(filePath, lines.join('\n'), 'utf-8');
}

/**
 * Compare semantic versions
 * Returns positive if v1 > v2, negative if v1 < v2, 0 if equal
 */
export function compareVersions(v1: string, v2: string): number {
  const clean1 = stripVersionPrefix(v1);
  const clean2 = stripVersionPrefix(v2);

  const parts1 = clean1.split(/[.-]/).map((p) => parseInt(p, 10) || 0);
  const parts2 = clean2.split(/[.-]/).map((p) => parseInt(p, 10) || 0);

  const maxLength = Math.max(parts1.length, parts2.length);
  for (let i = 0; i < maxLength; i++) {
    const p1 = parts1[i] ?? 0;
    const p2 = parts2[i] ?? 0;
    if (p1 !== p2) {
      return p1 - p2;
    }
  }

  return 0;
}

/**
 * Check if a tag is a pre-release version
 */
export function isPrereleaseTag(tag: string): boolean {
  const stripped = stripVersionPrefix(tag);
  return !NUMERIC_VERSION_PATTERN.test(stripped);
}

/**
 * Select the latest stable tag from a list
 */
export function selectLatestStableTag(tags: string[], tagPattern: RegExp): string {
  const matching = tags.filter(
    (tag) => tagPattern.test(tag) && !isPrereleaseTag(tag),
  );

  if (matching.length === 0) {
    throw new Error(`No stable tags found matching ${tagPattern}`);
  }

  return matching.sort((a, b) => compareVersions(b, a))[0];
}

/**
 * Extract metadata from versions content (lastUpdated, ffmpegVersion)
 */
export function getMetadataFromContent(content: string): VersionMetadata {
  const dateMatch = content.match(/# Updated: (\d{4}-\d{2}-\d{2})/);
  const lastUpdated = dateMatch ? dateMatch[1] : new Date().toISOString().split('T')[0];

  const ffmpegMatch = content.match(/FFMPEG_VERSION=n(\S+)/);
  const ffmpegVersion = ffmpegMatch ? ffmpegMatch[1] : 'unknown';

  return {lastUpdated, ffmpegVersion};
}

/**
 * Get metadata from versions file (sync)
 */
export function getVersionMetadataSync(filePath: string): VersionMetadata {
  const content = readFileSync(filePath, 'utf-8');
  return getMetadataFromContent(content);
}
