#!/usr/bin/env bash
set -euo pipefail

log() { printf -- "** %s\n" "$*" >&2; }
error() { printf -- "** ERROR: %s\n" "$*" >&2; }
fatal() { error "$@"; exit 1; }

REPO_ROOT="$(git -C "$PWD" rev-parse --show-toplevel)"

# Read paths to check from git, ensuring paths are properly handled as array
read -ra PATHS_TO_CHECK <<< "$( \
    git -C "${REPO_ROOT}" ls-files -z \
    "Package.swift" \
    | xargs -0 \
)"
# Check if the PATHS_TO_CHECK array is not empty
if [ ! -z ${PATHS_TO_CHECK+x} ]; then
    for FILE_PATH in "${PATHS_TO_CHECK[@]}"; do
        # Check if the file contains local Swift package references
        if [[ $(grep ".package(path:" "${FILE_PATH}"|wc -l) -ne 0 ]] ; then
            fatal "❌ The '${FILE_PATH}' file contains local Swift package reference(s)."
        fi
    done
fi
log "✅ Found 0 local Swift package dependency references."