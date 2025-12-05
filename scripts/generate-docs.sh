#!/bin/bash
set -e

OUTPUT_DIR="./docs"
CONFIG_FILE=".doccTargetList"
TARGET_FLAGS=""
COMBINED_FLAG=""
TARGETS=""

# Detect repo name (for hosting-base-path)
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    REPO_NAME=$(basename "$(git rev-parse --show-toplevel)")
else
    REPO_NAME=""
fi

# Read targets from .doccTargetList
read_targets_from_config() {
    TARGETS=$(grep -v '^\s*$' "$CONFIG_FILE")
    if [ -z "$TARGETS" ]; then
        echo "Error: $CONFIG_FILE exists but contains no valid targets."
        exit 1
    fi

    for TARGET in $TARGETS; do
        TARGET_FLAGS="$TARGET_FLAGS --target $TARGET"
    done
}

# Auto-detect documentable Swift targets
auto_detect_targets() {
    if ! command -v jq >/dev/null 2>&1; then
        echo "Error: jq is required. Install with: brew install jq"
        exit 1
    fi

    TARGETS=$(swift package dump-package \
        | jq -r '.targets[]
                 | select(.type == "regular" or .type == "executable")
                 | .name')

    if [ -z "$TARGETS" ]; then
        echo "Error: No documentable targets found."
        exit 1
    fi

    for TARGET in $TARGETS; do
        TARGET_FLAGS="$TARGET_FLAGS --target $TARGET"
    done
}

# Select target list
if [ -f "$CONFIG_FILE" ]; then
    read_targets_from_config
else
    auto_detect_targets
fi

# Count real targets
TARGET_COUNT=$(printf "%s\n" "$TARGETS" | grep -c .)

# Enable combined documentation if needed
if [ "$TARGET_COUNT" -gt 1 ]; then
    COMBINED_FLAG="--enable-experimental-combined-documentation"
fi

# Clean docs directory
if [ -d "$OUTPUT_DIR" ]; then
    rm -rf "$OUTPUT_DIR"
fi

mkdir -p "$OUTPUT_DIR"

# Build documentation
swift package \
  generate-documentation \
  --allow-writing-to-directory "$OUTPUT_DIR" \
  --output-path "$OUTPUT_DIR" \
  --transform-for-static-hosting \
  ${REPO_NAME:+--hosting-base-path "$REPO_NAME"} \
  $COMBINED_FLAG \
  $TARGET_FLAGS

echo "Documentation generated in $OUTPUT_DIR"