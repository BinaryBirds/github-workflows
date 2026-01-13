#!/usr/bin/env bash
# DocC Warnings / Analysis Script
#
# This script runs DocC documentation analysis for Swift package targets and
# fails if any warnings or errors are produced.
#
# Key characteristics:
# - Supports an explicit target list via .doccTargetList
# - Falls back to auto-detecting documentable targets from Package.swift
# - Ensures swift-docc-plugin is available (injects temporarily if missing)
# - Enforces a clean git working tree for local runs
# - Aggregates results across all targets
#
# Intended usage:
# - CI: validate documentation quality and fail on warnings
# - Local: run the same checks developers see in CI
#
# This script follows the same mental model as Swift's upstream `check-docs.sh`.

set -euo pipefail

# Logging helpers
#
# All logs go to stderr to keep stdout clean and CI-friendly.
log()   { printf -- "** %s\n" "$*" >&2; }
error() { printf -- "** ERROR: %s\n" "$*" >&2; }
fatal() { error "$@"; exit 1; }

# Configuration / state
TARGETS_FILE=".doccTargetList"   # Optional file listing explicit DocC targets
TARGETS=""                       # Raw newline-separated target names
TARGET_LIST=()                   # Target names as an array


# Git safety (local runs only)
#
# To avoid accidentally discarding local changes, this script refuses to run
# if the working tree is dirty when NOT running in GitHub Actions.
ensure_clean_git() {
    if [ -n "${GITHUB_ACTIONS:-}" ]; then
        return 0
    fi

    if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        if ! git diff --quiet || ! git diff --cached --quiet; then
            fatal "Working tree has uncommitted changes — please commit or stash before running DocC analysis"
        fi
    fi
}

# Ensure swift-docc-plugin is available
#
# DocC analysis requires the swift-docc-plugin dependency.
# If it is missing, we inject it temporarily into Package.swift.
#
# This mirrors the behavior of Swift's upstream documentation workflows.
ensure_docc_plugin() {
    local PACKAGE_FILE="Package.swift"

    if [ ! -f "$PACKAGE_FILE" ]; then
        fatal "Package.swift not found"
    fi

    if grep -q 'swift-docc-plugin' "$PACKAGE_FILE"; then
        log "swift-docc-plugin already present — using existing configuration"
        return 0
    fi

    log "swift-docc-plugin missing — injecting temporarily (from 1.4.0)"

    perl -0777 -i -pe '
        s|(dependencies:\s*\[)|$1\n        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.4.0"),|s
    ' "$PACKAGE_FILE"
}

# Reset git state after analysis (local only)
#
# Local runs restore the repository to a clean state after completion.
# This is skipped in CI environments.
reset_git_after_analysis() {
    if [ -n "${GITHUB_ACTIONS:-}" ]; then
        return 0
    fi

    if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        log "Resetting local git working tree"
        git reset --hard
    fi
}


# Pre-flight checks

ensure_clean_git
ensure_docc_plugin

# Load targets from .doccTargetList
#
# If the file exists, it is treated as the authoritative list of DocC targets.
# Empty lines are ignored.
load_from_config() {
    TARGETS=$(grep -v '^\s*$' "$TARGETS_FILE" || true)
    if [ -z "$TARGETS" ]; then
        fatal "$TARGETS_FILE exists but contains no valid targets."
    fi
}

# Auto-detect documentable Swift targets
#
# Falls back to SwiftPM package introspection when no explicit target list
# is provided.
auto_detect_targets() {
    if ! command -v jq >/dev/null 2>&1; then
        fatal "jq is required. Install with: brew install jq"
    fi

    TARGETS=$(swift package dump-package \
        | jq -r '.targets[]
            | select(.type == "regular" or .type == "executable")
            | .name')

    if [ -z "$TARGETS" ]; then
        fatal "No documentable targets found in Package.swift"
    fi
}

# Target selection
log "Detecting Swift targets for DocC analysis…"

if [ -f "$TARGETS_FILE" ]; then
    log "Using targets from $TARGETS_FILE"
    load_from_config
else
    log "Auto-detecting Swift targets"
    auto_detect_targets
fi

# Convert newline-separated target list into an array
while IFS= read -r TARGET; do
    TARGET_LIST+=("$TARGET")
done <<< "$TARGETS"

TARGET_COUNT="${#TARGET_LIST[@]}"

log "Found targets:"
printf "%s\n" "${TARGET_LIST[@]}"
log "Target count: $TARGET_COUNT"

# Run DocC analysis
#
# Each target is analyzed independently.
# Failures are collected and reported at the end instead of exiting early.
echo
TOTAL_RC=0

for TARGET in "${TARGET_LIST[@]}"; do
    set +e
    swift package \
        plugin \
        generate-documentation \
        --target "$TARGET" \
        --analyze \
        --warnings-as-errors
    RC=$?
    set -e

    if [ "$RC" -ne 0 ]; then
        error "DocC analysis failed for target '$TARGET'"
        TOTAL_RC=$RC
    fi
done

# Final result
if [ "$TOTAL_RC" -ne 0 ]; then
    log "WARNING: One or more DocC analysis runs failed"
    reset_git_after_analysis
    exit "$TOTAL_RC"
fi

log "All targets passed DocC analysis without warnings."

reset_git_after_analysis