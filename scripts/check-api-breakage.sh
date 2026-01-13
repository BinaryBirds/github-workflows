#!/usr/bin/env bash
# API Breaking Changes Check
#
# This script checks whether the current Swift package introduces
# API-breaking changes compared to a baseline.
#
# Baseline selection logic:
# - In GitHub Actions PRs: uses the PR base branch
# - Otherwise: uses the latest git tag
#
# If no tags exist at all, the check is skipped with a warning.

set -euo pipefail

# Logging helpers
log()   { printf -- "** %s\n" "$*" >&2; }
error() { printf -- "** ERROR: %s\n" "$*" >&2; }
fatal() { error "$@"; exit 1; }

# Determine baseline reference
if [ -n "${GITHUB_BASE_REF:-}" ] && [ -n "${GITHUB_REPOSITORY:-}" ] && [ -n "${GITHUB_SERVER_URL:-}" ]; then
    log "Running in PR context — using base branch: ${GITHUB_BASE_REF}"

    git fetch "${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}" \
        "${GITHUB_BASE_REF}:pull-base-ref"

    BASELINE_REF="pull-base-ref"
else
    log "No PR context detected — checking for existing tags"

    git fetch --tags

    if ! git tag | grep -q .; then
        log "⚠️ No git tags found — skipping API breakage check"
        exit 0
    fi

    BASELINE_REF=$(git describe --tags --abbrev=0)
fi

log "Using baseline: ${BASELINE_REF}"

# Run SwiftPM API breakage diagnosis
#
# This command exits non-zero if API-breaking changes are detected.
swift package diagnose-api-breaking-changes "$BASELINE_REF"

log "✅ No API-breaking changes detected."