/**
 * Path utilities for ESM scripts
 *
 * Provides helpers for common ESM patterns like __dirname equivalent
 * and main module detection.
 */

import {dirname} from 'node:path';
import {fileURLToPath} from 'node:url';

/**
 * Get the directory path of the calling script (ESM equivalent of __dirname)
 */
export function getScriptDir(importMetaUrl: string): string {
  return dirname(fileURLToPath(importMetaUrl));
}

/**
 * Check if the current module is being run directly (not imported)
 */
export function isMainModule(importMetaUrl: string): boolean {
  return importMetaUrl === `file://${process.argv[1]}`;
}
