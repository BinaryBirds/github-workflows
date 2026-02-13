#!/usr/bin/env bash
# Shell Script Format Check / Fix Script
#
# This script formats shell-related files with shfmt.
#
# Default behavior:
# - Runs shfmt in diff mode and fails when formatting drift is found.
#
# Optional behavior:
# - If --fix is passed, writes formatting changes in-place.

set -euo pipefail

log() { printf -- "** %s\n" "$*" >&2; }
error() { printf -- "** ERROR: %s\n" "$*" >&2; }
fatal() {
    error "$@"
    exit 1
}

usage() {
    cat >&2 <<USAGE
Usage: $0 [--fix]

Options:
  --fix    Apply formatting in-place
USAGE
}

FIX_MODE=0
for arg in "$@"; do
    case "$arg" in
        --fix)
            FIX_MODE=1
            ;;
        -h | --help)
            usage
            exit 0
            ;;
        *)
            fatal "Unknown argument: $arg"
            ;;
    esac
done

if ! command -v shfmt >/dev/null 2>&1; then
    fatal "shfmt is not installed. Install it first (e.g. 'brew install shfmt' or 'apt-get install shfmt')."
fi

FILES=()
while IFS= read -r -d '' file; do
    FILES+=("$file")
done < <(git ls-files -z '*.sh' '*.bash' '*.bats')

if [ "${#FILES[@]}" -eq 0 ]; then
    log "No shell files found to format."
    exit 0
fi

if [ "$FIX_MODE" -eq 1 ]; then
    shfmt -w -i 4 -ci "${FILES[@]}"
    log "✅ Applied shfmt formatting."
    exit 0
fi

set +e
shfmt -d -i 4 -ci "${FILES[@]}"
SHFMT_RC=$?
set -e

if [ "$SHFMT_RC" -ne 0 ]; then
    fatal "shfmt found formatting issues. Run with --fix to apply changes."
fi

log "✅ shfmt found no formatting issues."
