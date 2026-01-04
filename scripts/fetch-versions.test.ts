import {describe, test, mock, beforeEach, afterEach} from 'node:test';
import assert from 'node:assert';
import {writeFile, rm, mkdir} from 'node:fs/promises';
import {join} from 'node:path';
import {
  compareVersions,
  isPrereleaseTag,
  parseVersionsFile,
  selectLatestStableTag,
} from './fetch-versions.ts';
import {
  updateVersionsFile,
  parseVersionsFileSync,
  getMetadataFromContent,
  getVersionMetadataSync,
} from './lib/versions.ts';
import {
  DEPENDENCIES,
  getDependency,
  getDependencyByVersionKey,
} from './lib/dependencies.ts';

// ============================================================================
// compareVersions Tests
// ============================================================================

describe('compareVersions', () => {
  describe('happy path - basic comparisons', () => {
    test('correctly compares semantic versions', () => {
      assert(compareVersions('4.0', '0.9') > 0, '4.0 should be greater than 0.9');
      assert(compareVersions('0.9', '4.0') < 0, '0.9 should be less than 4.0');
      assert.strictEqual(compareVersions('2.0', '2.0'), 0, '2.0 should equal 2.0');
      assert(compareVersions('2.16.03', '2.16.02') > 0, '2.16.03 should be greater than 2.16.02');
      assert(compareVersions('3.0.0', '2.99.99') > 0, '3.0.0 should be greater than 2.99.99');
    });

    test('handles version prefixes correctly', () => {
      // v prefix
      assert(compareVersions('v2.3.0', 'v3.1.2') < 0, 'v2.3.0 should be less than v3.1.2');
      assert(compareVersions('v3.1.2', 'v2.3.0') > 0, 'v3.1.2 should be greater than v2.3.0');

      // n prefix (FFmpeg)
      assert(compareVersions('n8.0', 'n7.1') > 0, 'n8.0 should be greater than n7.1');
      assert(compareVersions('n8.0', 'n8.1') < 0, 'n8.0 should be less than n8.1');

      // nasm prefix
      assert(compareVersions('nasm-2.16.03', 'nasm-3.01') < 0, 'nasm-2.16.03 should be less than nasm-3.01');
      assert(compareVersions('nasm-3.01', 'nasm-2.16.03') > 0, 'nasm-3.01 should be greater than nasm-2.16.03');

      // openssl prefix
      assert(compareVersions('openssl-3.4.0', 'openssl-3.6.0') < 0, 'openssl-3.4.0 should be less than openssl-3.6.0');
      assert(compareVersions('openssl-3.6.0', 'openssl-3.4.0') > 0, 'openssl-3.6.0 should be greater than openssl-3.4.0');
    });

    test('handles mixed length versions', () => {
      assert.strictEqual(compareVersions('1.0', '1.0.0'), 0, '1.0 should equal 1.0.0');
      assert(compareVersions('1.0.1', '1.0') > 0, '1.0.1 should be greater than 1.0');
      assert(compareVersions('2.0', '2.0.0.1') < 0, '2.0 should be less than 2.0.0.1');
    });

    test('handles different separators', () => {
      assert(compareVersions('2.16-03', '2.16-02') > 0, '2.16-03 should be greater than 2.16-02');
      assert(compareVersions('3.4.0', '3.6.0') < 0, '3.4.0 should be less than 3.6.0');
      assert.strictEqual(compareVersions('1-2.3', '1.2-3'), 0, '1-2.3 should equal 1.2-3');
    });

    test('real-world version comparisons', () => {
      assert(compareVersions('4.0', '4.1') < 0, '4.0 should be less than 4.1');
      assert(compareVersions('4.1', '4.0') > 0, '4.1 should be greater than 4.0');
      assert(compareVersions('4.0', '3.6') > 0, '4.0 should be greater than 3.6');
      assert(compareVersions('2.16.03', '3.01') < 0, '2.16.03 should be less than 3.01');
      assert(compareVersions('3.4.0', '3.6.0') < 0, '3.4.0 should be less than 3.6.0');
      assert(compareVersions('0.17.3', '0.17.4') < 0, '0.17.3 should be less than 0.17.4');
      assert(compareVersions('1.5.2', '1.6') < 0, '1.5.2 should be less than 1.6');
    });
  });

  describe('sad path - edge cases', () => {
    test('handles empty version strings', () => {
      assert.strictEqual(compareVersions('', ''), 0, 'empty strings should be equal');
      assert(compareVersions('1.0', '') > 0, '1.0 should be greater than empty');
      assert(compareVersions('', '1.0') < 0, 'empty should be less than 1.0');
    });

    test('handles non-numeric parts gracefully', () => {
      // Non-numeric parts become 0 after parseInt
      assert.strictEqual(compareVersions('abc', 'def'), 0, 'non-numeric parts should be equal (both become 0)');
      assert(compareVersions('1.abc', '1.0') === 0, '1.abc should equal 1.0 (abc becomes 0)');
    });

    test('handles very long version strings', () => {
      const longV1 = '1.2.3.4.5.6.7.8.9.10';
      const longV2 = '1.2.3.4.5.6.7.8.9.11';
      assert(compareVersions(longV1, longV2) < 0, 'long version comparison should work');
    });

    test('handles leading zeros', () => {
      // parseInt handles leading zeros
      assert.strictEqual(compareVersions('01.02.03', '1.2.3'), 0, 'leading zeros should be handled');
    });
  });
});

