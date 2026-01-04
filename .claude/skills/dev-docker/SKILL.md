---
name: dev-docker
description: Refactor Dockerfiles following official Docker best practices without breaking builds. Use when asked to optimize, improve, refactor, or review Dockerfiles. Covers multi-stage builds, layer caching, security hardening, and instruction-specific patterns.
---

# Dockerfile Refactoring

Refactor Dockerfiles safely by applying these patterns incrementally. Test builds after each change.

## Pre-Refactor Checklist

1. Verify current Dockerfile builds: `docker build -t test:before .`
2. Note existing build time and image size
3. Check for `.dockerignore` file
4. Identify the base image and its update frequency

## Multi-Stage Builds

Split build dependencies from runtime. Only final stage artifacts ship.

```dockerfile
# Build stage
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production

# Runtime stage  
FROM node:20-alpine
WORKDIR /app
COPY --from=builder /app/node_modules ./node_modules
COPY . .
CMD ["node", "server.js"]
```

**Reusable stages**: If multiple images share setup, create a common base stage.

## Layer Cache Optimization

Order instructions from least to most frequently changing:

1. Base image and system packages (rarely change)
2. Language runtime dependencies (change occasionally)
3. Application dependencies (change with lock files)
4. Application code (changes most often)

**Critical**: Always combine `apt-get update && apt-get install` in one RUN:

```dockerfile
# WRONG - cache issues
RUN apt-get update
RUN apt-get install -y curl

# CORRECT
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    && rm -rf /var/lib/apt/lists/*
```

## Instruction Patterns

### FROM
- Use specific tags, not `latest`: `FROM python:3.12-slim`
- Pin digests for supply chain security: `FROM python:3.12-slim@sha256:abc123...`
- Prefer `-slim` or `-alpine` variants

### RUN
- Chain commands with `&&` to reduce layers
- Sort multi-line package lists alphabetically
- Use `--no-install-recommends` with apt-get
- Clean up in the same layer: `&& rm -rf /var/lib/apt/lists/*`
- Use heredocs for complex scripts:
```dockerfile
RUN <<EOF
set -e
apt-get update
apt-get install -y --no-install-recommends curl
rm -rf /var/lib/apt/lists/*
EOF
```

### COPY vs ADD
- Prefer `COPY` for local files
- Use `ADD` only for: remote URLs with checksums, or auto-extracting tarballs
- Use bind mounts for build-time-only files:
```dockerfile
RUN --mount=type=bind,source=requirements.txt,target=/tmp/requirements.txt \
    pip install -r /tmp/requirements.txt
```

### ENV
- Environment variables persist across layers; use single RUN for secrets:
```dockerfile
# WRONG - ADMIN_USER leaks to image
ENV ADMIN_USER=admin
RUN echo $ADMIN_USER > /config

# CORRECT - variable doesn't persist
RUN export ADMIN_USER=admin && echo $ADMIN_USER > /config
```

### USER
- Create non-root user early, switch late:
```dockerfile
RUN groupadd -r appuser && useradd --no-log-init -r -g appuser appuser
# ... install dependencies as root ...
USER appuser
CMD ["./app"]
```

### ENTRYPOINT + CMD
- `ENTRYPOINT` for the command, `CMD` for default arguments:
```dockerfile
ENTRYPOINT ["python"]
CMD ["--help"]
```

### WORKDIR
- Always use absolute paths
- Prefer `WORKDIR /app` over `RUN cd /app && ...`

### EXPOSE
- Document ports but don't assume they're published
- Use standard ports (80, 443, 8080, etc.)

## .dockerignore

Create if missing. Exclude:
```
.git
.gitignore
node_modules
__pycache__
*.pyc
.env
*.md
Dockerfile*
docker-compose*
.dockerignore
```

## Common Refactoring Transforms

| Before | After | Why |
|--------|-------|-----|
| `FROM ubuntu:latest` | `FROM ubuntu:24.04` | Reproducible builds |
| Multiple `RUN apt-get` | Single chained `RUN` | Fewer layers, cache efficiency |
| `COPY . .` early | `COPY . .` last | Better cache utilization |
| `ADD local.tar.gz /app` | `COPY local.tar.gz /app` + `RUN tar` | Explicit, debuggable |
| Root user throughout | `USER nonroot` at end | Security |
| No `.dockerignore` | Add `.dockerignore` | Smaller context, faster builds |

## Validation

After refactoring:
1. Build: `docker build -t test:after .`
2. Compare size: `docker images test`
3. Run tests: `docker run test:after <test-command>`
4. Check no secrets leaked: `docker history test:after`

## Safe Refactoring Order

1. Add `.dockerignore` (no build change)
2. Pin base image version (minimal risk)
3. Reorder COPY statements (cache optimization)
4. Combine RUN statements (reduce layers)
5. Add multi-stage build (larger change, test thoroughly)
6. Add non-root user (may need permission fixes)
