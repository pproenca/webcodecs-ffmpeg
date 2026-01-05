#!/usr/bin/env bash
# musl-specific configuration
# Alpine base, fully static, no network

# Base image
ALPINE_VERSION="${ALPINE_VERSION:-3.21}"
BASE_IMAGE="alpine:${ALPINE_VERSION}"

# Features
ENABLE_OPENSSL=0
ENABLE_NETWORK=0