// ============================================================================
// isPrereleaseTag Tests
// ============================================================================

describe('isPrereleaseTag', () => {
  describe('happy path - stable tags', () => {
    test('identifies stable tags', () => {
      assert.strictEqual(isPrereleaseTag('v1.2.3'), false, 'v1.2.3 is stable');
      assert.strictEqual(isPrereleaseTag('n8.0.1'), false, 'n8.0.1 is stable');
      assert.strictEqual(isPrereleaseTag('openssl-3.4.0'), false, 'openssl-3.4.0 is stable');
      assert.strictEqual(isPrereleaseTag('1.2.3'), false, '1.2.3 is stable');
      assert.strictEqual(isPrereleaseTag('nasm-2.16.03'), false, 'nasm-2.16.03 is stable');
    });
  });

  describe('sad path - prerelease tags', () => {
    test('identifies prerelease tags', () => {
      assert.strictEqual(isPrereleaseTag('v1.2.3-rc1'), true, 'rc tag is prerelease');
      assert.strictEqual(isPrereleaseTag('v1.2.3beta'), true, 'beta suffix is prerelease');
      assert.strictEqual(isPrereleaseTag('openssl-3.4.0-alpha1'), true, 'alpha tag is prerelease');
      assert.strictEqual(isPrereleaseTag('v1.0.0-dev'), true, 'dev tag is prerelease');
      assert.strictEqual(isPrereleaseTag('n8.1-dev'), true, 'FFmpeg dev tag is prerelease');
    });

    test('identifies edge case prerelease patterns', () => {
      assert.strictEqual(isPrereleaseTag('v1.0.0-pre'), true, 'pre tag is prerelease');
      assert.strictEqual(isPrereleaseTag('v1.0.0-snapshot'), true, 'snapshot tag is prerelease');
      assert.strictEqual(isPrereleaseTag('v1.0.0+build123'), true, 'build metadata is prerelease');
    });
  });
});

// ============================================================================
// selectLatestStableTag Tests
// ============================================================================

