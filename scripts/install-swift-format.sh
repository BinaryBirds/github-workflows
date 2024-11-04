#!/usr/bin/env bash
set -euo pipefail

log() { printf -- "** %s\n" "$*" >&2; }
error() { printf -- "** ERROR: %s\n" "$*" >&2; }
fatal() { error "$@"; exit 1; }

REPO="https://github.com/swiftlang/swift-format" 
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
cd "swift-format-${VERSION}"
swift build -c release
install .build/release/swift-format /usr/local/bin/swift-format
cd ..
rm -f "${VERSION}.tar.gz"
rm -rf "swift-format-${VERSION}"
