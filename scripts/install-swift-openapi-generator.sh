#!/usr/bin/env bash
set -euo pipefail

log() { printf -- "** %s\n" "$*" >&2; }
error() { printf -- "** ERROR: %s\n" "$*" >&2; }
fatal() { error "$@"; exit 1; }

#https://github.com/apple/swift-openapi-generator
VERSION="1.2.1"
while getopts v: flag
do
    case "${flag}" in
        v) VERSION=${OPTARG};;
        *)
    esac
done
curl -L -o "${VERSION}.tar.gz" "https://github.com/apple/swift-openapi-generator/archive/refs/tags/${VERSION}.tar.gz"
tar -xf "${VERSION}.tar.gz"
cd "swift-openapi-generator-${VERSION}"
swift build -c release
install .build/release/swift-openapi-generator /usr/local/bin/swift-openapi-generator
cd ..
rm -f "${VERSION}.tar.gz"
rm -rf "swift-openapi-generator-${VERSION}"