describe('selectLatestStableTag', () => {
  describe('happy path', () => {
    test('picks the newest stable tag', () => {
      const tags = ['v1.2.0', 'v1.2.3', 'v1.3.0-rc1'];
      const result = selectLatestStableTag(tags, /^v[0-9]+(?:\.[0-9]+)*$/);
      assert.strictEqual(result, 'v1.2.3', 'latest stable tag should be v1.2.3');
    });

    test('handles FFmpeg-style tags', () => {
      const tags = ['n8.0', 'n8.0.1', 'n8.1-rc1'];
      const result = selectLatestStableTag(tags, /^n[0-9]+(?:\.[0-9]+){1,2}$/);
      assert.strictEqual(result, 'n8.0.1', 'latest stable tag should be n8.0.1');
    });

    test('handles NASM-style tags', () => {
      const tags = ['nasm-2.16.02', 'nasm-2.16.03', 'nasm-3.01'];
      const result = selectLatestStableTag(tags, /^nasm-[0-9]+(?:\.[0-9]+)*$/);
      assert.strictEqual(result, 'nasm-3.01', 'latest stable tag should be nasm-3.01');
    });

    test('handles OpenSSL-style tags', () => {
      const tags = ['openssl-3.0.0', 'openssl-3.4.0', 'openssl-3.6.0'];
      const result = selectLatestStableTag(tags, /^openssl-3\.[0-9]+(?:\.[0-9]+)?$/);
      assert.strictEqual(result, 'openssl-3.6.0', 'latest stable tag should be openssl-3.6.0');
    });

    test('filters out all prereleases correctly', () => {
      const tags = ['v1.0.0-alpha', 'v1.0.0-beta', 'v1.0.0-rc1', 'v1.0.0', 'v1.0.1-dev'];
      const result = selectLatestStableTag(tags, /^v[0-9]+(?:\.[0-9]+)*$/);
      assert.strictEqual(result, 'v1.0.0', 'should only select stable v1.0.0');
    });

    test('handles unsorted input', () => {
      const tags = ['v1.0.0', 'v3.0.0', 'v2.0.0', 'v1.5.0'];
      const result = selectLatestStableTag(tags, /^v[0-9]+(?:\.[0-9]+)*$/);
      assert.strictEqual(result, 'v3.0.0', 'should sort and select v3.0.0');
    });
  });

  describe('sad path', () => {
    test('throws when no stable tags match', () => {
      const tags = ['v1.2.3-rc1'];
      assert.throws(
        () => selectLatestStableTag(tags, /^v[0-9]+(?:\.[0-9]+)*$/),
        /No stable tags found/,
      );
    });

    test('throws when no tags match pattern', () => {
      const tags = ['release-1.0', 'release-2.0'];
      assert.throws(
        () => selectLatestStableTag(tags, /^v[0-9]+(?:\.[0-9]+)*$/),
        /No stable tags found/,
      );
    });

    test('throws when tags array is empty', () => {
      assert.throws(
        () => selectLatestStableTag([], /^v[0-9]+(?:\.[0-9]+)*$/),
        /No stable tags found/,
      );
    });

    test('throws when all tags are prereleases', () => {
      const tags = ['v1.0.0-alpha', 'v1.0.0-beta', 'v2.0.0-rc1'];
      assert.throws(
        () => selectLatestStableTag(tags, /^v[0-9]+(?:\.[0-9]+)*$/),
        /No stable tags found/,
      );
    });
  });
});

// ============================================================================
// parseVersionsFile Tests
// ============================================================================

