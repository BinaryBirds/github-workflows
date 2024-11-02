#!/usr/bin/env bash
set -euo pipefail

log() { printf -- "** %s\n" "$*" >&2; }
error() { printf -- "** ERROR: %s\n" "$*" >&2; }
fatal() { error "$@"; exit 1; }

FORMAT_COMMAND=(lint --strict)
for arg in "$@"; do
  if [ "$arg" == "--fix" ]; then
    FORMAT_COMMAND=(format --in-place)
  fi
done

SWIFTFORMAT_BIN=${SWIFTFORMAT_BIN:-$(command -v swift-format)} || fatal "❌ SWIFTFORMAT_BIN unset and no swift-format on PATH"

URL="https://raw.githubusercontent.com/BinaryBirds/github-workflows/refs/heads/dev"
if [ ! -f ".swift-format" ]; then
    log ".swift-format does not exist. Downloading..."
    curl -o ".swift-format" "$URL/.swift-format"
fi

if [ ! -f ".swiftformatignore" ]; then
    log ".swiftformatignore does not exist. Downloading..."
    curl -o ".swiftformatignore" "$URL/.swiftformatignore"
fi

tr '\n' '\0' < .swiftformatignore| xargs -0 -I% printf '":(exclude)%" '| xargs git ls-files -z '*.swift' \
| xargs -0 "${SWIFTFORMAT_BIN}" "${FORMAT_COMMAND[@]}" --parallel \
&& SWIFT_FORMAT_RC=$? || SWIFT_FORMAT_RC=$?

if [ "${SWIFT_FORMAT_RC}" -ne 0 ]; then
  fatal "❌ Running swift-format produced errors.
  To fix:
    % run run-swift-format.sh with paramter: --fix
  "
fi

log "✅ Ran swift-format with no errors."
