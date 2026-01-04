# FFmpeg Prebuilds - Codec Reference

This document details all video and audio codecs included in the FFmpeg prebuilds, their licenses, and implications for your project.

<!-- AUTO-GENERATED:timestamp:START -->
Last Updated: 2026-01-04 | FFmpeg Version: 8.0
<!-- AUTO-GENERATED:timestamp:END -->

**Build License:** **GPL-2.0-or-later + Non-free components**

---

## Quick License Summary

| Component Type | License | Commercial Use | Distribution Requirements |
|----------------|---------|----------------|---------------------------|
| **FFmpeg Core** | LGPL 2.1+ | ✅ Permitted | Source disclosure if modified |
| **GPL Codecs** | GPL 2.0+ | ✅ Permitted* | Entire build becomes GPL - source disclosure required |
| **Non-free Codecs** | Proprietary | ⚠️ Restricted | Patent licensing may be required |

**\* Commercial use permitted under GPL, but you must disclose your source code if distributing the binaries.**

---

## Overall Build License

Due to the inclusion of **x264**, **x265** (GPL), and **fdk-aac** (Non-free), this entire build is licensed as:

```
GPL-2.0-or-later + Non-free components
```

**Implications:**
- ✅ You can use this for commercial projects
- ✅ You can modify and redistribute
- ❌ You **must** disclose your source code if you distribute binaries
- ❌ You **must** comply with patent licensing for fdk-aac if distributing commercially
- ⚠️ Consider building without GPL/Non-free codecs if you cannot accept these terms

---

<!-- AUTO-GENERATED:codec-list:START -->
## Video Codecs

### H264 - H.264/AVC - Most widely supported video codec

- **Library:** libx264
- **License:** GPL-2.0-or-later
- **Status:** ✅ Enabled
- **Configure Flag:** `--enable-libx264`

### H265 - H.265/HEVC - Better compression than H.264

- **Library:** libx265
- **License:** GPL-2.0-or-later
- **Status:** ✅ Enabled
- **Configure Flag:** `--enable-libx265`

### VP8 - VP8 - WebM video codec

- **Library:** libvpx
- **License:** BSD-3-Clause
- **Status:** ✅ Enabled
- **Configure Flag:** `--enable-libvpx`

### VP9 - VP9 - Improved WebM codec (shares libvpx with VP8)

- **Library:** libvpx
- **License:** BSD-3-Clause
- **Status:** ✅ Enabled
- **Configure Flag:** `--enable-libvpx`

### AV1 - AV1 - Royalty-free next-gen codec (reference encoder)

- **Library:** libaom
- **License:** BSD-2-Clause
- **Status:** ✅ Enabled
- **Configure Flag:** `--enable-libaom`

### SVT-AV1 - SVT-AV1 - Intel's optimized AV1 encoder (faster than libaom)

- **Library:** libsvtav1
- **License:** BSD-2-Clause
- **Status:** ✅ Enabled
- **Configure Flag:** `--enable-libsvtav1`
- **Build Dependency:** SVT-AV1

### RAV1E - rav1e - Rust AV1 encoder (requires Cargo toolchain)

- **Library:** librav1e
- **License:** BSD-2-Clause
- **Status:** ❌ Disabled
- **Configure Flag:** `--enable-librav1e`
- **Build Dependency:** Rust/Cargo
- **Notes:** Disabled by default - requires Rust toolchain which increases build time significantly

### THEORA - Theora - Legacy Ogg video codec

- **Library:** libtheora
- **License:** BSD-3-Clause
- **Status:** ✅ Enabled
- **Configure Flag:** `--enable-libtheora`
- **Build Dependency:** libtheora

### XVID - Xvid - MPEG-4 ASP codec

- **Library:** libxvid
- **License:** GPL-2.0-or-later
- **Status:** ✅ Enabled
- **Configure Flag:** `--enable-libxvid`
- **Build Dependency:** xvidcore

## Audio Codecs

### OPUS - Opus - Best quality/bitrate for voice and music

- **Library:** libopus
- **License:** BSD-3-Clause
- **Status:** ✅ Enabled
- **Configure Flag:** `--enable-libopus`

### MP3 - MP3 - Universal audio codec (LAME encoder)

- **Library:** libmp3lame
- **License:** LGPL-2.1-or-later
- **Status:** ✅ Enabled
- **Configure Flag:** `--enable-libmp3lame`

### AAC - AAC - FFmpeg native encoder