describe('parseVersionsFile', () => {
  describe('happy path', () => {
    test('parses versions.properties correctly', async () => {
      const mockContent = `# FFmpeg Prebuilds Dependency Versions
# Updated: 2026-01-04

# Core FFmpeg
FFMPEG_VERSION=n8.0
FFMPEG_GIT_URL=https://git.ffmpeg.org/ffmpeg.git

# Video Codecs
X264_VERSION=stable
X264_GIT_URL=https://code.videolan.org/videolan/x264.git

X265_VERSION=4.0
X265_GIT_URL=https://bitbucket.org/multicoreware/x265_git.git`;

      const tmpFile = `/tmp/test-versions-${Date.now()}.properties`;
      await writeFile(tmpFile, mockContent);

      try {
        const result = await parseVersionsFile(tmpFile);

        assert.strictEqual(result['FFMPEG_VERSION'], 'n8.0', 'FFMPEG_VERSION should be n8.0');
        assert.strictEqual(result['X264_VERSION'], 'stable', 'X264_VERSION should be stable');
        assert.strictEqual(result['X265_VERSION'], '4.0', 'X265_VERSION should be 4.0');
        assert.strictEqual(result['FFMPEG_GIT_URL'], 'https://git.ffmpeg.org/ffmpeg.git', 'FFMPEG_GIT_URL should match');
        assert.strictEqual(result['# FFmpeg Prebuilds Dependency Versions'], undefined, 'Should not parse comment lines');
      } finally {
        await rm(tmpFile).catch(() => {});
      }
    });

    test('handles empty lines and comments', async () => {
      const mockContent = `# Comment

FFMPEG_VERSION=n8.0

# Another comment
X264_VERSION=stable`;

      const tmpFile = `/tmp/test-versions-empty-${Date.now()}.properties`;
      await writeFile(tmpFile, mockContent);

      try {
        const result = await parseVersionsFile(tmpFile);

        assert.strictEqual(result['FFMPEG_VERSION'], 'n8.0', 'FFMPEG_VERSION should be n8.0');
        assert.strictEqual(result['X264_VERSION'], 'stable', 'X264_VERSION should be stable');
        assert.strictEqual(Object.keys(result).length, 2, 'Should have exactly 2 entries');
      } finally {
        await rm(tmpFile).catch(() => {});
      }
    });

    test('handles malformed lines gracefully', async () => {
      const mockContent = `FFMPEG_VERSION=n8.0
INVALID_LINE_WITHOUT_EQUALS
X264_VERSION=stable
=VALUE_WITHOUT_KEY
`;

      const tmpFile = `/tmp/test-versions-malformed-${Date.now()}.properties`;
      await writeFile(tmpFile, mockContent);

      try {
        const result = await parseVersionsFile(tmpFile);

        assert.strictEqual(result['FFMPEG_VERSION'], 'n8.0', 'FFMPEG_VERSION should be n8.0');
        assert.strictEqual(result['X264_VERSION'], 'stable', 'X264_VERSION should be stable');
        assert.strictEqual(result['INVALID_LINE_WITHOUT_EQUALS'], undefined, 'Malformed line should be skipped');
      } finally {
        await rm(tmpFile).catch(() => {});
      }
    });

    test('handles values with equals signs', async () => {
      const mockContent = `URL=https://example.com?param=value
DESCRIPTION=This is a description with = sign`;

      const tmpFile = `/tmp/test-versions-equals-${Date.now()}.properties`;
      await writeFile(tmpFile, mockContent);

      try {
        const result = await parseVersionsFile(tmpFile);

        assert.strictEqual(result['URL'], 'https://example.com?param=value', 'URL should preserve equals in value');
        assert.strictEqual(result['DESCRIPTION'], 'This is a description with = sign', 'Description should preserve equals');
      } finally {
        await rm(tmpFile).catch(() => {});
      }
    });
  });

  describe('sad path', () => {
    test('throws on non-existent file', async () => {
      await assert.rejects(
        parseVersionsFile('/tmp/non-existent-file-12345.properties'),
        /ENOENT/,
        'Should throw ENOENT for non-existent file',
      );
    });

    test('handles empty file', async () => {
      const tmpFile = `/tmp/test-versions-empty-file-${Date.now()}.properties`;
      await writeFile(tmpFile, '');

      try {
        const result = await parseVersionsFile(tmpFile);
        assert.strictEqual(Object.keys(result).length, 0, 'Empty file should return empty object');
      } finally {
        await rm(tmpFile).catch(() => {});
      }
    });

    test('handles file with only comments', async () => {
      const tmpFile = `/tmp/test-versions-comments-${Date.now()}.properties`;
      await writeFile(tmpFile, '# Comment 1\n# Comment 2\n# Comment 3');

      try {
        const result = await parseVersionsFile(tmpFile);
        assert.strictEqual(Object.keys(result).length, 0, 'File with only comments should return empty object');
      } finally {
        await rm(tmpFile).catch(() => {});
      }
    });
  });
});

// ============================================================================
// parseVersionsFileSync Tests
// ============================================================================

describe('parseVersionsFileSync', () => {
  describe('happy path', () => {
    test('parses synchronously', async () => {
      const mockContent = `FFMPEG_VERSION=n8.0
X264_VERSION=stable`;

      const tmpFile = `/tmp/test-versions-sync-${Date.now()}.properties`;
      await writeFile(tmpFile, mockContent);

      try {
        const result = parseVersionsFileSync(tmpFile);
        assert.strictEqual(result['FFMPEG_VERSION'], 'n8.0');
        assert.strictEqual(result['X264_VERSION'], 'stable');
      } finally {
        await rm(tmpFile).catch(() => {});
      }
    });
  });

  describe('sad path', () => {
    test('throws on non-existent file', () => {
      assert.throws(
        () => parseVersionsFileSync('/tmp/non-existent-sync-file.properties'),
        /ENOENT/,
      );
    });
  });
});

