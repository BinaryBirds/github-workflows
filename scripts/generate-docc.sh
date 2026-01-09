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
REPO_NAME=""
SWIFTPM_PACKAGE_PATH=""

# ------------------------------------------------------------
# Argument parsing
# ------------------------------------------------------------
while [[ $# -gt 0 ]]; do
    case "$1" in
        --local)
            LOCAL_MODE=true
            shift
            ;;
        --name)
            if [[ -n "${2:-}" ]]; then
                REPO_NAME="$2"
                shift 2
            else
                fatal "--name flag requires a value but none was provided"
            fi
            ;;
        *)
            fatal "Unknown argument: $1"
            ;;
    esac
done

# ------------------------------------------------------------
# Git safety (local only)
# ------------------------------------------------------------
ensure_clean_git() {
    if [ -n "${GITHUB_ACTIONS:-}" ]; then
        return 0
    fi

    if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        if ! git diff --quiet || ! git diff --cached --quiet; then
            fatal "Working tree has uncommitted changes — please commit or stash before generating docs"
        fi
    fi
}

# ------------------------------------------------------------
# Ensure swift-docc-plugin (only if missing)
# ------------------------------------------------------------
ensure_docc_plugin() {
    local PACKAGE_FILE="Package.swift"

    if [ ! -f "$PACKAGE_FILE" ]; then
        fatal "Package.swift not found"
    fi

    if grep -q 'swift-docc-plugin' "$PACKAGE_FILE"; then
        log "swift-docc-plugin already present — using existing configuration"
        return 0
    fi

    log "swift-docc-plugin missing — injecting temporarily (from 1.4.0)"

    TMP_PACKAGE_DIR="$(mktemp -d)"
    TMP_PACKAGE_FILE="$TMP_PACKAGE_DIR/Package.swift"

    cp "$PACKAGE_FILE" "$TMP_PACKAGE_FILE"

    perl -0777 -i -pe '
        s|(dependencies:\s*\[)|$1\n        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.4.0"),|s
    ' "$TMP_PACKAGE_FILE"

    SWIFTPM_PACKAGE_PATH="$TMP_PACKAGE_DIR"
    export SWIFTPM_PACKAGE_PATH

    trap 'rm -rf "$TMP_PACKAGE_DIR"' EXIT
}

# ------------------------------------------------------------
# Reset git after docs (local only)
# ------------------------------------------------------------
reset_git_after_docs() {
    if [ -n "${GITHUB_ACTIONS:-}" ]; then
        return 0
    fi

    if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        log "Resetting local git working tree"
        git reset --hard
    fi
}

# ------------------------------------------------------------
# Repo name detection
# ------------------------------------------------------------
if [[ -z "$REPO_NAME" ]]; then
    if git rev-parse --show-toplevel >/dev/null 2>&1; then
        REPO_ROOT="$(git rev-parse --show-toplevel)"
        REPO_NAME="$(basename "$REPO_ROOT")"
    fi
fi

if $LOCAL_MODE; then
    log "DocC generation mode: local testing (no static hosting)"
else
    log "DocC generation mode: GitHub Pages"
fi

log "Repo name value: '${REPO_NAME}' (empty means no hosting-base-path)"

# ------------------------------------------------------------
# Pre-flight checks
# ------------------------------------------------------------
ensure_clean_git
ensure_docc_plugin

# ------------------------------------------------------------
# Load targets from .doccTargetList if present
# ------------------------------------------------------------
load_from_config() {
    TARGETS=$(grep -v '^\s*$' "$TARGETS_FILE" || true)
    if [ -z "$TARGETS" ]; then
        fatal "$TARGETS_FILE exists but contains no valid targets."
    fi
    for TARGET in $TARGETS; do
        TARGET_FLAGS+=( --target "$TARGET" )
    done
}

# ------------------------------------------------------------
# Auto-detect Swift targets
# ------------------------------------------------------------
auto_detect_targets() {
    if ! command -v jq >/dev/null 2>&1; then
        fatal "jq is required (install with: brew install jq)"
    fi

    TARGETS=$(swift package \
        ${SWIFTPM_PACKAGE_PATH:+--package-path "$SWIFTPM_PACKAGE_PATH"} \
        dump-package \
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

# ------------------------------------------------------------
# Target selection
# ------------------------------------------------------------
if [ -f "$TARGETS_FILE" ]; then
    log "Using targets from $TARGETS_FILE"
    load_from_config
else
    log "Auto-detecting Swift targets"
    auto_detect_targets
fi

TARGET_COUNT=$(printf "%s\n" "$TARGETS" | grep -c .)

log "Targets detected:"
printf "%s\n" "$TARGETS"
log "Target count: $TARGET_COUNT"

# ------------------------------------------------------------
# Combined docs flag
# ------------------------------------------------------------
if [ "$TARGET_COUNT" -gt 1 ]; then
    COMBINED_FLAG="--enable-experimental-combined-documentation"
    log "Combined documentation: enabled"
else
    COMBINED_FLAG=""
    log "Combined documentation: disabled"
fi

# ------------------------------------------------------------
# Generate documentation
# ------------------------------------------------------------
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

DOCS_EXIT_CODE=0
echo

if $LOCAL_MODE; then
    swift package \
        ${SWIFTPM_PACKAGE_PATH:+--package-path "$SWIFTPM_PACKAGE_PATH"} \
        --allow-writing-to-directory "$OUTPUT_DIR" \
        generate-documentation \
        $COMBINED_FLAG \
        "${TARGET_FLAGS[@]}" \
        --output-path "$OUTPUT_DIR" \
        || DOCS_EXIT_CODE=$?
else
    swift package \
        ${SWIFTPM_PACKAGE_PATH:+--package-path "$SWIFTPM_PACKAGE_PATH"} \
        --allow-writing-to-directory "$OUTPUT_DIR" \
        generate-documentation \
        $COMBINED_FLAG \
        "${TARGET_FLAGS[@]}" \
        --output-path "$OUTPUT_DIR" \
        --transform-for-static-hosting \
        ${REPO_NAME:+--hosting-base-path "$REPO_NAME"} \
        || DOCS_EXIT_CODE=$?
fi

if [ "$DOCS_EXIT_CODE" -ne 0 ]; then
    log "WARNING: Documentation generation failed (exit code $DOCS_EXIT_CODE)"
fi

reset_git_after_docs
exit $DOCS_EXIT_CODE