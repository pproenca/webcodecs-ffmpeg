# Third-Party Notices

This document contains licensing information for third-party dependencies bundled in the pre-compiled FFmpeg binaries distributed by this project.

## Bundled Dependencies

| Library | License |
| :--- | :--- |
| FFmpeg | [LGPLv2.1](https://www.gnu.org/licenses/old-licenses/lgpl-2.1.html) or [GPLv2](https://www.gnu.org/licenses/old-licenses/gpl-2.0.html) (when built with GPL components) |
| x264 | [GPLv2](https://www.gnu.org/licenses/old-licenses/gpl-2.0.html) or later |
| x265 | [GPLv2](https://www.gnu.org/licenses/old-licenses/gpl-2.0.html) or later |
| libvpx | [BSD 3-Clause License](https://github.com/webmproject/libvpx/blob/main/LICENSE) |
| libaom | [BSD 2-Clause License](https://aomedia.googlesource.com/aom/+/refs/heads/main/LICENSE), [Alliance for Open Media Patent License 1.0](https://aomedia.org/license/patent-license/) |
| SVT-AV1 | [BSD 2-Clause License](https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/master/LICENSE.md), [Alliance for Open Media Patent License 1.0](https://aomedia.org/license/patent-license/) |
| rav1e | [BSD 2-Clause License](https://github.com/xiph/rav1e/blob/master/LICENSE) |
| libtheora | [BSD 3-Clause License](https://github.com/xiph/theora/blob/master/COPYING) |
| Xvid | [GPLv2](https://www.gnu.org/licenses/old-licenses/gpl-2.0.html) or later |
| Opus | [BSD 3-Clause License](https://opus-codec.org/license/) |
| LAME | [LGPLv2](https://www.gnu.org/licenses/old-licenses/lgpl-2.0.html) or later |
| libvorbis | [BSD 3-Clause License](https://github.com/xiph/vorbis/blob/master/COPYING) |
| libogg | [BSD 3-Clause License](https://github.com/xiph/ogg/blob/master/COPYING) |
| fdk-aac | [Software License for The Fraunhofer FDK AAC Codec Library](https://github.com/mstorsjo/fdk-aac/blob/master/NOTICE) |
| FLAC | [BSD 3-Clause License](https://github.com/xiph/flac/blob/master/COPYING.Xiph) |
| Speex | [BSD 3-Clause License](https://github.com/xiph/speex/blob/master/COPYING) |
| libass | [ISC License](https://github.com/libass/libass/blob/master/COPYING) |
| FreeType | [The FreeType License](https://gitlab.freedesktop.org/freetype/freetype/-/blob/master/docs/FTL.TXT) or [GPLv2](https://www.gnu.org/licenses/old-licenses/gpl-2.0.html) |

## Licensing Summary

### GPL Components

This build includes **x264**, **x265**, and **Xvid**, which are licensed under the GNU General Public License v2.0 or later. As a result:

- **The distributed binaries are licensed under GPLv2 or later**
- When redistributing or using these binaries, you must comply with GPL terms
- Source code for all GPL components is available from their respective repositories (see `versions.properties`)

### LGPL Components

**FFmpeg** core (without GPL codecs) and **LAME** are available under the GNU Lesser General Public License. The LGPL usage follows the "or any later version" clause from LGPLv2/2.1.

### fdk-aac License Notice

The **fdk-aac** library is included under the Fraunhofer FDK AAC Codec Library Software License. This is a restrictive license that:

- Allows redistribution of binaries and source code
- Prohibits patent license grants
- Requires preservation of license notices
- Is NOT compatible with GPL (these builds do not enable fdk-aac when GPL codecs are present)

See the [full fdk-aac license](https://github.com/mstorsjo/fdk-aac/blob/master/NOTICE) for details.

### Alliance for Open Media Patent License

**libaom** and **SVT-AV1** include the Alliance for Open Media Patent License 1.0, which grants patent rights for AV1 codec implementations. See the [AOM Patent License](https://aomedia.org/license/patent-license/) for details.

## Build Variants

Different build variants may include different codec combinations:

- **Standard builds**: Include GPL codecs (x264, x265, Xvid) → **GPLv2+ licensed**
- **LGPL builds** (if provided): Exclude GPL codecs → **LGPLv2.1+ licensed**
- **Hardware acceleration variants**: Same licensing as standard builds, with platform-specific hardware APIs

## Source Code Availability

Source code for all bundled dependencies is available from:

1. **This repository**: Build scripts and version definitions (`versions.properties`)
2. **Upstream repositories**: Links provided in `versions.properties` for each dependency
3. **FFmpeg source**: Available from [https://git.ffmpeg.org/ffmpeg.git](https://git.ffmpeg.org/ffmpeg.git)

## Reporting Issues

Please report errors or omissions in this document by [creating an issue](https://github.com/pproenca/ffmpeg-prebuilds/issues).

---

**Last Updated**: 2026-01-04
**Applies to**: FFmpeg 8.0 builds and all platform variants
