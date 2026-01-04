/**
 * Hardware Acceleration Detection for FFmpeg Prebuilds
 *
 * Detects available GPU hardware and recommends the appropriate FFmpeg variant.
 * This enables automatic selection of hardware-accelerated builds when available.
 *
 * Usage:
 *   const { detectHardware, getRecommendedVariant } = require('@pproenca/ffmpeg/lib/detect-hw');
 *
 *   const hw = detectHardware();
 *   console.log('Available HW:', hw);
 *   // { platform: 'linux', gpu: 'intel', acceleration: 'vaapi', available: true }
 *
 *   const variant = getRecommendedVariant();
 *   console.log('Recommended:', variant);
 *   // '@pproenca/ffmpeg-linux-x64-glibc-vaapi'
 */

const { execSync } = require('child_process');
const { existsSync } = require('fs');
const { platform, arch } = require('os');

/**
 * Hardware Acceleration Types
 */
const HW_TYPES = {
  VAAPI: 'vaapi',      // Intel/AMD GPU (Linux)
  VDPAU: 'vdpau',      // NVIDIA GPU (Linux, legacy)
  NVENC: 'nvenc',      // NVIDIA dedicated encoders (Linux/Windows)
  VIDEOTOOLBOX: 'videotoolbox', // Apple hardware (macOS)
  DXVA2: 'dxva2',      // DirectX Video Acceleration (Windows)
  NONE: 'none'         // Software-only
};

/**
 * GPU Vendors
 */
const GPU_VENDORS = {
  INTEL: 'intel',
  AMD: 'amd',
  NVIDIA: 'nvidia',
  APPLE: 'apple',
  UNKNOWN: 'unknown'
};

/**
 * Detect Linux GPU vendor
 * @returns {string} GPU vendor
 */
function detectLinuxGPU() {
  try {
    // Check for /dev/dri/renderD* devices
    if (!existsSync('/dev/dri')) {
      return GPU_VENDORS.UNKNOWN;
    }

    // Try lspci to identify GPU
    const lspci = execSync('lspci 2>/dev/null || true', { encoding: 'utf8' });

    if (lspci.match(/VGA.*Intel/i)) {
      return GPU_VENDORS.INTEL;
    }
    if (lspci.match(/VGA.*AMD|VGA.*ATI/i)) {
      return GPU_VENDORS.AMD;
    }
    if (lspci.match(/VGA.*NVIDIA|3D.*NVIDIA/i)) {
      return GPU_VENDORS.NVIDIA;
    }

    // Fallback: check /sys/class/drm
    try {
      const drm = execSync('ls -1 /sys/class/drm/card*/device/vendor 2>/dev/null | head -1 | xargs cat 2>/dev/null', { encoding: 'utf8' }).trim();
      if (drm === '0x8086') return GPU_VENDORS.INTEL;
      if (drm === '0x1002') return GPU_VENDORS.AMD;
      if (drm === '0x10de') return GPU_VENDORS.NVIDIA;
    } catch (e) {
      // Ignore
    }

    return GPU_VENDORS.UNKNOWN;
  } catch (e) {
    return GPU_VENDORS.UNKNOWN;
  }
}

/**
 * Check if VA-API is available
 * @returns {boolean}
 */
function isVAAPIAvailable() {
  try {
    // Check for VA-API device
    if (!existsSync('/dev/dri/renderD128')) {
      return false;
    }

    // Check if vainfo command exists and works
    execSync('command -v vainfo >/dev/null 2>&1');
    const vainfo = execSync('vainfo 2>&1', { encoding: 'utf8' });
    return vainfo.includes('VAProfile');
  } catch (e) {
    return false;
  }
}

/**
 * Check if VDPAU is available
 * @returns {boolean}
 */
function isVDPAUAvailable() {
  try {
    execSync('command -v vdpauinfo >/dev/null 2>&1');
    const vdpauinfo = execSync('vdpauinfo 2>&1', { encoding: 'utf8' });
    return vdpauinfo.includes('VDPAU');
  } catch (e) {
    return false;
  }
}

/**
 * Check if NVENC is available
 * @returns {boolean}
 */
function isNVENCAvailable() {
  try {
    // Check for nvidia-smi
    execSync('command -v nvidia-smi >/dev/null 2>&1');
    const nvidiaInfo = execSync('nvidia-smi --query-gpu=name --format=csv,noheader 2>&1', { encoding: 'utf8' });

    // NVENC available on most modern NVIDIA GPUs
    // GeForce 600 series (Kepler) and newer
    return nvidiaInfo.length > 0;
  } catch (e) {
    return false;
  }
}

/**
 * Detect macOS hardware acceleration
 * @returns {string} HW type
 */
function detectMacOSHardware() {
  // VideoToolbox available on all macOS systems
  // Built into the OS, no additional checks needed
  return HW_TYPES.VIDEOTOOLBOX;
}

/**
 * Detect Windows hardware acceleration
 * @returns {string} HW type
 */
function detectWindowsHardware() {
  try {
    // Check for NVIDIA GPU first (NVENC preferred)
    const wmic = execSync('wmic path win32_VideoController get name', { encoding: 'utf8' });

    if (wmic.match(/NVIDIA/i)) {
      return HW_TYPES.NVENC;
    }

    // Fallback to DXVA2 (available on all Windows systems)
    return HW_TYPES.DXVA2;
  } catch (e) {
    // DXVA2 available by default on Windows
    return HW_TYPES.DXVA2;
  }
}

/**
 * Detect Linux hardware acceleration
 * @returns {string} HW type
 */
