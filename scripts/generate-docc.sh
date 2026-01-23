#!/usr/bin/env bash
# DocC Documentation Generation Script
#
# This script generates DocC documentation for a Swift package.
#
# Features:
# - Supports explicit target selection via .docctargetlist
# - Falls back to auto-detecting documentable Swift targets
# - Injects swift-docc-plugin temporarily if missing
# - Supports local preview mode and GitHub Pages static hosting
# - Enforces a clean git working tree for local runs
#
# Intended usage:
# - CI: generate documentation for publishing or validation
# - Local: preview documentation output safely

set -euo pipefail

# Logging helpers
# All output is written to stderr for consistent CI and local logs
log()   { printf -- "** %s\n" "$*" >&2; }
error() { printf -- "** ERROR: %s\n" "$*" >&2; }
fatal() { error "$@"; exit 1; }

# Configuration / state
OUTPUT_DIR="./docs"            # Output directory for generated documentation
TARGETS_FILE=".docctargetlist" # Optional file listing explicit DocC targets
TARGETS=""                     # Raw newline-separated target names
TARGET_FLAGS=()                # --target flags passed to SwiftPM
COMBINED_FLAG=""               # Experimental combined documentation flag
LOCAL_MODE=false               # Local preview vs static hosting mode
REPO_NAME=""                   # Hosting base path (for GitHub Pages)

# Argument parsing
#
# --local        Generate docs for local preview (no static hosting transform)
# --name NAME    Override repository name used for hosting base path
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

# Git safety (local runs only)
#
# Prevents accidental loss of local changes when the script temporarily
# modifies Package.swift.
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

# Ensure swift-docc-plugin is available
SCRIPT_DIR="$(pwd)"
source "$SCRIPT_DIR/lib/ensure-docc-plugin.sh"

# Restore git state after documentation generation (local only)
#
# Ensures the repository is returned to a clean state after execution.
reset_git_after_docs() {
    if [ -n "${GITHUB_ACTIONS:-}" ]; then
        return 0
    fi

    if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        log "Resetting local git working tree"
        git reset --hard
    fi
}

# Determine repository name
#
# Used as the hosting base path when generating documentation for
# static hosting (e.g. GitHub Pages).
if [[ -z "$REPO_NAME" ]]; then
    if git rev-parse --show-toplevel >/dev/null 2>&1; then
        REPO_ROOT="$(git rev-parse --show-toplevel)"
        REPO_NAME="$(basename "$REPO_ROOT")"
    fi
fi

# Log generation mode
if $LOCAL_MODE; then
    log "DocC generation mode: local testing (no static hosting)"
else
    log "DocC generation mode: GitHub Pages"
fi

log "Repo name value: '${REPO_NAME}' (empty means no hosting-base-path)"

# Pre-flight checks
ensure_clean_git
ensure_docc_plugin

# Validate Package.swift after mutation
swift package dump-package >/dev/null \
  || fatal "Package.swift became invalid after injecting swift-docc-plugin"

# Load targets from .docctargetlist
#
# If present, this file defines the authoritative list of DocC targets.
# Empty lines are ignored.
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
#
# Uses SwiftPM package introspection to find regular and executable targets.
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

# Generate GitHub Pages redirects for DocC output
#
# Pages source = /docs
# DocC generated with --hosting-base-path "$REPO_NAME"
generate_pages_redirects() {
    local DOC_ROOT="$OUTPUT_DIR/documentation"

    if [ -z "$REPO_NAME" ]; then
        fatal "REPO_NAME must be set for GitHub Pages redirects"
    fi

    local BASE_PATH="/$REPO_NAME"

    log "Generating GitHub Pages redirects (base path: $BASE_PATH)"

    # Prevent Jekyll interference
    touch "$OUTPUT_DIR/.nojekyll"

    # ------------------------------------------------------------
    # 1. Site root redirect → /documentation/
    # ------------------------------------------------------------
    cat > "$OUTPUT_DIR/index.html" <<EOF
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="utf-8" />
        <title>Documentation</title>
        <meta http-equiv="refresh" content="0; url=$BASE_PATH/documentation/" />
        <script>
        location.replace("$BASE_PATH/documentation/");
        </script>
    </head>
    </html>
EOF

    # ------------------------------------------------------------
    # 2. If documentation/index.html exists → multi-target
    # ------------------------------------------------------------
    if [ -f "$DOC_ROOT/index.html" ]; then
        log "Multi-target DocC detected — using DocC landing page"
        return 0
    fi

    # ------------------------------------------------------------
    # 3. Single-target → redirect /documentation/ → /documentation/<Target>/
    # ------------------------------------------------------------
    local TARGET
    TARGET=$(ls -d "$DOC_ROOT"/*/ 2>/dev/null | head -n 1 | xargs basename)

    if [ -z "$TARGET" ]; then
        fatal "Unable to determine single DocC target"
    fi

    cat > "$DOC_ROOT/index.html" <<EOF
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="utf-8" />
        <title>Documentation</title>
        <meta http-equiv="refresh" content="0; url=$BASE_PATH/documentation/$TARGET/" />
        <script>
        location.replace("$BASE_PATH/documentation/$TARGET/");
        </script>
    </head>
    </html>
EOF

    log "Single-target redirect generated → $BASE_PATH/documentation/$TARGET/"
}

# Target selection
#
# Prefer .docctargetlist if present, otherwise fall back to auto-detection.
if [ -f "$TARGETS_FILE" ]; then
    log "Using targets from $TARGETS_FILE"
    load_from_config
else
    log "Auto-detecting Swift targets"
    auto_detect_targets
fi

TARGET_COUNT=$(printf "%s\n" "$TARGETS" | grep -c .)

log "Targets detected: $TARGET_COUNT"

# Combined documentation flag
#
# Enables experimental combined documentation when multiple targets exist.
if [ "$TARGET_COUNT" -gt 1 ]; then
    COMBINED_FLAG="--enable-experimental-combined-documentation"
    log "Combined documentation: enabled"
else
    COMBINED_FLAG=""
    log "Combined documentation: disabled"
fi

# Generate documentation
#
# Documentation is generated into the OUTPUT_DIR directory.
# Behavior differs slightly between local preview and static hosting modes.
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

DOCS_EXIT_CODE=0
echo

if $LOCAL_MODE; then
    swift package \
        --allow-writing-to-directory "$OUTPUT_DIR" \
        generate-documentation \
        $COMBINED_FLAG \
        "${TARGET_FLAGS[@]}" \
        --output-path "$OUTPUT_DIR" \
        || DOCS_EXIT_CODE=$?
else
    swift package \
        --allow-writing-to-directory "$OUTPUT_DIR" \
        generate-documentation \
        $COMBINED_FLAG \
        "${TARGET_FLAGS[@]}" \
        --output-path "$OUTPUT_DIR" \
        --transform-for-static-hosting \
        ${REPO_NAME:+--hosting-base-path "$REPO_NAME"} \
        || DOCS_EXIT_CODE=$?
fi

# Report failure without hiding the exit code
if [ "$DOCS_EXIT_CODE" -ne 0 ]; then
    log "WARNING: Documentation generation failed (exit code $DOCS_EXIT_CODE)"
fi

if ! $LOCAL_MODE && [ "$DOCS_EXIT_CODE" -eq 0 ]; then
    generate_pages_redirects
fi

# Cleanup and exit
reset_git_after_docs
exit $DOCS_EXIT_CODE