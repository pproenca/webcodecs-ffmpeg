# =============================================================================
# Shared FFmpeg Configuration
# =============================================================================
# Common FFmpeg configure options shared across all platforms.
# Platform-specific options (architecture, hardware acceleration) are defined
# in each platform's Makefile as FFMPEG_BASE_OPTS.
#
# Usage (in platform Makefile):
#   include $(PROJECT_ROOT)/shared/ffmpeg.mk
#   FFMPEG_CONFIGURE_OPTS := $(FFMPEG_BASE_OPTS) $(FFMPEG_LICENSE_OPTS)
# =============================================================================

# =============================================================================
# FFmpeg Codec Options (by license tier)
# =============================================================================
# These are identical across all platforms.

# BSD-licensed codecs (VP8/VP9, AV1, Opus, Vorbis)
FFMPEG_BSD_OPTS := \
	--enable-libvpx \
	--enable-libaom \
	--enable-libsvtav1 \
	--enable-libdav1d \
	--enable-libopus \
	--enable-libvorbis

# LGPL-licensed codecs (MP3)
FFMPEG_LGPL_OPTS := \
	--enable-libmp3lame

# GPL-licensed codecs (H.264, H.265)
FFMPEG_GPL_OPTS := \
	--enable-gpl \
	--enable-libx264 \
	--enable-libx265

# =============================================================================
# License Tier Selection
# =============================================================================
# Combines codec options based on LICENSE value.
# LICENSE is set in the platform Makefile or via command line.

ifeq ($(LICENSE),free)
    FFMPEG_LICENSE_OPTS := $(FFMPEG_BSD_OPTS) $(FFMPEG_LGPL_OPTS)
else
    # non-free: includes GPL codecs
    FFMPEG_LICENSE_OPTS := $(FFMPEG_BSD_OPTS) $(FFMPEG_LGPL_OPTS) $(FFMPEG_GPL_OPTS)
endif
