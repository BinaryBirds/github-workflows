#!/usr/bin/env bash
# Broken Symlink Check
#
# This script scans the repository for broken symbolic links.
#
# A broken symlink is a symbolic link whose target file or directory
# no longer exists. Such links can cause build failures, tooling issues,
# or confusing behavior for developers.
#
# Intended usage:
# - CI: fail if broken symlinks are present in the repository
# - Local: verify repository integrity before committing or releasing
#
# Only files tracked by git are checked to ensure deterministic behavior.

set -euo pipefail

# Logging helpers
# All output is written to stderr for consistent CI and local logs
log()   { printf -- "** %s\n" "$*" >&2; }
error() { printf -- "** ERROR: %s\n" "$*" >&2; }
fatal() { error "$@"; exit 1; }

# Resolve the repository root
# Ensures correct path resolution even if the script is run from a subdirectory
REPO_ROOT="$(git -C "$PWD" rev-parse --show-toplevel)"

log "Checking for broken symlinks..."
NUM_BROKEN_SYMLINKS=0

# Iterate over all files tracked by git
#
# Using `git ls-files` ensures:
# - Only committed files are checked
# - Generated or untracked files are ignored
while read -r -d '' file; do
    # Check whether the symlink target exists
    #
    # `test -e` follows the symlink and verifies that the target
    # file or directory is present.
    if ! test -e "${REPO_ROOT}/${file}"; then
        log "Broken symlink: ${file}"
        ((NUM_BROKEN_SYMLINKS++))
    fi
done < <(git -C "${REPO_ROOT}" ls-files -z)

# If any broken symlinks were found, fail the script
if [ "${NUM_BROKEN_SYMLINKS}" -gt 0 ]; then
    log "❌ Found ${NUM_BROKEN_SYMLINKS} broken symlinks."
    exit 1
fi

# Success
log "✅ Found 0 broken symlinks."