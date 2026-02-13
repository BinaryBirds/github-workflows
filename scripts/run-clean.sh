#!/usr/bin/env bash
# Project Cleanup Script
#
# This script removes generated, cached, or temporary files from the repository
# to restore a clean working state.
#
# It is intentionally destructive and should only be run when:
# - You want a fresh build environment
# - You need to reset generated artifacts
# - You are preparing for a clean CI run
#
# Intended usage:
# - Local development cleanup
# - CI setup or teardown steps

set -euo pipefail

# Logging helpers
# All output is written to stderr for consistent logs
log() { printf -- "** %s\n" "$*" >&2; }
error() { printf -- "** ERROR: %s\n" "$*" >&2; }
fatal() {
    error "$@"
    exit 1
}

# Remove files and directories
rm -rf ".build"
rm -rf ".swiftpm"
rm -f "openapi/openapi.yaml"
rm -f "db.sqlite"
rm -f "migration-entries.json"
