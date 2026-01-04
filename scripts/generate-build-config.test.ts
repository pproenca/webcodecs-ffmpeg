import {describe, test} from 'node:test';
import assert from 'node:assert';
import {readFile} from 'node:fs/promises';
import {join, dirname} from 'node:path';
import {fileURLToPath} from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

describe('generate-build-config', () => {
  test('full preset exists and is valid JSON', async () => {
    const presetPath = join(__dirname, '..', 'presets', 'full.json');
    const content = await readFile(presetPath, 'utf-8');
    const config = JSON.parse(content);

    // Validate structure
    assert('codecs' in config, 'config should have codecs property');
    assert('video' in config.codecs, 'config.codecs should have video property');
    assert('audio' in config.codecs, 'config.codecs should have audio property');
    assert('features' in config, 'config should have features property');
    assert('optimization' in config, 'config should have optimization property');
    assert('build' in config, 'config should have build property');
    assert('license' in config, 'config should have license property');
    assert('metadata' in config, 'config should have metadata property');
  });

  test('minimal preset exists and is valid JSON', async () => {
    const presetPath = join(__dirname, '..', 'presets', 'minimal.json');
    const content = await readFile(presetPath, 'utf-8');
    const config = JSON.parse(content);

    // Validate structure
    assert('codecs' in config, 'config should have codecs property');
    assert('metadata' in config, 'config should have metadata property');
    assert.strictEqual(config.metadata.preset, 'minimal', 'preset should be minimal');
  });

  test('streaming preset exists and is valid JSON', async () => {
    const presetPath = join(__dirname, '..', 'presets', 'streaming.json');
    const content = await readFile(presetPath, 'utf-8');
    const config = JSON.parse(content);

    // Validate structure
    assert('codecs' in config, 'config should have codecs property');
    assert('metadata' in config, 'config should have metadata property');
    assert.strictEqual(config.metadata.preset, 'streaming', 'preset should be streaming');
  });

  test('full preset has expected codecs enabled', async () => {
    const presetPath = join(__dirname, '..', 'presets', 'full.json');
    const content = await readFile(presetPath, 'utf-8');
    const config = JSON.parse(content);

    // Check video codecs
    assert.strictEqual(config.codecs.video.h264.enabled, true, 'h264 should be enabled');
    assert.strictEqual(config.codecs.video.h265.enabled, true, 'h265 should be enabled');
    assert.strictEqual(config.codecs.video.av1.enabled, true, 'av1 should be enabled');

    // Check audio codecs
    assert.strictEqual(config.codecs.audio.opus.enabled, true, 'opus should be enabled');
    assert.strictEqual(config.codecs.audio.mp3.enabled, true, 'mp3 should be enabled');
  });

  test('codec config has required fields', async () => {
    const presetPath = join(__dirname, '..', 'presets', 'full.json');
    const content = await readFile(presetPath, 'utf-8');
    const config = JSON.parse(content);

    // Check a video codec has all required fields
    const h264 = config.codecs.video.h264;
    assert('enabled' in h264, 'h264 should have enabled property');
    assert('library' in h264, 'h264 should have library property');
    assert('license' in h264, 'h264 should have license property');
    assert('description' in h264, 'h264 should have description property');
    assert('configure_flag' in h264, 'h264 should have configure_flag property');

    // Check an audio codec
    const opus = config.codecs.audio.opus;
    assert('enabled' in opus, 'opus should have enabled property');
    assert('library' in opus, 'opus should have library property');
    assert('license' in opus, 'opus should have license property');
    assert('description' in opus, 'opus should have description property');
  });
});
