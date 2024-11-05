#!/usr/bin/env bash
set -euo pipefail

log() { printf -- "** %s\n" "$*" >&2; }
error() { printf -- "** ERROR: %s\n" "$*" >&2; }
fatal() { error "$@"; exit 1; }

REPO="https://github.com/apple/swift-openapi-generator" 
VERSION=$(git ls-remote --tags --sort="v:refname" "${REPO}" | tail -n1 | sed 's/.*\///; s/\^{}//')
while getopts v: flag
do
    case "${flag}" in
        v) VERSION=${OPTARG};;
        *)
    esac
done
curl -L -o "${VERSION}.tar.gz" "${REPO}/archive/refs/tags/${VERSION}.tar.gz"
tar -xf "${VERSION}.tar.gz"
cd "swift-openapi-generator-${VERSION}"
swift build -c release
install .build/release/swift-openapi-generator /usr/local/bin/swift-openapi-generator
cd ..
rm -f "${VERSION}.tar.gz"
rm -rf "swift-openapi-generator-${VERSION}"