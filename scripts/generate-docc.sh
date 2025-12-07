#!/usr/bin/env bash
set -euo pipefail

log()   { printf -- "** %s\n" "$*" >&2; }
error() { printf -- "** ERROR: %s\n" "$*" >&2; }
fatal() { error "$@"; exit 1; }

OUTPUT_DIR="./docs"
TARGETS_FILE=".doccTargetList"
TARGETS=""
TARGET_FLAGS=()
COMBINED_FLAG=""
LOCAL_MODE=false

# Parse optional parameter: --local
if [[ "${1:-}" == "--local" ]]; then
    LOCAL_MODE=true
    log "DocC generation mode: local testing (no static hosting)"
else
    log "DocC generation mode: GitHub Pages"
fi

# If repo name argument is passed use it, otherwise detect via git
if [ -n "${1:-}" ]; then
    REPO_NAME="$1"
else
    # fallback to git detection
    REPO_ROOT="$(git rev-parse --show-toplevel)"
    REPO_NAME="$(basename "$REPO_ROOT")"
fi
log "Using repo name: $REPO_NAME"

# Load targets from .doccTargetList if present
load_from_config() {
    TARGETS=$(grep -v '^\s*$' "$TARGETS_FILE" || true)
    if [ -z "$TARGETS" ]; then
        fatal "$TARGETS_FILE exists but contains no valid targets."
    fi
    for TARGET in $TARGETS; do
        TARGET_FLAGS+=( --target "$TARGET" )
    done
}

# Auto-detect documentable Swift targets
auto_detect_targets() {
    if ! command -v jq >/dev/null 2>&1; then
        fatal "jq is required (install with: brew install jq)"
    fi
    TARGETS=$(swift package dump-package \
        | jq -r '.targets[]
            | select(.type == "regular" or .type == "executable")
            | .name')
    if [ -z "$TARGETS" ]; then
        fatal "No documentable targets found in Package.swift."
    fi
    for TARGET in $TARGETS; do
        TARGET_FLAGS+=( --target "$TARGET" )
    done
}

# Select target source
if [ -f "$TARGETS_FILE" ]; then
    log "Using targets from $TARGETS_FILE"
    load_from_config
else
    log "Auto-detecting Swift targets"
    auto_detect_targets
fi

# Count non-empty targets
TARGET_COUNT=$(printf "%s\n" "$TARGETS" | grep -c .)

log "Targets detected:"
printf "%s\n" "$TARGETS"
log "Target count: $TARGET_COUNT"

# Enable experimental combined docs when >1 target
if [ "$TARGET_COUNT" -gt 1 ]; then
    COMBINED_FLAG="--enable-experimental-combined-documentation"
    log "Combined documentation: enabled"
else
    COMBINED_FLAG=""
    log "Combined documentation: disabled"
fi

rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

# Generate documentation
echo
if $LOCAL_MODE; then
    swift package --allow-writing-to-directory "$OUTPUT_DIR" \
        generate-documentation \
        $COMBINED_FLAG \
        "${TARGET_FLAGS[@]}" \
        --output-path "$OUTPUT_DIR"

else
    swift package --allow-writing-to-directory "$OUTPUT_DIR" \
        generate-documentation \
        $COMBINED_FLAG \
        "${TARGET_FLAGS[@]}" \
        --output-path "$OUTPUT_DIR" \
        --transform-for-static-hosting \
        ${REPO_NAME:+--hosting-base-path "$REPO_NAME"}
fi