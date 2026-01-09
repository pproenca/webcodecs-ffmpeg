/**
 * Helper for binding.gyp to resolve FFmpeg include paths.
 *
 * Usage in binding.gyp:
 *   "include_dirs": ["<!(node -p \"require('@pproenca/webcodecs-ffmpeg-dev/gyp-config').include\")"]
 */
const path = require('path');

module.exports = {
  include: path.join(__dirname, 'include')
};
