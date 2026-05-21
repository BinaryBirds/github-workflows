#!/usr/bin/env bash
# GitHub Actions Workflow Lint Script
#
# Runs actionlint against repository workflows.

set -euo pipefail

log() { printf -- "** %s\n" "$*" >&2; }
error() { printf -- "** ERROR: %s\n" "$*" >&2; }
fatal() {
    error "$@"
    exit 1
}

REPO_ROOT="$(git -C "$PWD" rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$REPO_ROOT"

log "Running actionlint..."

if ! command -v actionlint >/dev/null 2>&1; then
    fatal "actionlint is not installed. Install it first (e.g. 'brew install actionlint' or 'apt-get install actionlint')."
fi

set +e
LOCAL_OUTPUT="$(actionlint "$@" 2>&1)"
LOCAL_RC=$?
set -e

if [ "$LOCAL_RC" -ne 0 ] && printf '%s' "$LOCAL_OUTPUT" | grep -q 'label ".*" is unknown'; then
    error "Your installed actionlint is likely outdated and does not recognize newer runner labels."
    error "Please upgrade actionlint and run this script again."
fi

[ -n "$LOCAL_OUTPUT" ] && printf '%s\n' "$LOCAL_OUTPUT"
[ "$LOCAL_RC" -ne 0 ] && exit "$LOCAL_RC"

log "✅ actionlint found no issues."
