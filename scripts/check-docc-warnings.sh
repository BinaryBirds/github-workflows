#!/usr/bin/env bash
set -euo pipefail

log()   { printf -- "** %s\n" "$*" >&2; }
error() { printf -- "** ERROR: %s\n" "$*" >&2; }
fatal() { error "$@"; exit 1; }

REPO_ROOT="$(git -C "$PWD" rev-parse --show-toplevel)"
TARGETS=""
TARGET_LIST=()

# Auto-detect documentable Swift targets
log "Detecting Swift targets for DocC analysis…"

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

# Convert to array
while IFS= read -r TARGET; do
    TARGET_LIST+=("$TARGET")
done <<< "$TARGETS"

TARGET_COUNT="${#TARGET_LIST[@]}"

log "Found targets:"
printf "%s\n" "${TARGET_LIST[@]}"
log "Target count: $TARGET_COUNT"

# Run DocC analysis (per target)
echo
TOTAL_RC=0
for TARGET in "${TARGET_LIST[@]}"; do
    set +e
    swift package \
        --package-path "$REPO_ROOT" \
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
    fatal "Documentation analysis failed."
fi

log "All targets passed DocC analysis without warnings."