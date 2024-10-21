#!/usr/bin/env bash
set -euo pipefail

log() { printf -- "** %s\n" "$*" >&2; }
error() { printf -- "** ERROR: %s\n" "$*" >&2; }
fatal() { error "$@"; exit 1; }

#https://github.com/apple/swift-format
VERSION="510.1.0"
while getopts v: flag
do
    case "${flag}" in
        v) VERSION=${OPTARG};;
        *)
    esac
done
curl -L -o "${VERSION}.tar.gz" "https://github.com/apple/swift-format/archive/refs/tags/${VERSION}.tar.gz"
tar -xf "${VERSION}.tar.gz"
cd "swift-format-${VERSION}"
swift build -c release
install .build/release/swift-format /usr/local/bin/swift-format
cd ..
rm -f "${VERSION}.tar.gz"
rm -rf "swift-format-${VERSION}"
