#!/usr/bin/env bash
set -euo pipefail

log() { printf -- "** %s\n" "$*" >&2; }
error() { printf -- "** ERROR: %s\n" "$*" >&2; }
fatal() { error "$@"; exit 1; }

rm -rf ".build"
rm -rf ".swiftpm"
rm -f "openapi/openapi.yaml"
rm -f "db.sqlite"
rm -f "migration-entries.json"