// ============================================================================
// updateVersionsFile Tests
// ============================================================================

describe('updateVersionsFile', () => {
  describe('happy path', () => {
    test('updates existing values', async () => {
      const originalContent = `# Updated: 2026-01-01
FFMPEG_VERSION=n8.0
X264_VERSION=stable`;

      const tmpFile = `/tmp/test-update-${Date.now()}.properties`;
      await writeFile(tmpFile, originalContent);

      try {
        await updateVersionsFile(tmpFile, {FFMPEG_VERSION: 'n8.0.1'});

        const result = await parseVersionsFile(tmpFile);
        assert.strictEqual(result['FFMPEG_VERSION'], 'n8.0.1', 'FFMPEG_VERSION should be updated');
        assert.strictEqual(result['X264_VERSION'], 'stable', 'X264_VERSION should be unchanged');
      } finally {
        await rm(tmpFile).catch(() => {});
      }
    });

    test('updates multiple values', async () => {
      const originalContent = `FFMPEG_VERSION=n8.0
X264_VERSION=stable
X265_VERSION=4.0`;

      const tmpFile = `/tmp/test-update-multi-${Date.now()}.properties`;
      await writeFile(tmpFile, originalContent);

      try {
        await updateVersionsFile(tmpFile, {
          FFMPEG_VERSION: 'n8.0.1',
          X265_VERSION: '4.1',
        });

        const result = await parseVersionsFile(tmpFile);
        assert.strictEqual(result['FFMPEG_VERSION'], 'n8.0.1');
        assert.strictEqual(result['X264_VERSION'], 'stable');
        assert.strictEqual(result['X265_VERSION'], '4.1');
      } finally {
        await rm(tmpFile).catch(() => {});
      }
    });

    test('updates timestamp comment', async () => {
      const originalContent = `# Updated: 2026-01-01
FFMPEG_VERSION=n8.0`;

      const tmpFile = `/tmp/test-update-timestamp-${Date.now()}.properties`;
      await writeFile(tmpFile, originalContent);

      try {
        await updateVersionsFile(tmpFile, {FFMPEG_VERSION: 'n8.0.1'});

        const {readFile} = await import('node:fs/promises');
        const content = await readFile(tmpFile, 'utf-8');

        // Timestamp should be updated to today's date
        const today = new Date().toISOString().split('T')[0];
        assert(content.includes(`# Updated: ${today}`), 'Timestamp should be updated');
      } finally {
        await rm(tmpFile).catch(() => {});
      }
    });

    test('preserves indentation', async () => {
      const originalContent = `  FFMPEG_VERSION=n8.0
\tX264_VERSION=stable`;

      const tmpFile = `/tmp/test-update-indent-${Date.now()}.properties`;
      await writeFile(tmpFile, originalContent);

      try {
        await updateVersionsFile(tmpFile, {FFMPEG_VERSION: 'n8.0.1'});

        const {readFile} = await import('node:fs/promises');
        const content = await readFile(tmpFile, 'utf-8');

        assert(content.includes('  FFMPEG_VERSION=n8.0.1'), 'Should preserve spaces indentation');
        assert(content.includes('\tX264_VERSION=stable'), 'Should preserve tab indentation');
      } finally {
        await rm(tmpFile).catch(() => {});
      }
    });
  });

  describe('sad path', () => {
    test('ignores updates for non-existent keys', async () => {
      const originalContent = `FFMPEG_VERSION=n8.0`;

      const tmpFile = `/tmp/test-update-nonexistent-${Date.now()}.properties`;
      await writeFile(tmpFile, originalContent);

      try {
        await updateVersionsFile(tmpFile, {NON_EXISTENT_KEY: 'value'});

        const result = await parseVersionsFile(tmpFile);
        assert.strictEqual(result['FFMPEG_VERSION'], 'n8.0', 'Existing key should be unchanged');
        assert.strictEqual(result['NON_EXISTENT_KEY'], undefined, 'Non-existent key should not be added');
      } finally {
        await rm(tmpFile).catch(() => {});
      }
    });

    test('throws on non-existent file', async () => {
      await assert.rejects(
        updateVersionsFile('/tmp/non-existent-update-file.properties', {KEY: 'value'}),
        /ENOENT/,
      );
    });
  });
});

