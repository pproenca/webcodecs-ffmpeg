import {describe, test} from 'node:test';
import assert from 'node:assert';
import {writeFile, rm} from 'node:fs/promises';
import {compareVersions, parseVersionsFile} from './fetch-versions.ts';

describe('compareVersions', () => {
  test('correctly compares semantic versions', () => {
    // Basic version comparison
    assert(compareVersions('4.0', '0.9') > 0, '4.0 should be greater than 0.9');
    assert(compareVersions('0.9', '4.0') < 0, '0.9 should be less than 4.0');
    assert.strictEqual(compareVersions('2.0', '2.0'), 0, '2.0 should equal 2.0');

    // Multi-part versions
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
    // Dash separators
    assert(compareVersions('2.16-03', '2.16-02') > 0, '2.16-03 should be greater than 2.16-02');

    // Dot separators
    assert(compareVersions('3.4.0', '3.6.0') < 0, '3.4.0 should be less than 3.6.0');

    // Mixed separators (converted to dots)
    assert.strictEqual(compareVersions('1-2.3', '1.2-3'), 0, '1-2.3 should equal 1.2-3');
  });

  test('real-world version comparisons', () => {
    // x265 versions
    assert(compareVersions('4.0', '4.1') < 0, '4.0 should be less than 4.1');
    assert(compareVersions('4.1', '4.0') > 0, '4.1 should be greater than 4.0');
    assert(compareVersions('4.0', '3.6') > 0, '4.0 should be greater than 3.6');

    // NASM versions
    assert(compareVersions('2.16.03', '3.01') < 0, '2.16.03 should be less than 3.01');

    // OpenSSL versions
    assert(compareVersions('3.4.0', '3.6.0') < 0, '3.4.0 should be less than 3.6.0');

    // libass versions
    assert(compareVersions('0.17.3', '0.17.4') < 0, '0.17.3 should be less than 0.17.4');

    // Opus versions
    assert(compareVersions('1.5.2', '1.6') < 0, '1.5.2 should be less than 1.6');
  });
});

describe('parseVersionsFile', () => {
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

    // Write to temp file
    const tmpFile = `/tmp/test-versions-${Date.now()}.properties`;
    await writeFile(tmpFile, mockContent);

    try {
      const result = await parseVersionsFile(tmpFile);

      assert.strictEqual(result['FFMPEG_VERSION'], 'n8.0', 'FFMPEG_VERSION should be n8.0');
      assert.strictEqual(result['X264_VERSION'], 'stable', 'X264_VERSION should be stable');
      assert.strictEqual(result['X265_VERSION'], '4.0', 'X265_VERSION should be 4.0');
      assert.strictEqual(result['FFMPEG_GIT_URL'], 'https://git.ffmpeg.org/ffmpeg.git', 'FFMPEG_GIT_URL should match');

      // Should not parse comments
      assert.strictEqual(result['# FFmpeg Prebuilds Dependency Versions'], undefined, 'Should not parse comment lines');
      assert.strictEqual(result['# Core FFmpeg'], undefined, 'Should not parse comment lines');
    } finally {
      // Cleanup
      await rm(tmpFile).catch(() => {}); // Best effort cleanup
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
      // Malformed lines should be skipped
      assert.strictEqual(result['INVALID_LINE_WITHOUT_EQUALS'], undefined, 'Malformed line should be skipped');
      assert.strictEqual(result[''], undefined, 'Empty key should be skipped');
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
      assert.strictEqual(result['DESCRIPTION'], 'This is a description with = sign', 'Description should preserve equals in value');
    } finally {
      await rm(tmpFile).catch(() => {});
    }
  });
});
