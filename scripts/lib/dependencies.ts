/**
 * Dependency Registry
 *
 * Single source of truth for dependency metadata including:
 * - Version fetching configuration
 * - License information
 * - Homepage and release URLs
 * - Download URL templates
 */

// ============================================================================
// Types
// ============================================================================

export interface License {
  name: string;
  url: string;
}

export type FetchSource =
  | {type: 'github'; repo: string; tagPattern: RegExp}
  | {type: 'gitlab'; host: string; project: string; tagPattern: RegExp}
  | {type: 'bitbucket'; repo: string; tagPattern: RegExp}
  | {type: 'static'; version: string}
  | {type: 'anitya'; projectName: string};

export interface DependencyMetadata {
  name: string;
  homepage: string;
  releasesUrl: string;
  license: License;
  versionKey: string;
  urlKey?: string;
  sha256Key?: string;
  gitUrlKey?: string;
  fetchSource: FetchSource;
  downloadUrl?: (version: string) => string;
}

// ============================================================================
// Tag Patterns
// ============================================================================

const SEMVER_TAG = /^v[0-9]+(?:\.[0-9]+)*$/;
const SEMVER_NO_PREFIX_TAG = /^[0-9]+(?:\.[0-9]+)*$/;
const FFMPEG_TAG = /^n[0-9]+(?:\.[0-9]+){1,2}$/;
const NASM_TAG = /^nasm-[0-9]+(?:\.[0-9]+)*$/;
const OPENSSL_TAG = /^openssl-3\.[0-9]+(?:\.[0-9]+)?$/;

// ============================================================================
// Dependency Registry
// ============================================================================