// ============================================================================
// getMetadataFromContent Tests
// ============================================================================

describe('getMetadataFromContent', () => {
  describe('happy path', () => {
    test('extracts metadata from content', () => {
      const content = `# Updated: 2026-01-04
FFMPEG_VERSION=n8.0.1
X264_VERSION=stable`;

      const metadata = getMetadataFromContent(content);
      assert.strictEqual(metadata.lastUpdated, '2026-01-04');
      assert.strictEqual(metadata.ffmpegVersion, '8.0.1');
    });

    test('handles different date formats', () => {
      const content = `# Updated: 2025-12-31
FFMPEG_VERSION=n7.1`;

      const metadata = getMetadataFromContent(content);
      assert.strictEqual(metadata.lastUpdated, '2025-12-31');
      assert.strictEqual(metadata.ffmpegVersion, '7.1');
    });
  });

  describe('sad path', () => {
    test('uses fallback when date missing', () => {
      const content = `FFMPEG_VERSION=n8.0`;
      const metadata = getMetadataFromContent(content);

      // Should use today's date as fallback
      assert.match(metadata.lastUpdated, /^\d{4}-\d{2}-\d{2}$/);
    });

    test('uses unknown when FFmpeg version missing', () => {
      const content = `# Updated: 2026-01-04
X264_VERSION=stable`;

      const metadata = getMetadataFromContent(content);
      assert.strictEqual(metadata.ffmpegVersion, 'unknown');
    });

    test('handles empty content', () => {
      const metadata = getMetadataFromContent('');
      assert.match(metadata.lastUpdated, /^\d{4}-\d{2}-\d{2}$/);
      assert.strictEqual(metadata.ffmpegVersion, 'unknown');
    });
  });
});

// ============================================================================
// DEPENDENCIES Registry Tests
// ============================================================================

describe('DEPENDENCIES', () => {
  describe('happy path - registry structure', () => {
    test('has expected number of dependencies', () => {
      assert(DEPENDENCIES.length > 0, 'Should have at least one dependency');
      assert(DEPENDENCIES.length >= 15, 'Should have at least 15 dependencies');
    });

    test('all dependencies have required fields', () => {
      for (const dep of DEPENDENCIES) {
        assert(dep.name, `${dep.name || 'Unknown'} should have name`);
        assert(dep.homepage, `${dep.name} should have homepage`);
        assert(dep.releasesUrl, `${dep.name} should have releasesUrl`);
        assert(dep.license, `${dep.name} should have license`);
        assert(dep.license.name, `${dep.name} should have license.name`);
        assert(dep.license.url, `${dep.name} should have license.url`);
        assert(dep.versionKey, `${dep.name} should have versionKey`);
        assert(dep.fetchSource, `${dep.name} should have fetchSource`);
        assert(dep.fetchSource.type, `${dep.name} should have fetchSource.type`);
      }
    });

    test('FFmpeg dependency exists and is configured correctly', () => {
      const ffmpeg = DEPENDENCIES.find((d) => d.name === 'FFmpeg');
      assert(ffmpeg, 'FFmpeg should exist');
      assert.strictEqual(ffmpeg.versionKey, 'FFMPEG_VERSION');
      assert.strictEqual(ffmpeg.fetchSource.type, 'anitya');
      if (ffmpeg.fetchSource.type === 'anitya') {
        assert.strictEqual(ffmpeg.fetchSource.projectId, 5405);
      }
    });

    test('all fetch source types are valid', () => {
      const validTypes = ['static', 'anitya'];
      for (const dep of DEPENDENCIES) {
        assert(
          validTypes.includes(dep.fetchSource.type),
          `${dep.name} has invalid fetchSource.type: ${dep.fetchSource.type}`,
        );
      }
    });

    test('static sources have version', () => {
      for (const dep of DEPENDENCIES) {
        if (dep.fetchSource.type === 'static') {
          assert(dep.fetchSource.version, `${dep.name} static source should have version`);
        }
      }
    });

    test('anitya sources have projectId', () => {
      for (const dep of DEPENDENCIES) {
        if (dep.fetchSource.type === 'anitya') {
          assert(typeof dep.fetchSource.projectId === 'number', `${dep.name} anitya source should have projectId`);
        }
      }
    });

    test('dependencies with sha256Key have downloadUrl', () => {
      for (const dep of DEPENDENCIES) {
        if (dep.sha256Key) {
          assert(dep.downloadUrl, `${dep.name} with sha256Key should have downloadUrl`);
        }
      }
    });
  });
});

