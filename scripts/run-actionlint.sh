#!/usr/bin/env bash
# GitHub Actions Workflow Lint Script
#
# Runs actionlint against repository workflows.

set -euo pipefail

log()   { printf -- "** %s\n" "$*" >&2; }
error() { printf -- "** ERROR: %s\n" "$*" >&2; }
fatal() { error "$@"; exit 1; }

if ! command -v actionlint >/dev/null 2>&1; then
  fatal "actionlint is not installed. Install it first (e.g. 'brew install actionlint' or 'apt-get install actionlint')."
fi

REPO_ROOT="$(git -C "$PWD" rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$REPO_ROOT"

log "Running actionlint..."
actionlint "$@"
log "✅ actionlint found no issues."