export const DEPENDENCIES: readonly DependencyMetadata[] = [
  // ---------------------------------------------------------------------------
  // Core FFmpeg
  // ---------------------------------------------------------------------------
  {
    name: 'FFmpeg',
    homepage: 'https://ffmpeg.org/',
    releasesUrl: 'https://ffmpeg.org/releases/',
    license: {
      name: 'LGPL-2.1',
      url: 'https://ffmpeg.org/legal.html',
    },
    versionKey: 'FFMPEG_VERSION',
    gitUrlKey: 'FFMPEG_GIT_URL',
    fetchSource: {type: 'github', repo: 'FFmpeg/FFmpeg', tagPattern: FFMPEG_TAG},
  },

  // ---------------------------------------------------------------------------
  // Video Codecs
  // ---------------------------------------------------------------------------
  {
    name: 'x264',
    homepage: 'https://www.videolan.org/developers/x264.html',
    releasesUrl: 'https://code.videolan.org/videolan/x264/-/tags',
    license: {
      name: 'GPL-2.0',
      url: 'https://www.gnu.org/licenses/old-licenses/gpl-2.0.html',
    },
    versionKey: 'X264_VERSION',
    gitUrlKey: 'X264_GIT_URL',
    fetchSource: {type: 'static', version: 'stable'},
  },
  {
    name: 'x265',
    homepage: 'https://x265.org/',
    releasesUrl: 'https://bitbucket.org/multicoreware/x265_git/downloads/',
    license: {
      name: 'GPL-2.0',
      url: 'https://bitbucket.org/multicoreware/x265_git/src/master/COPYING',
    },
    versionKey: 'X265_VERSION',
    gitUrlKey: 'X265_GIT_URL',
    fetchSource: {type: 'bitbucket', repo: 'multicoreware/x265_git', tagPattern: SEMVER_NO_PREFIX_TAG},
  },
  {
    name: 'libvpx',
    homepage: 'https://www.webmproject.org/code/',
    releasesUrl: 'https://github.com/webmproject/libvpx/releases',
    license: {
      name: 'BSD-3-Clause',
      url: 'https://github.com/webmproject/libvpx/blob/main/LICENSE',
    },
    versionKey: 'LIBVPX_VERSION',
    gitUrlKey: 'LIBVPX_GIT_URL',
    fetchSource: {type: 'github', repo: 'webmproject/libvpx', tagPattern: SEMVER_TAG},
  },
  {
    name: 'libaom',
    homepage: 'https://aomedia.googlesource.com/aom',
    releasesUrl: 'https://aomedia.googlesource.com/aom/+refs',
    license: {
      name: 'BSD-2-Clause',
      url: 'https://aomedia.org/license/software-license/',
    },
    versionKey: 'LIBAOM_VERSION',
    gitUrlKey: 'LIBAOM_GIT_URL',
    // libaom is on Google Source which doesn't have a convenient API
    fetchSource: {type: 'static', version: 'v3.12.1'},
  },
  {
    name: 'SVT-AV1',
    homepage: 'https://gitlab.com/AOMediaCodec/SVT-AV1',
    releasesUrl: 'https://gitlab.com/AOMediaCodec/SVT-AV1/-/tags',
    license: {
      name: 'BSD-3-Clause-Clear',
      url: 'https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/master/LICENSE.md',
    },
    versionKey: 'SVTAV1_VERSION',
    gitUrlKey: 'SVTAV1_GIT_URL',
    fetchSource: {type: 'gitlab', host: 'gitlab.com', project: 'AOMediaCodec/SVT-AV1', tagPattern: SEMVER_TAG},
  },
  {
    name: 'dav1d',
    homepage: 'https://code.videolan.org/videolan/dav1d',
    releasesUrl: 'https://code.videolan.org/videolan/dav1d/-/tags',
    license: {
      name: 'BSD-2-Clause',
      url: 'https://code.videolan.org/videolan/dav1d/-/blob/master/COPYING',
    },
    versionKey: 'DAV1D_VERSION',
    urlKey: 'DAV1D_URL',
    sha256Key: 'DAV1D_SHA256',
    fetchSource: {type: 'gitlab', host: 'code.videolan.org', project: 'videolan/dav1d', tagPattern: SEMVER_NO_PREFIX_TAG},
    downloadUrl: (v) => `https://downloads.videolan.org/pub/videolan/dav1d/${v}/dav1d-${v}.tar.xz`,
  },
  {
    name: 'rav1e',
    homepage: 'https://github.com/xiph/rav1e',
    releasesUrl: 'https://github.com/xiph/rav1e/releases',
    license: {
      name: 'BSD-2-Clause',
      url: 'https://github.com/xiph/rav1e/blob/master/LICENSE',
    },
    versionKey: 'RAV1E_VERSION',
    gitUrlKey: 'RAV1E_GIT_URL',
    fetchSource: {type: 'github', repo: 'xiph/rav1e', tagPattern: SEMVER_TAG},
  },
  {
    name: 'Theora',
    homepage: 'https://www.theora.org/',
    releasesUrl: 'https://xiph.org/downloads/',
    license: {
      name: 'BSD-3-Clause',
      url: 'https://git.xiph.org/?p=theora.git;a=blob;f=COPYING',
    },
    versionKey: 'THEORA_VERSION',
    urlKey: 'THEORA_URL',
    sha256Key: 'THEORA_SHA256',
    fetchSource: {type: 'static', version: '1.1.1'},
    downloadUrl: (v) => `https://ftp.osuosl.org/pub/xiph/releases/theora/libtheora-${v}.tar.gz`,
  },
  {
    name: 'Xvid',
    homepage: 'https://www.xvid.com/',
    releasesUrl: 'https://labs.xvid.com/source/',
    license: {
      name: 'GPL-2.0',
      url: 'http://websvn.xvid.org/cvs/viewvc.cgi/trunk/xvidcore/LICENSE',
    },
    versionKey: 'XVID_VERSION',
    urlKey: 'XVID_URL',
    sha256Key: 'XVID_SHA256',
    fetchSource: {type: 'static', version: '1.3.7'},
    downloadUrl: (v) => `https://downloads.xvid.com/downloads/xvidcore-${v}.tar.gz`,
  },

  // ---------------------------------------------------------------------------
  // Audio Codecs
  // ---------------------------------------------------------------------------
  {
    name: 'Opus',
    homepage: 'https://opus-codec.org/',
    releasesUrl: 'https://opus-codec.org/downloads/',
    license: {
      name: 'BSD-3-Clause',
      url: 'https://opus-codec.org/license/',
    },
    versionKey: 'OPUS_VERSION',
    urlKey: 'OPUS_URL',
    sha256Key: 'OPUS_SHA256',
    fetchSource: {type: 'github', repo: 'xiph/opus', tagPattern: SEMVER_TAG},
    downloadUrl: (v) => `https://downloads.xiph.org/releases/opus/opus-${v}.tar.gz`,
  },
  {
    name: 'LAME',
    homepage: 'https://lame.sourceforge.io/',
    releasesUrl: 'https://lame.sourceforge.io/download.php',
    license: {
      name: 'LGPL-2.0',
      url: 'https://lame.sourceforge.io/license.txt',
    },
    versionKey: 'LAME_VERSION',
    urlKey: 'LAME_URL',
    sha256Key: 'LAME_SHA256',
    fetchSource: {type: 'static', version: '3.100'},
    downloadUrl: (v) => `https://downloads.sourceforge.net/project/lame/lame/${v}/lame-${v}.tar.gz`,
  },
  {
    name: 'Vorbis',
    homepage: 'https://xiph.org/vorbis/',
    releasesUrl: 'https://xiph.org/downloads/',
    license: {
      name: 'BSD-3-Clause',
      url: 'https://www.xiph.org/licenses/bsd/',
    },
    versionKey: 'VORBIS_VERSION',
    urlKey: 'VORBIS_URL',
    sha256Key: 'VORBIS_SHA256',
    fetchSource: {type: 'static', version: '1.3.7'},
    downloadUrl: (v) => `https://ftp.osuosl.org/pub/xiph/releases/vorbis/libvorbis-${v}.tar.gz`,
  },
  {
    name: 'Ogg',
    homepage: 'https://www.xiph.org/ogg/',
    releasesUrl: 'https://xiph.org/downloads/',
    license: {
      name: 'BSD-3-Clause',
      url: 'https://www.xiph.org/licenses/bsd/',
    },
    versionKey: 'OGG_VERSION',
    urlKey: 'OGG_URL',
    sha256Key: 'OGG_SHA256',
    fetchSource: {type: 'static', version: '1.3.5'},
    downloadUrl: (v) => `https://ftp.osuosl.org/pub/xiph/releases/ogg/libogg-${v}.tar.gz`,
  },
  {
    name: 'fdk-aac',
    homepage: 'https://github.com/mstorsjo/fdk-aac',
    releasesUrl: 'https://github.com/mstorsjo/fdk-aac/releases',
    license: {
      name: 'FDK-AAC',
      url: 'https://github.com/mstorsjo/fdk-aac/blob/master/NOTICE',
    },
    versionKey: 'FDKAAC_VERSION',
    gitUrlKey: 'FDKAAC_GIT_URL',
    fetchSource: {type: 'github', repo: 'mstorsjo/fdk-aac', tagPattern: SEMVER_TAG},
  },
  {
    name: 'FLAC',
    homepage: 'https://xiph.org/flac/',
    releasesUrl: 'https://xiph.org/downloads/',
    license: {
      name: 'BSD-3-Clause',
      url: 'https://github.com/xiph/flac/blob/master/COPYING.Xiph',
    },
    versionKey: 'FLAC_VERSION',
    urlKey: 'FLAC_URL',
    sha256Key: 'FLAC_SHA256',
    fetchSource: {type: 'static', version: '1.4.3'},
    downloadUrl: (v) => `https://ftp.osuosl.org/pub/xiph/releases/flac/flac-${v}.tar.xz`,
  },
  {
    name: 'Speex',
    homepage: 'https://www.speex.org/',
    releasesUrl: 'https://xiph.org/downloads/',
    license: {
      name: 'BSD-3-Clause',
      url: 'https://www.xiph.org/licenses/bsd/',
    },
    versionKey: 'SPEEX_VERSION',
    urlKey: 'SPEEX_URL',
    sha256Key: 'SPEEX_SHA256',
    fetchSource: {type: 'static', version: '1.2.1'},
    downloadUrl: (v) => `https://ftp.osuosl.org/pub/xiph/releases/speex/speex-${v}.tar.gz`,
  },

  // ---------------------------------------------------------------------------
  // Subtitle/Rendering Libraries
  // ---------------------------------------------------------------------------
  {
    name: 'libass',
    homepage: 'https://github.com/libass/libass',
    releasesUrl: 'https://github.com/libass/libass/releases',
    license: {
      name: 'ISC',
      url: 'https://github.com/libass/libass/blob/master/COPYING',
    },
    versionKey: 'LIBASS_VERSION',
    urlKey: 'LIBASS_URL',
    sha256Key: 'LIBASS_SHA256',
    fetchSource: {type: 'github', repo: 'libass/libass', tagPattern: SEMVER_NO_PREFIX_TAG},
    downloadUrl: (v) => `https://github.com/libass/libass/releases/download/${v}/libass-${v}.tar.gz`,
  },
  {
    name: 'FreeType',
    homepage: 'https://freetype.org/',
    releasesUrl: 'https://download.savannah.gnu.org/releases/freetype/',
    license: {
      name: 'FTL',
      url: 'https://freetype.org/license.html',
    },
    versionKey: 'FREETYPE_VERSION',
    urlKey: 'FREETYPE_URL',
    sha256Key: 'FREETYPE_SHA256',
    fetchSource: {type: 'static', version: '2.13.3'},
    downloadUrl: (v) => `https://download.savannah.gnu.org/releases/freetype/freetype-${v}.tar.xz`,
  },

  // ---------------------------------------------------------------------------
  // Build Tools
  // ---------------------------------------------------------------------------
  {
    name: 'NASM',
    homepage: 'https://www.nasm.us/',
    releasesUrl: 'https://www.nasm.us/pub/nasm/releasebuilds/',
    license: {
      name: 'BSD-2-Clause',
      url: 'https://github.com/netwide-assembler/nasm/blob/master/LICENSE',
    },
    versionKey: 'NASM_VERSION',
    urlKey: 'NASM_URL',
    sha256Key: 'NASM_SHA256',
    fetchSource: {type: 'github', repo: 'netwide-assembler/nasm', tagPattern: NASM_TAG},
    downloadUrl: (v) => `https://github.com/netwide-assembler/nasm/archive/refs/tags/nasm-${v}.tar.gz`,
  },

  // ---------------------------------------------------------------------------
  // Network Libraries
  // ---------------------------------------------------------------------------
  {
    name: 'OpenSSL',
    homepage: 'https://www.openssl.org/',
    releasesUrl: 'https://www.openssl.org/source/',
    license: {
      name: 'Apache-2.0',
      url: 'https://www.openssl.org/source/license.html',
    },
    versionKey: 'OPENSSL_VERSION',
    urlKey: 'OPENSSL_URL',
    sha256Key: 'OPENSSL_SHA256',
    fetchSource: {type: 'github', repo: 'openssl/openssl', tagPattern: OPENSSL_TAG},
    downloadUrl: (v) => `https://www.openssl.org/source/openssl-${v}.tar.gz`,
  },
];

// ============================================================================
// Helper Functions
// ============================================================================

/**
 * Get dependency by name (case-insensitive)
 */
export function getDependency(name: string): DependencyMetadata | undefined {
  const lowerName = name.toLowerCase();
  return DEPENDENCIES.find((d) => d.name.toLowerCase() === lowerName);
}

/**
 * Get dependency by version key
 */
export function getDependencyByVersionKey(versionKey: string): DependencyMetadata | undefined {
  return DEPENDENCIES.find((d) => d.versionKey === versionKey);
}
