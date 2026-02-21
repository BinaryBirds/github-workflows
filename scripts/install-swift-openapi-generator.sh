#!/usr/bin/env bash
# Swift OpenAPI Generator Installer
#
# This script downloads, builds, and installs the Swift OpenAPI Generator
# from its official GitHub repository.
#
# By default:
# - The latest tagged release is installed
#
# Optional behavior:
# - A specific version can be installed using the `-v` flag
#
# Intended usage:
# - CI: ensure a known version of the generator is available
# - Local: install or update the generator for development use

set -euo pipefail

# Logging helpers
# All output is written to stderr for consistent CI and local logs
log() { printf -- "** %s\n" "$*" >&2; }
error() { printf -- "** ERROR: %s\n" "$*" >&2; }
fatal() {
    error "$@"
    exit 1
}

# Repository containing the Swift OpenAPI Generator
REPO="https://github.com/apple/swift-openapi-generator"
VERSION=""

usage() {
    cat >&2 <<EOF
Usage: $0 [-v version]

Options:
  -v VERSION   Install a specific version tag (default: latest available tag)
  -h           Show this help message
EOF
}

# Parse optional flags
#
# -v VERSION   Install a specific version instead of the latest one
while getopts ":v:h" flag; do
    case "${flag}" in
        v)
            VERSION=${OPTARG}
            ;;
        h)
            usage
            exit 0
            ;;
        \?) fatal "Unknown option: -${OPTARG}" ;;
        :) fatal "Option -${OPTARG} requires an argument." ;;
    esac
done

for required_cmd in git curl tar swift install; do
    command -v "${required_cmd}" >/dev/null 2>&1 ||
        fatal "'${required_cmd}' is required but not installed"
done

if [ -z "${VERSION}" ]; then
    # Determine latest available tag by default.
    VERSION=$(git ls-remote --tags --sort="v:refname" "${REPO}" |
        tail -n1 |
        sed 's/.*\///; s/\^{}//')
fi

[ -n "${VERSION}" ] ||
    fatal "Unable to resolve swift-openapi-generator version"

log "Installing swift-openapi-generator version: ${VERSION}"

# Download the source archive for the selected version
curl -fL -o "${VERSION}.tar.gz" \
    "${REPO}/archive/refs/tags/${VERSION}.tar.gz"

# Extract the source archive
tar -xf "${VERSION}.tar.gz"

# Build the generator in release mode
cd "swift-openapi-generator-${VERSION}"
swift build -c release

# Install the compiled binary into /usr/local/bin
#
# This typically requires appropriate permissions (e.g. sudo)
install .build/release/swift-openapi-generator /usr/local/bin/swift-openapi-generator

# Return to the original directory
cd ..

# Clean up downloaded and extracted files
rm -f "${VERSION}.tar.gz"
rm -rf "swift-openapi-generator-${VERSION}"

log "✅ swift-openapi-generator ${VERSION} installed successfully."