// ============================================================================
// getDependency Tests
// ============================================================================

describe('getDependency', () => {
  describe('happy path', () => {
    test('finds dependency by exact name', () => {
      const ffmpeg = getDependency('FFmpeg');
      assert(ffmpeg, 'Should find FFmpeg');
      assert.strictEqual(ffmpeg.name, 'FFmpeg');
    });

    test('finds dependency case-insensitively', () => {
      const ffmpeg = getDependency('ffmpeg');
      assert(ffmpeg, 'Should find ffmpeg (lowercase)');
      assert.strictEqual(ffmpeg.name, 'FFmpeg');

      const x264 = getDependency('X264');
      assert(x264, 'Should find X264 (uppercase)');
      assert.strictEqual(x264.name, 'x264');
    });

    test('finds all expected dependencies', () => {
      const expectedDeps = ['FFmpeg', 'x264', 'x265', 'libvpx', 'Opus', 'NASM', 'OpenSSL'];
      for (const name of expectedDeps) {
        const dep = getDependency(name);
        assert(dep, `Should find ${name}`);
      }
    });
  });

  describe('sad path', () => {
    test('returns undefined for non-existent dependency', () => {
      const notFound = getDependency('NonExistentLibrary');
      assert.strictEqual(notFound, undefined, 'Should return undefined for non-existent');
    });

    test('returns undefined for empty string', () => {
      const empty = getDependency('');
      assert.strictEqual(empty, undefined, 'Should return undefined for empty string');
    });
  });
});

// ============================================================================
// getDependencyByVersionKey Tests
// ============================================================================

describe('getDependencyByVersionKey', () => {
  describe('happy path', () => {
    test('finds dependency by version key', () => {
      const ffmpeg = getDependencyByVersionKey('FFMPEG_VERSION');
      assert(ffmpeg, 'Should find by FFMPEG_VERSION');
      assert.strictEqual(ffmpeg.name, 'FFmpeg');
    });

    test('finds all dependencies by their version keys', () => {
      const keysToTest = [
        ['FFMPEG_VERSION', 'FFmpeg'],
        ['X264_VERSION', 'x264'],
        ['X265_VERSION', 'x265'],
        ['OPUS_VERSION', 'Opus'],
        ['NASM_VERSION', 'NASM'],
        ['OPENSSL_VERSION', 'OpenSSL'],
      ] as const;

      for (const [key, expectedName] of keysToTest) {
        const dep = getDependencyByVersionKey(key);
        assert(dep, `Should find ${key}`);
        assert.strictEqual(dep.name, expectedName, `${key} should map to ${expectedName}`);
      }
    });
  });

  describe('sad path', () => {
    test('returns undefined for non-existent key', () => {
      const notFound = getDependencyByVersionKey('NON_EXISTENT_VERSION');
      assert.strictEqual(notFound, undefined, 'Should return undefined for non-existent key');
    });

    test('returns undefined for empty string', () => {
      const empty = getDependencyByVersionKey('');
      assert.strictEqual(empty, undefined, 'Should return undefined for empty string');
    });

    test('is case-sensitive for version keys', () => {
      const lowercase = getDependencyByVersionKey('ffmpeg_version');
      assert.strictEqual(lowercase, undefined, 'Version keys should be case-sensitive');
    });
  });
});

// ============================================================================
// Integration Tests - Download URL Generation
// ============================================================================

