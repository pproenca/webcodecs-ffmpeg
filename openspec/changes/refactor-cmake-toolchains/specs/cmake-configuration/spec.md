# CMake Configuration

## ADDED Requirements

### Requirement: Centralized CMake Base Configuration

Common CMake options SHALL be defined in a single shared file to eliminate duplication across platforms.

#### Scenario: Base configuration in shared/cmake.mk
- **WHEN** any platform builds a CMake-based codec (aom, svt-av1, x265)
- **THEN** cmake invocation SHALL include options from `$(CMAKE_OPTS_BASE)` defined in `shared/cmake.mk`
- **AND** `CMAKE_OPTS_BASE` SHALL include:
  - `-DCMAKE_INSTALL_PREFIX=$(PREFIX)`
  - `-DCMAKE_PREFIX_PATH=$(PREFIX)`
  - `-DCMAKE_BUILD_TYPE=Release`
  - `-DCMAKE_C_COMPILER=$(CC)`
  - `-DCMAKE_CXX_COMPILER=$(CXX)`
  - `-DBUILD_SHARED_LIBS=OFF`

#### Scenario: Platform-specific options appended
- **WHEN** a platform config.mk defines `CMAKE_PLATFORM_OPTS`
- **THEN** the final `CMAKE_OPTS` SHALL be composed as `$(CMAKE_OPTS_BASE) $(CMAKE_PLATFORM_OPTS) $(CMAKE_CCACHE_OPTS)`
- **AND** platform-specific flags SHALL NOT duplicate base configuration flags

### Requirement: Consistent -Wno-dev Handling

CMake developer warnings SHALL be suppressed unless DEBUG mode is enabled.

#### Scenario: Warnings suppressed by default
- **WHEN** a CMake-based codec is built without DEBUG=1
- **THEN** cmake invocation SHALL include `-Wno-dev`

#### Scenario: Warnings enabled in debug mode
- **WHEN** a CMake-based codec is built with DEBUG=1
- **THEN** cmake invocation SHALL NOT include `-Wno-dev`

### Requirement: ccache Integration via Shared Configuration

ccache compiler launcher options SHALL be defined centrally when ccache is available.

#### Scenario: ccache detected
- **WHEN** ccache is available on the build system
- **THEN** `CMAKE_CCACHE_OPTS` SHALL include `-DCMAKE_C_COMPILER_LAUNCHER=ccache -DCMAKE_CXX_COMPILER_LAUNCHER=ccache`
- **AND** these options SHALL be included in `CMAKE_OPTS` automatically

#### Scenario: ccache not available
- **WHEN** ccache is not available on the build system
- **THEN** `CMAKE_CCACHE_OPTS` SHALL be empty
- **AND** cmake invocation SHALL NOT include compiler launcher options

### Requirement: Platform Include Order

Platforms SHALL include shared cmake.mk after config.mk to ensure variable composition works correctly.

#### Scenario: Correct include order in Makefile
- **WHEN** a platform Makefile is processed
- **THEN** `config.mk` SHALL be included before `$(SHARED_DIR)/cmake.mk`
- **AND** `CMAKE_PLATFORM_OPTS` defined in config.mk SHALL be available when cmake.mk composes `CMAKE_OPTS`

## MODIFIED Requirements

### Requirement: No Duplicate Build Flags

Codec recipes SHALL NOT duplicate flags that are already in `CMAKE_OPTS_BASE`.

#### Scenario: BUILD_SHARED_LIBS not duplicated
- **WHEN** aom.mk, svt-av1.mk, or x265.mk invokes cmake
- **THEN** codec-specific flags SHALL NOT include `-DBUILD_SHARED_LIBS=OFF`
- **BECAUSE** this flag is already in `CMAKE_OPTS_BASE`
