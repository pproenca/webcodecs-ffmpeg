# Codec Cross-Compilation Checklist

When adding a new codec to the build system, use this checklist to ensure proper cross-compilation support (especially for darwin-x64 built from ARM64 hosts).

## Build System Detection

Each build system auto-detects host architecture differently. Identify which system your codec uses:

| Build System | Detection Mechanism | Cross-Compilation Fix |
|--------------|--------------------|-----------------------|
| **CMake** | `CMAKE_SYSTEM_PROCESSOR` | Add `-DCMAKE_SYSTEM_PROCESSOR=<target>` to `CMAKE_OPTS` |
| **Autoconf** | `config.guess` / `uname -m` | Add `--host=<target>-apple-darwin` to configure |
| **Meson** | `host_machine.cpu_family()` | Use cross-file (e.g., `x86_64-darwin.ini`) |
| **Raw configure** | Various | Check codec docs for `--arch` or `--cpu` flags |

## Checklist for New Codecs

### 1. Identify Build System
- [ ] Check if codec uses CMake (`CMakeLists.txt`)
- [ ] Check if codec uses Autoconf (`configure.ac` or `configure`)
- [ ] Check if codec uses Meson (`meson.build`)
- [ ] Check if codec uses custom build (`Makefile` only)

### 2. CMake-based Codecs (aom, x265, svt-av1)
- [ ] Inherit `$(CMAKE_OPTS)` from `config.mk`
- [ ] Add codec-specific target CPU flag if needed (e.g., `-DAOM_TARGET_CPU=x86_64`)
- [ ] Verify codec doesn't override `CMAKE_SYSTEM_PROCESSOR`

### 3. Autoconf-based Codecs (x264, opus, vorbis, ogg, lame, libvpx)
- [ ] Add `--host=x86_64-apple-darwin` for darwin-x64 platform
- [ ] Verify `CFLAGS` and `LDFLAGS` with `-arch` flag are passed
- [ ] Check if codec has `--disable-asm` fallback for problematic assembly

### 4. Meson-based Codecs (dav1d)
- [ ] Use cross-file via `--cross-file=$(MESON_CROSS_FILE)`
- [ ] Verify cross-file exists for target architecture
- [ ] Check `host_machine` settings in cross-file

### 5. Assembly/Intrinsics Requirements
- [ ] Check if codec requires NASM/YASM for x86 assembly
- [ ] For darwin-x64: Add `nasm.stamp` dependency if codec uses x86 assembly
- [ ] Verify assembly is disabled or correct arch is selected

### 6. pkg-config Dependencies
- [ ] Ensure codec finds dependencies via `PKG_CONFIG_LIBDIR` (not `PKG_CONFIG_PATH`)
- [ ] Test that host system libraries don't leak into build

### 7. Verification
- [ ] Build completes without architecture-related errors
- [ ] Run `file <output>` to verify binary architecture
- [ ] Check `lipo -info <output>` for fat binary issues on macOS

## Platform-Specific Notes

### darwin-x64 (Cross-compiled from ARM64)
- Uses `PKG_CONFIG_LIBDIR` to isolate from host ARM64 libs
- Requires `CMAKE_SYSTEM_PROCESSOR=x86_64` for CMake
- Requires `--host=x86_64-apple-darwin` for Autoconf
- Requires Meson cross-file for Meson
- NASM must be x86_64 binary (built from source, runs via Rosetta 2)

### darwin-arm64 (Native build)
- Host = Target, so fewer cross-compilation issues
- Still uses `PKG_CONFIG_LIBDIR` for consistency

## Rosetta 2 Deprecation (Action Required by 2027)

> **Warning:** Apple announced at WWDC 2025 that Rosetta 2 will be removed in macOS 28 (2027).

The current darwin-x64 build relies on Rosetta 2 to run x86_64 NASM on ARM64 hosts. Before 2027, evaluate these alternatives:

### Option 1: Docker-based Cross-Compilation (Recommended)
- Use Docker with `--platform linux/amd64` for x86_64 toolchain
- Pros: No Rosetta dependency, consistent environment
- Cons: Requires Docker, may have performance overhead

### Option 2: Remote x86_64 Build Runners
- Use dedicated x86_64 macOS runners or Linux runners
- Pros: Native compilation, no translation overhead
- Cons: Requires additional infrastructure

### Option 3: LLVM Cross-Compilation Toolchain
- Use LLVM's cross-compilation capabilities with `--target=x86_64-apple-darwin`
- Pros: Modern, well-supported approach
- Cons: May require toolchain setup, NASM still needs x86_64 binary

### Option 4: Pre-built NASM Binaries
- Download pre-built x86_64 NASM from official releases
- Pros: Simple, no build required
- Cons: Depends on external binary availability

### Migration Timeline
- **Now**: Current approach works with Rosetta 2
- **2026**: Begin testing alternatives
- **2027 Q1**: Complete migration before macOS 28 release

## Common Failure Modes

| Symptom | Cause | Fix |
|---------|-------|-----|
| "ARM NEON" in x86_64 build | CMake detected ARM64 host | Add `CMAKE_SYSTEM_PROCESSOR` |
| Conflicting `-arch` flags | Autoconf added host arch | Add `--host` flag |
| "Library not found" | pkg-config found host libs | Use `PKG_CONFIG_LIBDIR` |
| NASM multipass test fails | ARM64 NASM can't assemble x86 | Build x86_64 NASM from source |
| SSE intrinsic errors | Wrong assembly code selected | Check `AOM_TARGET_CPU` or equivalent |

## Example: Adding a New CMake Codec

```makefile
# codecs/bsd/newcodec.mk

NEWCODEC_SRC := $(SOURCES_DIR)/newcodec-$(NEWCODEC_VERSION)
NEWCODEC_BUILD := $(BUILD_DIR)/newcodec

newcodec.stamp: dirs
	$(call log_info,Building newcodec $(NEWCODEC_VERSION)...)
	$(call download_and_extract,newcodec,$(NEWCODEC_URL),$(SOURCES_DIR))
	mkdir -p $(NEWCODEC_BUILD)
	cd $(NEWCODEC_BUILD) && \
		cmake $(NEWCODEC_SRC) \
			$(CMAKE_OPTS) \
			-DNEWCODEC_TARGET_CPU=$(ARCH) \  # If codec has its own CPU flag
			-DBUILD_SHARED_LIBS=OFF \
			-DENABLE_TESTS=OFF && \
		$(MAKE) -j$(NPROC) && \
		$(MAKE) install
	@touch $(STAMPS_DIR)/$@
```

## Example: Adding a New Autoconf Codec

```makefile
# codecs/bsd/newcodec.mk

NEWCODEC_SRC := $(SOURCES_DIR)/newcodec-$(NEWCODEC_VERSION)

newcodec.stamp: dirs
	$(call log_info,Building newcodec $(NEWCODEC_VERSION)...)
	$(call download_and_extract,newcodec,$(NEWCODEC_URL),$(SOURCES_DIR))
	cd $(NEWCODEC_SRC) && \
		./configure \
			--host=$(ARCH)-apple-darwin \  # Critical for cross-compilation
			--prefix=$(PREFIX) \
			--enable-static \
			--disable-shared \
			CC="$(CC)" \
			CFLAGS="$(CFLAGS)" \
			LDFLAGS="$(LDFLAGS)" && \
		$(MAKE) -j$(NPROC) && \
		$(MAKE) install
	@touch $(STAMPS_DIR)/$@
```
