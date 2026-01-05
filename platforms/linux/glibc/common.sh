#!/usr/bin/env bash
# glibc-specific configuration
# Ubuntu base, OpenSSL enabled for network protocols

# Base image
UBUNTU_VERSION="${UBUNTU_VERSION:-24.04}"
BASE_IMAGE="ubuntu:${UBUNTU_VERSION}"

# Features
ENABLE_OPENSSL=1
ENABLE_NETWORK=1