- **Library:** native
- **License:** LGPL-2.1-or-later
- **Status:** ✅ Enabled
- **Notes:** Built into FFmpeg, no external library needed

### FDK-AAC - fdk-aac - High-quality AAC encoder (better than native)

- **Library:** libfdk-aac
- **License:** Non-free
- **Status:** ✅ Enabled
- **Configure Flag:** `--enable-libfdk-aac --enable-nonfree`
- **Build Dependency:** fdk-aac
- **Notes:** Non-free license - may have distribution restrictions

### FLAC - FLAC - Lossless audio compression

- **Library:** libflac
- **License:** BSD-3-Clause
- **Status:** ✅ Enabled
- **Configure Flag:** `--enable-libflac`
- **Build Dependency:** flac

### SPEEX - Speex - Speech codec (optimized for voice)

- **Library:** libspeex
- **License:** BSD-3-Clause
- **Status:** ✅ Enabled
- **Configure Flag:** `--enable-libspeex`
- **Build Dependency:** speex

### VORBIS - Vorbis - Ogg audio codec

- **Library:** libvorbis
- **License:** BSD-3-Clause
- **Status:** ✅ Enabled
- **Configure Flag:** `--enable-libvorbis`


<!-- AUTO-GENERATED:codec-list:END -->

## Build Configuration Options

### Creating an LGPL-Only Build

If you cannot accept GPL terms, you can build FFmpeg with only LGPL/BSD codecs:

**Exclude from configure:**
```bash
# Remove these flags:
--enable-libx264      # GPL
--enable-libx265      # GPL
--enable-libxvid      # GPL
--enable-libfdk-aac   # Non-free
--enable-nonfree      # Remove this flag
```

**Resulting build license:** LGPL 2.1+ (with BSD/ISC components)

**Trade-offs:**
- ❌ No H.264 encoding (can still decode via FFmpeg's native decoder)
- ❌ No H.265 encoding
- ❌ No high-quality AAC encoding (use native FFmpeg AAC or Opus instead)
- ✅ Still have VP8, VP9, AV1, Opus, Vorbis, FLAC

---

## Patent & Legal Considerations

### Patent-Free Codecs (Safe for All Use)

| Codec | Status | Notes |
|-------|--------|-------|
| VP8, VP9 | ✅ Royalty-free | Google's patent grant |
| AV1 | ✅ Royalty-free | Alliance for Open Media patent grant |
| Opus | ✅ Royalty-free | IETF standard, royalty-free |
| Vorbis | ✅ Royalty-free | Xiph.Org patent-free |
| FLAC | ✅ Royalty-free | Xiph.Org patent-free |
| Theora | ✅ Royalty-free | Xiph.Org patent-free |

### Codecs Requiring Patent Licenses

| Codec | Patent Holder | License Contact | Notes |
|-------|---------------|-----------------|-------|
| H.264/AVC | MPEG LA | https://www.mpegla.com/ | Free for non-commercial; commercial requires license |
| H.265/HEVC | Multiple pools | MPEG LA, HEVC Advance | Complex patent situation |
| AAC | Via Licensing, MPEG LA | https://www.via-la.com/ | Required for fdk-aac commercial use |

**Important:** Even GPL codecs like x264/x265 may require patent licenses for commercial distribution. The GPL covers the software license, not the patents.

---

## Recommendations by Use Case

### Web Streaming (Royalty-Free)

✅ **Recommended:**
- Video: VP9 or AV1 (SVT-AV1 for speed)
- Audio: Opus
- **License:** All BSD - fully royalty-free

### Broadcast/Professional (Maximum Compatibility)

✅ **Recommended:**
- Video: H.264 (x264) or H.265 (x265)
- Audio: AAC (fdk-aac)
- **License:** GPL + Non-free - ensure patent licenses obtained

### Archive/High Quality (Lossless)

✅ **Recommended:**
- Video: AV1 (libaom or rav1e)
- Audio: FLAC
- **License:** All BSD - fully royalty-free

---

## References

- **FFmpeg Licensing:** https://ffmpeg.org/legal.html
- **H.264 Patents:** https://www.mpegla.com/programs/avc-h-264/
- **AV1 Patent Grant:** https://aomedia.org/license/patent-license/
- **GPL FAQ:** https://www.gnu.org/licenses/gpl-faq.html

---

## Disclaimer

This document provides general information and does not constitute legal advice. Consult a qualified intellectual property attorney for licensing questions specific to your use case.
