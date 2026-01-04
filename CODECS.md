# FFmpeg Prebuilds - Codec Reference

This document details all video and audio codecs included in the FFmpeg prebuilds, their licenses, and implications for your project.

**Last Updated:** 2026-01-04
**FFmpeg Version:** 8.0
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

## Video Codecs

### H.264 / AVC (x264)

**Purpose:** Industry-standard video codec for web, streaming, and broadcasting
**License:** GPL 2.0 or later
**Version:** stable (latest from VideoLAN)
**Homepage:** https://www.videolan.org/developers/x264.html

**Why Included:**
- Most widely supported video codec across all devices and browsers
- Required for broad compatibility (YouTube, browsers, mobile devices)
- Patent pool licensing available through MPEG LA

**License Impact:** Forces entire build to GPL

---

### H.265 / HEVC (x265)

**Purpose:** Next-generation video codec with 50% better compression than H.264
**License:** GPL 2.0 or later
**Version:** 3.6
**Homepage:** https://www.videolan.org/developers/x265.html

**Why Included:**
- Superior compression for 4K/8K content
- Growing support in modern devices and streaming platforms
- Successor to H.264 for high-quality video

**License Impact:** Forces entire build to GPL

---

### VP8 (libvpx)

**Purpose:** Open-source alternative to H.264
**License:** BSD 3-Clause
**Version:** 1.15.2
**Homepage:** https://www.webmproject.org/

**Why Included:**
- Royalty-free alternative to H.264
- WebRTC standard codec
- Patent-free for web applications

**License Impact:** ✅ Permissive (BSD) - No GPL/commercial restrictions

---

### VP9 (libvpx)

**Purpose:** Open-source alternative to H.265
**License:** BSD 3-Clause
**Version:** 1.15.2
**Homepage:** https://www.webmproject.org/

**Why Included:**
- Royalty-free alternative to H.265
- YouTube's primary 4K codec
- Excellent compression with no licensing fees

**License Impact:** ✅ Permissive (BSD) - No GPL/commercial restrictions

---

### AV1 (libaom)

**Purpose:** Next-generation royalty-free codec by Alliance for Open Media
**License:** BSD 2-Clause
**Version:** 3.12.1
**Homepage:** https://aomedia.org/

**Why Included:**
- 30% better compression than VP9/H.265
- Completely royalty-free
- Future-proof for streaming applications
- Netflix, YouTube adoption

**License Impact:** ✅ Permissive (BSD) - No GPL/commercial restrictions

---

### AV1 (SVT-AV1)

**Purpose:** Intel's optimized AV1 encoder - 5-10x faster than libaom
**License:** BSD 2-Clause + Patent Grant
**Version:** 2.3.0
**Homepage:** https://gitlab.com/AOMediaCodec/SVT-AV1

**Why Included:**
- Dramatically faster AV1 encoding for production use
- Intel-optimized with SIMD/AVX2/AVX512 support
- Suitable for real-time encoding scenarios

**License Impact:** ✅ Permissive (BSD) - No GPL/commercial restrictions

---

### AV1 (rav1e)

**Purpose:** Rust-based AV1 encoder focused on quality
**License:** BSD 2-Clause
**Version:** 0.7.1
**Homepage:** https://github.com/xiph/rav1e
**Note:** Requires Rust toolchain - may be skipped if Cargo unavailable

**Why Included:**
- Highest quality AV1 encoding
- Memory-safe implementation (Rust)
- Alternative to libaom for quality-focused workflows

**License Impact:** ✅ Permissive (BSD) - No GPL/commercial restrictions

---

### Theora (libtheora)

**Purpose:** Legacy Ogg video codec
**License:** BSD 3-Clause
**Version:** 1.1.1
**Homepage:** https://www.theora.org/

**Why Included:**
- Historical compatibility with .ogv files
- Fully open-source with no patent concerns
- Used in older web content and Wikipedia

**License Impact:** ✅ Permissive (BSD) - No GPL/commercial restrictions

---

### Xvid (xvidcore)

