#!/bin/bash
set -e

OUTPUT_DIR="./docs"
CONFIG_FILE=".doccTargetList"
TARGET_FLAGS=""
TARGETS=""
COMBINED_FLAG=""

# Detect hosting base path (repo name)
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    REPO_NAME=$(basename "$(git rev-parse --show-toplevel)")
else
    REPO_NAME=""
fi

# Load targets from .doccTargetList if exists
load_from_config() {
    TARGETS=$(grep -v '^\s*$' "$CONFIG_FILE")
    if [ -z "$TARGETS" ]; then
        echo "Error: $CONFIG_FILE exists but contains no valid targets."
        exit 1
    fi

    for TARGET in $TARGETS; do
        TARGET_FLAGS="$TARGET_FLAGS --target $TARGET"
    done
}

# Auto-detect valid Swift targets
auto_detect_targets() {
    if ! command -v jq >/dev/null 2>&1; then
        echo "Error: jq required (install via: brew install jq)"
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

# Determine target list source
if [ -f "$CONFIG_FILE" ]; then
    load_from_config
else
    auto_detect_targets
fi

# Count real targets
TARGET_COUNT=$(printf "%s\n" "$TARGETS" | grep -c .)

# Log targets
echo "Detected documentation targets:"
printf "%s\n" "$TARGETS"

# Determine if combined docs is needed
if [ "$TARGET_COUNT" -gt 1 ]; then
    COMBINED_FLAG="--enable-experimental-combined-documentation"
    echo "Combined documentation: ENABLED"
else
    COMBINED_FLAG=""
    echo "Combined documentation: disabled"
fi

echo

# Prepare output directory
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

# Generate DocC documentation
swift package \
  generate-documentation \
  --allow-writing-to-directory "$OUTPUT_DIR" \
  $COMBINED_FLAG \
  $TARGET_FLAGS \
  --output-path "$OUTPUT_DIR" \
  --transform-for-static-hosting \
  ${REPO_NAME:+--hosting-base-path "$REPO_NAME"}

echo "Documentation generated in $OUTPUT_DIR"