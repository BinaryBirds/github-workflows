#!/usr/bin/env bash
# Local Swift Package Dependency Check
#
# This script ensures that a Swift package does NOT reference
# local Swift package dependencies (e.g. `.package(path: ...)`).
#
# Local package references are problematic because:
# - They break CI and clean builds
# - They are not portable across machines
# - They should never be committed to shared repositories
#
# Intended usage:
# - CI: fail fast if local dependencies are detected
# - Local: allow developers to verify their Package.swift before pushing
#
# The script checks ONLY tracked files to avoid false positives from
# uncommitted or generated files.

set -euo pipefail

# Logging helpers
#
# All output goes to stderr to keep stdout clean and CI-friendly.
log()   { printf -- "** %s\n" "$*" >&2; }
error() { printf -- "** ERROR: %s\n" "$*" >&2; }
fatal() { error "$@"; exit 1; }

# Determine repository root
#
# Ensures the script always runs against the top-level git repository,
# even if invoked from a subdirectory.
REPO_ROOT="$(git -C "$PWD" rev-parse --show-toplevel)"

# Collect files to check
#
# We intentionally use `git ls-files` to:
# - Inspect only tracked files
# - Avoid scanning generated or uncommitted files
#
# Currently, we only check Package.swift, since local package references
# are only valid in that file.
read -ra PATHS_TO_CHECK <<< "$(
    git -C "${REPO_ROOT}" ls-files -z \
        "Package.swift" \
    | xargs -0
)"

# Scan files for local Swift package references
#
# We look specifically for `.package(path: ...)`, which indicates
# a local dependency that should not be committed.
if [ -n "${PATHS_TO_CHECK+x}" ]; then
    for FILE_PATH in "${PATHS_TO_CHECK[@]}"; do
        if grep -q ".package(path:" "${FILE_PATH}"; then
            fatal "❌ The '${FILE_PATH}' file contains local Swift package reference(s)."
        fi
    done
fi

# Success
log "✅ Found 0 local Swift package dependency references."