function detectLinuxHardware() {
  const gpu = detectLinuxGPU();

  // Priority: NVENC > VA-API > VDPAU > None
  if (gpu === GPU_VENDORS.NVIDIA && isNVENCAvailable()) {
    return HW_TYPES.NVENC;
  }

  if ((gpu === GPU_VENDORS.INTEL || gpu === GPU_VENDORS.AMD) && isVAAPIAvailable()) {
    return HW_TYPES.VAAPI;
  }

  if (gpu === GPU_VENDORS.NVIDIA && isVDPAUAvailable()) {
    return HW_TYPES.VDPAU;
  }

  return HW_TYPES.NONE;
}

/**
 * Detect available hardware acceleration
 * @returns {object} Hardware detection result
 */
function detectHardware() {
  const plat = platform();
  const architecture = arch();

  const result = {
    platform: plat,
    arch: architecture,
    gpu: GPU_VENDORS.UNKNOWN,
    acceleration: HW_TYPES.NONE,
    available: false
  };

  switch (plat) {
    case 'linux':
      result.gpu = detectLinuxGPU();
      result.acceleration = detectLinuxHardware();
      result.available = result.acceleration !== HW_TYPES.NONE;
      break;

    case 'darwin':
      result.gpu = GPU_VENDORS.APPLE;
      result.acceleration = detectMacOSHardware();
      result.available = true;
      break;

    case 'win32':
      result.acceleration = detectWindowsHardware();
      result.available = true;
      result.gpu = result.acceleration === HW_TYPES.NVENC ? GPU_VENDORS.NVIDIA : GPU_VENDORS.UNKNOWN;
      break;

    default:
      // Unsupported platform
      break;
  }

  return result;
}

/**
 * Get recommended FFmpeg package based on hardware
 * @param {boolean} preferHardware - Prefer hardware variant if available (default: true)
 * @returns {string} Package name
 */
function getRecommendedVariant(preferHardware = true) {
  const hw = detectHardware();
  const plat = hw.platform;
  const arch = hw.arch;

  // Base package names
  const BASE_PACKAGES = {
    'linux-x64': '@pproenca/ffmpeg-linux-x64-glibc',
    'linux-arm64': '@pproenca/ffmpeg-linux-arm64-glibc',
    'darwin-x64': '@pproenca/ffmpeg-darwin',
    'darwin-arm64': '@pproenca/ffmpeg-darwin',
    'win32-x64': '@pproenca/ffmpeg-windows-x64'
  };

  // Hardware-accelerated variants
  const HW_PACKAGES = {
    'linux-x64-vaapi': '@pproenca/ffmpeg-linux-x64-glibc-vaapi',
    'linux-x64-vdpau': '@pproenca/ffmpeg-linux-x64-glibc-vdpau',
    'linux-x64-nvenc': '@pproenca/ffmpeg-linux-x64-glibc-nvenc',
    'darwin-x64-videotoolbox': '@pproenca/ffmpeg-darwin-videotoolbox',
    'darwin-arm64-videotoolbox': '@pproenca/ffmpeg-darwin-videotoolbox',
    'win32-x64-nvenc': '@pproenca/ffmpeg-windows-x64-nvenc',
    'win32-x64-dxva2': '@pproenca/ffmpeg-windows-x64-dxva2'
  };

  const platformKey = `${plat}-${arch}`;
  const basePackage = BASE_PACKAGES[platformKey];

  if (!preferHardware || !hw.available) {
    return basePackage;
  }

  // Return HW-accelerated variant if available
  const hwKey = `${platformKey}-${hw.acceleration}`;
  return HW_PACKAGES[hwKey] || basePackage;
}

/**
 * Get FFmpeg encoding recommendations based on hardware
 * @returns {object} Encoder recommendations
 */
function getEncoderRecommendations() {
  const hw = detectHardware();

  const recommendations = {
    h264: 'libx264',      // Default software encoder
    h265: 'libx265',
    vp9: 'libvpx-vp9',
    av1: 'libsvtav1',
    useHardware: false
  };

  if (!hw.available) {
    return recommendations;
  }

  // Update with hardware encoders
  recommendations.useHardware = true;

  switch (hw.acceleration) {
    case HW_TYPES.VAAPI:
      recommendations.h264 = 'h264_vaapi';
      recommendations.h265 = 'hevc_vaapi';
      recommendations.vp9 = 'vp9_vaapi';
      recommendations.hwFlags = ['-vaapi_device', '/dev/dri/renderD128', '-vf', 'format=nv12,hwupload'];
      break;

    case HW_TYPES.NVENC:
      recommendations.h264 = 'h264_nvenc';
      recommendations.h265 = 'hevc_nvenc';
      recommendations.av1 = 'av1_nvenc';
      recommendations.hwFlags = ['-hwaccel', 'cuda', '-hwaccel_output_format', 'cuda'];
      break;

    case HW_TYPES.VIDEOTOOLBOX:
      recommendations.h264 = 'h264_videotoolbox';
      recommendations.h265 = 'hevc_videotoolbox';
      recommendations.hwFlags = ['-hwaccel', 'videotoolbox'];
      break;

    case HW_TYPES.DXVA2:
      recommendations.h264 = 'h264_qsv';  // Intel QuickSync on Windows
      recommendations.h265 = 'hevc_qsv';
      recommendations.hwFlags = ['-hwaccel', 'dxva2'];
      break;

    case HW_TYPES.VDPAU:
      recommendations.h264 = 'h264_nvenc';
      recommendations.h265 = 'hevc_nvenc';
      recommendations.hwFlags = ['-hwaccel', 'vdpau'];
      break;
  }

  return recommendations;
}

module.exports = {
  HW_TYPES,
  GPU_VENDORS,
  detectHardware,
  getRecommendedVariant,
  getEncoderRecommendations
};
