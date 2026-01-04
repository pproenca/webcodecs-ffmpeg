/**
 * Platform definitions for FFmpeg prebuilds
 *
 * Single source of truth for all supported platforms.
 */

export interface Platform {
  name: string;
  os: string;
  cpu: string;
  libc?: 'glibc' | 'musl';
  hwAccel?: string;
}

export const PLATFORMS: readonly Platform[] = [
  // macOS - universal binary (x64 + arm64)
  // Note: VideoToolbox is always enabled in darwin builds
  {name: 'darwin', os: 'darwin', cpu: 'x64'},
  // Deprecated platforms (for backwards compatibility)
  {name: 'darwin-x64', os: 'darwin', cpu: 'x64'},
  {name: 'darwin-arm64', os: 'darwin', cpu: 'arm64'},
  // Linux platforms
  {name: 'linux-x64-glibc', os: 'linux', cpu: 'x64', libc: 'glibc'},
  {name: 'linux-x64-musl', os: 'linux', cpu: 'x64', libc: 'musl'},
  {name: 'linux-arm64-glibc', os: 'linux', cpu: 'arm64', libc: 'glibc'},
  {name: 'linux-arm64-musl', os: 'linux', cpu: 'arm64', libc: 'musl'},
  {name: 'linux-armv7-glibc', os: 'linux', cpu: 'arm', libc: 'glibc'},
  // Linux hardware acceleration variants
  {name: 'linux-x64-glibc-vaapi', os: 'linux', cpu: 'x64', libc: 'glibc', hwAccel: 'VA-API'},
  {name: 'linux-x64-glibc-nvenc', os: 'linux', cpu: 'x64', libc: 'glibc', hwAccel: 'NVENC'},
  // Windows platforms
  {name: 'windows-x64', os: 'win32', cpu: 'x64'},
  {name: 'windows-x64-dxva2', os: 'win32', cpu: 'x64', hwAccel: 'DXVA2'},
];

export const DEPRECATED_PLATFORMS = ['darwin-x64', 'darwin-arm64'] as const;

export function getStandardPlatforms(): Platform[] {
  return PLATFORMS.filter(
    (p) => !p.hwAccel && !DEPRECATED_PLATFORMS.includes(p.name as typeof DEPRECATED_PLATFORMS[number])
  );
}

export function getHwAccelPlatforms(): Platform[] {
  return PLATFORMS.filter((p) => p.hwAccel);
}

export function getDeprecatedPlatforms(): Platform[] {
  return PLATFORMS.filter((p) =>
    DEPRECATED_PLATFORMS.includes(p.name as typeof DEPRECATED_PLATFORMS[number])
  );
}
