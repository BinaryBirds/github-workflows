#!/bin/bash
set -e

OUTPUT_DIR="./docs"
CONFIG_FILE=".doccTargetList"
TARGET_FLAGS=""
COMBINED_FLAG=""

# --------------------------------------------
#  Detect repo name (for hosting-base-path)
# --------------------------------------------
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    REPO_NAME=$(basename "$(git rev-parse --show-toplevel)")
else
    REPO_NAME=""
fi

# --------------------------------------------
#  Function: Read targets from .doccTargetList
# --------------------------------------------
read_targets_from_config() {
    echo "📄 Using targets from $CONFIG_FILE"

    TARGETS=$(grep -v '^\s*$' "$CONFIG_FILE")
    if [ -z "$TARGETS" ]; then
        echo "❌ Error: $CONFIG_FILE exists but contains no valid targets."
        exit 1
    fi

    for TARGET in $TARGETS; do
        TARGET_FLAGS="$TARGET_FLAGS --target $TARGET"
    done

    TARGET_COUNT=$(echo "$TARGETS" | wc -l | tr -d ' ')
}

# --------------------------------------------
#  Function: Auto-detect documentable targets
# --------------------------------------------
auto_detect_targets() {
    echo "🔍 Auto-detecting Swift targets..."

    if ! command -v jq >/dev/null 2>&1; then
        echo "❌ jq is required. Install with: brew install jq"
        exit 1
    fi

    TARGETS=$(swift package dump-package \
        | jq -r '.targets[]
                 | select(.type == "regular" or .type == "executable")
                 | .name')

    if [ -z "$TARGETS" ]; then
        echo "❌ Error: no valid targets found."
        exit 1
    fi

    for TARGET in $TARGETS; do
        TARGET_FLAGS="$TARGET_FLAGS --target $TARGET"
    done

    TARGET_COUNT=$(echo "$TARGETS" | wc -l | tr -d ' ')
}

# --------------------------------------------
#  Decide: config file OR auto detection
# --------------------------------------------
if [ -f "$CONFIG_FILE" ]; then
    read_targets_from_config
else
    auto_detect_targets
fi

echo "📦 Targets selected:"
echo "$TARGETS"
echo "➡️ Count: $TARGET_COUNT"
echo

# --------------------------------------------
#  Add combined docs flag if multiple targets
# --------------------------------------------
if [ "$TARGET_COUNT" -gt 1 ]; then
    COMBINED_FLAG="--enable-experimental-combined-documentation"
    echo "🔗 Multi-target detected → enabling combined documentation"
else
    COMBINED_FLAG=""
    echo "🔹 Single target → combined documentation disabled"
fi

echo

# --------------------------------------------
#  Build documentation
# --------------------------------------------
echo "🧹 Cleaning old docs..."
rm -rf "$OUTPUT_DIR"

echo "📚 Generating DocC documentation..."
swift package \
  generate-documentation \
  --allow-writing-to-directory "$OUTPUT_DIR" \
  --output-path "$OUTPUT_DIR" \
  --transform-for-static-hosting \
  ${REPO_NAME:+--hosting-base-path "$REPO_NAME"} \
  $COMBINED_FLAG \
  $TARGET_FLAGS

echo
echo "🎉 Documentation generated successfully!"
echo "📁 Location: $OUTPUT_DIR"
echo
echo "👉 Preview locally:"
echo "   python3 -m http.server --directory docs 8080"
echo
exit 0