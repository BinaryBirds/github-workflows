#!/usr/bin/env bash
set -euo pipefail

log() { printf -- "** %s\n" "$*" >&2; }
error() { printf -- "** ERROR: %s\n" "$*" >&2; }
fatal() { error "$@"; exit 1; }

REPO_ROOT="$(git -C "$PWD" rev-parse --show-toplevel)"

log "Checking for broken symlinks..."
NUM_BROKEN_SYMLINKS=0

# Loop through each file listed by git
while read -r -d '' file; do
    # Check if the symlink is broken (i.e., target does not exist)
    if ! test -e "${REPO_ROOT}/${file}"; then
        log "Broken symlink: ${file}"
        ((NUM_BROKEN_SYMLINKS++))
    fi
done < <(git -C "${REPO_ROOT}" ls-files -z)

# Check if any broken symlinks were found
if [ "${NUM_BROKEN_SYMLINKS}" -gt 0 ]; then
    log "❌ Found ${NUM_BROKEN_SYMLINKS} broken symlinks."
    exit 1
fi

log "✅ Found 0 broken symlinks."