**Purpose:** MPEG-4 Part 2 (ASP) video codec
**License:** GPL 1.0 or later
**Version:** 1.3.7
**Homepage:** https://www.xvid.com/

**Why Included:**
- Legacy compatibility with MPEG-4 ASP files (.avi, .mp4)
- Widely used in older media archives
- DivX alternative

**License Impact:** Forces entire build to GPL

---

## Audio Codecs

### AAC (fdk-aac)

**Purpose:** High-quality AAC encoder - industry-standard for audio
**License:** **Fraunhofer FDK AAC License (Non-free)**
**Version:** 2.0.3
**Homepage:** https://github.com/mstorsjo/fdk-aac

**Why Included:**
- Best AAC encoder available (superior to libavcodec's native AAC)
- Required for professional audio quality
- Standard for Apple devices, streaming, broadcasting

**License Impact:** ⚠️ **Non-free** - Requires patent licensing for commercial distribution
**Commercial Use:** Contact Via Licensing or MPEG LA for patent licenses

**Patent Warning:**
> This software requires a patent license for commercial distribution. Consult a lawyer if distributing commercially.

---

### Opus (libopus)

**Purpose:** Modern low-latency audio codec
**License:** BSD 3-Clause
**Version:** 1.5.2
**Homepage:** https://opus-codec.org/

**Why Included:**
- Best codec for VoIP, streaming, and real-time audio
- Royalty-free with excellent quality
- WebRTC standard audio codec

**License Impact:** ✅ Permissive (BSD) - No GPL/commercial restrictions

---

### MP3 (LAME)

**Purpose:** Legacy MP3 encoder
**License:** LGPL 2.0 or later
**Version:** 3.100
**Homepage:** https://lame.sourceforge.io/

**Why Included:**
- Universal MP3 support for compatibility
- Patent-free as of April 2017
- Required for MP3 playback/encoding

**License Impact:** ✅ LGPL (compatible with commercial use)

---

### Vorbis (libvorbis)

**Purpose:** Open-source alternative to MP3/AAC
**License:** BSD 3-Clause
**Version:** 1.3.7
**Homepage:** https://xiph.org/vorbis/

**Why Included:**
- Royalty-free, patent-free audio codec
- Used in Ogg containers (.ogg, .oga)
- Good quality-to-bitrate ratio

**License Impact:** ✅ Permissive (BSD) - No GPL/commercial restrictions

---

### FLAC (libFLAC)

**Purpose:** Lossless audio compression
**License:** BSD 3-Clause
**Version:** 1.4.3
**Homepage:** https://xiph.org/flac/

**Why Included:**
- Industry-standard lossless audio codec
- Archival quality with no quality loss
- Widely supported in audiophile and archival contexts

**License Impact:** ✅ Permissive (BSD) - No GPL/commercial restrictions

---

### Speex (libspeex)

**Purpose:** Speech-optimized audio codec
**License:** BSD 3-Clause
**Version:** 1.2.1
**Homepage:** https://www.speex.org/

**Why Included:**
- Optimized for human voice (VoIP, podcasts)
- Low bitrate with good speech quality
- Legacy compatibility (superseded by Opus for new projects)

**License Impact:** ✅ Permissive (BSD) - No GPL/commercial restrictions

---

## Subtitle & Rendering Libraries

### libass (Subtitle Rendering)

**Purpose:** Advanced SubStation Alpha (ASS/SSA) subtitle renderer
**License:** ISC (permissive)
**Version:** 0.17.3
**Homepage:** https://github.com/libass/libass

**Why Included:**
- Professional subtitle rendering for video players
- Supports styled subtitles with animations and effects
- Required for complex subtitle formats

**License Impact:** ✅ Permissive (ISC) - No GPL/commercial restrictions

---

### libfreetype (Font Rendering)

**Purpose:** Font rasterization library
**License:** FreeType License (BSD-style) or GPL 2.0
**Version:** 2.13.3
**Homepage:** https://freetype.org/

**Why Included:**
- Dependency for libass subtitle rendering
- TrueType/OpenType font support
- Text overlay rendering

**License Impact:** ✅ Dual-licensed (can use BSD-style FreeType License)

---

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
