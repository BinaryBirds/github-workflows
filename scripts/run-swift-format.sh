#!/usr/bin/env bash
# Swift Format Check / Fix Script
#
# This script runs `swift-format` on all Swift source files in the repository.
#
# Default behavior:
# - Runs `swift format lint --strict`
# - Fails if formatting violations are found
#
# Optional behavior:
# - If `--fix` is passed, runs `swift format format --in-place`
#   to automatically fix formatting issues
#
# The script ensures that required configuration files
# (.swift-format and .swiftformatignore) are present by downloading
# them from the central workflow repository if missing.
#
# Intended usage:
# - CI: enforce consistent Swift formatting
# - Local: optionally auto-fix formatting before committing

set -euo pipefail

# Logging helpers
# All output is written to stderr for consistent CI and local logs
log() { printf -- "** %s\n" "$*" >&2; }
error() { printf -- "** ERROR: %s\n" "$*" >&2; }
fatal() {
    error "$@"
    exit 1
}

# Determine swift-format command mode
#
# By default, run in strict lint mode.
# If --fix is provided, switch to in-place formatting.
FORMAT_COMMAND=(lint --strict)
for arg in "$@"; do
    if [ "$arg" == "--fix" ]; then
        FORMAT_COMMAND=(format --in-place)
    fi
done

# Base URL for shared swift-format configuration files
URL="https://raw.githubusercontent.com/BinaryBirds/github-workflows/refs/heads/main"

# Ensure .swift-format configuration exists
#
# This file defines formatting rules used by swift-format.
# If missing, it is downloaded to keep formatting consistent
# across repositories.
if [ ! -f ".swift-format" ]; then
    log ".swift-format does not exist. Downloading..."
    curl -o ".swift-format" "$URL/.swift-format"
fi

# Ensure .swiftformatignore exists
#
# This file defines paths that should be excluded from formatting.
# If missing, it is downloaded from the shared configuration.
if [ ! -f ".swiftformatignore" ]; then
    log ".swiftformatignore does not exist. Downloading..."
    curl -o ".swiftformatignore" "$URL/.swiftformatignore"
fi

# Run swift-format
#
# - Uses git to list all tracked Swift files
# - Applies exclusions defined in .swiftformatignore
# - Runs formatting in parallel for performance
#
# The exit code is captured explicitly to allow controlled error handling.
tr '\n' '\0' <.swiftformatignore |
    xargs -0 -I% printf '":(exclude)%" ' |
    xargs git ls-files -z '*.swift' |
    xargs -0 swift format "${FORMAT_COMMAND[@]}" --parallel &&
    SWIFT_FORMAT_RC=$? || SWIFT_FORMAT_RC=$?

# If swift-format failed, print a helpful error message
if [ "${SWIFT_FORMAT_RC}" -ne 0 ]; then
    fatal "❌ Running swift-format produced errors.
  To fix:
    % run make format
  "
fi

# Success
log "✅ Ran swift-format with no errors."
