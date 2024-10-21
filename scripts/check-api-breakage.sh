#!/usr/bin/env bash
set -euo pipefail

log() { printf -- "** %s\n" "$*" >&2; }
error() { printf -- "** ERROR: %s\n" "$*" >&2; }
fatal() { error "$@"; exit 1; }

# Fetch all tags from the remote repository
git fetch -t

# Get the latest commit hash that has a tag
REV_LIST=$(git rev-list --tags --max-count=1)

# Check if REV_LIST is not empty
if [ -n "${REV_LIST}" ]; then
    # Get the latest tag associated with the commit hash
    LATEST_TAG=$(git describe --tags "${REV_LIST}")

    # Run the Swift package API breakage diagnosis tool and redirect output to a log file
    swift package diagnose-api-breaking-changes "$LATEST_TAG" cmd > api-breakage-output.log || {
        NUM=$(cmd api-breakage-output.log|grep -c)
        log "❌ Found ${NUM} API breakages."
        cat api-breakages.log
        exit 0
    }
    log "✅ Found no API breakages."
else
    log "✅ The repository has no tags yet."
fi