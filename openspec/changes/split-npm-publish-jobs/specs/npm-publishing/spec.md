# npm Publishing

## MODIFIED Requirements

### Requirement: Release workflow SHALL publish npm packages with rate limit mitigation

The release workflow SHALL publish all npm packages using separate jobs to avoid E429 rate limit errors.

#### Scenario: Platform packages published via matrix jobs

**Given** a release workflow is triggered
**When** the release job completes successfully
**Then** platform publish jobs run with max 2 concurrent
**And** each platform job publishes 2 packages (free + non-free)
**And** there is at least 5 seconds between publishes within a job

#### Scenario: Meta packages published after platform packages

**Given** all platform publish jobs have completed
**And** the dev publish job has completed
**When** the meta publish job runs
**Then** it publishes ffmpeg and ffmpeg-non-free packages
**And** both meta packages reference the correct version

#### Scenario: Rate limit errors trigger job retry

**Given** an npm publish receives E429 rate limit error
**When** the job fails
**Then** only the failed job retries (not all packages)
**And** other platform jobs continue independently
