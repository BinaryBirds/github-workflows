#!/usr/bin/env bash
set -euo pipefail

# ------------------------------------------------------------
# Ensures that swift-docc-plugin (>= 1.4.0) is present
# in Package.swift.
#
# Behavior:
# - If the plugin dependency already exists, does nothing.
# - If dependencies exist, injects the plugin into them.
# - If dependencies do not exist:
#   - Inserts them after products, or
#   - Before targets as a fallback.
#
# NOTE:
# - This function mutates Package.swift.
# - Caller MUST ensure the git working tree is clean
#   and MUST rollback changes if needed.
# ------------------------------------------------------------

ensure_docc_plugin() {
    local PACKAGE_FILE="Package.swift"

    if [ ! -f "$PACKAGE_FILE" ]; then
        echo "** ERROR: Package.swift not found" >&2
        return 1
    fi

    # Already present (any formatting)
    if grep -q 'github.com/apple/swift-docc-plugin' "$PACKAGE_FILE"; then
        echo "** swift-docc-plugin already present — using existing configuration" >&2
        return 0
    fi

    echo "** swift-docc-plugin missing — injecting temporarily (from 1.4.0)" >&2

    # Case 1: dependencies section exists
    if grep -q 'dependencies\s*:' "$PACKAGE_FILE"; then
        perl -0777 -i -pe '
            s|(
                dependencies:\s*\[\s*
            )
            |$1
                .package(
                    url: "https://github.com/apple/swift-docc-plugin",
                    from: "1.4.0"
                ),
            |xs
        ' "$PACKAGE_FILE"
        return 0
    fi

    # Case 2: products exist → insert after products
    if grep -q 'products\s*:' "$PACKAGE_FILE"; then
        perl -0777 -i -pe '
            s|(
                products:\s*\[[^\]]*\],\s*
            )
            |$1
            dependencies: [
                .package(
                    url: "https://github.com/apple/swift-docc-plugin",
                    from: "1.4.0"
                )
            ],
        |xs
        ' "$PACKAGE_FILE"
        return 0
    fi

    # Case 3: fallback → insert before targets
    if grep -q 'targets\s*:' "$PACKAGE_FILE"; then
        perl -0777 -i -pe '
            s|(
                targets:\s*\[
            )
            |dependencies: [
                .package(
                    url: "https://github.com/apple/swift-docc-plugin",
                    from: "1.4.0"
                )
            ],
            $1
        |xs
        ' "$PACKAGE_FILE"
        return 0
    fi

    echo "** ERROR: Unsupported Package.swift structure" >&2
    return 1
}