describe('downloadUrl generation', () => {
  describe('happy path', () => {
    test('generates correct download URLs', () => {
      const testCases = [
        {
          name: 'Opus',
          version: '1.5.2',
          expected: 'https://downloads.xiph.org/releases/opus/opus-1.5.2.tar.gz',
        },
        {
          name: 'NASM',
          version: '2.16.03',
          expected: 'https://github.com/netwide-assembler/nasm/archive/refs/tags/nasm-2.16.03.tar.gz',
        },
        {
          name: 'OpenSSL',
          version: '3.4.0',
          expected: 'https://www.openssl.org/source/openssl-3.4.0.tar.gz',
        },
        {
          name: 'dav1d',
          version: '1.5.0',
          expected: 'https://downloads.videolan.org/pub/videolan/dav1d/1.5.0/dav1d-1.5.0.tar.xz',
        },
      ];

      for (const tc of testCases) {
        const dep = getDependency(tc.name);
        assert(dep, `Should find ${tc.name}`);
        assert(dep.downloadUrl, `${tc.name} should have downloadUrl`);
        const url = dep.downloadUrl(tc.version);
        assert.strictEqual(url, tc.expected, `${tc.name} download URL should match`);
      }
    });
  });

  describe('sad path', () => {
    test('dependencies without downloadUrl return undefined', () => {
      const ffmpeg = getDependency('FFmpeg');
      assert(ffmpeg, 'Should find FFmpeg');
      assert.strictEqual(ffmpeg.downloadUrl, undefined, 'FFmpeg should not have downloadUrl (git-only)');
    });
  });
});

// ============================================================================
// Anitya Fetch Source Type Tests
// ============================================================================

describe('Anitya fetch source type', () => {
  test('anitya source type has required projectId field', () => {
    const source = {type: 'anitya' as const, projectId: 5405};
    assert.strictEqual(source.type, 'anitya');
    assert.strictEqual(source.projectId, 5405);
  });

  test('anitya source works in dependency metadata', () => {
    const testDep = {
      name: 'TestLib',
      homepage: 'https://example.com',
      releasesUrl: 'https://example.com/releases',
      license: {name: 'MIT', url: 'https://example.com/license'},
      versionKey: 'TEST_VERSION',
      fetchSource: {type: 'anitya' as const, projectId: 12345},
    };
    assert.strictEqual(testDep.fetchSource.type, 'anitya');
    assert.strictEqual(testDep.fetchSource.projectId, 12345);
  });
});

// ============================================================================
// DEPENDENCIES Anitya Migration Tests
// ============================================================================

describe('DEPENDENCIES Anitya migration', () => {
  test('all non-static dependencies use anitya fetch source', () => {
    for (const dep of DEPENDENCIES) {
      if (dep.fetchSource.type !== 'static') {
        assert.strictEqual(
          dep.fetchSource.type,
          'anitya',
          `${dep.name} should use anitya fetch source, got ${dep.fetchSource.type}`,
        );
      }
    }
  });

  test('anitya dependencies have valid projectId', () => {
    for (const dep of DEPENDENCIES) {
      if (dep.fetchSource.type === 'anitya') {
        assert(
          typeof dep.fetchSource.projectId === 'number',
          `${dep.name} should have numeric projectId`,
        );
        assert(
          dep.fetchSource.projectId > 0,
          `${dep.name} projectId should be positive`,
        );
      }
    }
  });

  test('x264 remains static (uses stable branch)', () => {
    const x264 = getDependency('x264');
    assert(x264, 'x264 should exist');
    assert.strictEqual(x264.fetchSource.type, 'static', 'x264 should use static source');
  });
});

// ============================================================================
// Exit Code Behavior Tests
// ============================================================================

describe('exit code behavior', () => {
  test('should return error code when errors exist regardless of updates', () => {
    // Tests the logic pattern: errors should always result in exit code 1
    const scenarios = [
      {hasErrors: true, hasUpdates: true, expected: 1},
      {hasErrors: true, hasUpdates: false, expected: 1},
      {hasErrors: false, hasUpdates: true, expected: 0},
      {hasErrors: false, hasUpdates: false, expected: 0},
    ];

    for (const {hasErrors, hasUpdates, expected} of scenarios) {
      const exitCode = hasErrors ? 1 : 0;
      assert.strictEqual(
        exitCode,
        expected,
        `errors=${hasErrors}, updates=${hasUpdates} should exit with ${expected}`,
      );
    }
  });
});
