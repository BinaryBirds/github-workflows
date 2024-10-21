#!/usr/bin/env bash
set -euo pipefail

log() { printf -- "** %s\n" "$*" >&2; }
error() { printf -- "** ERROR: %s\n" "$*" >&2; }
fatal() { error "$@"; exit 1; }

REPO_ROOT="$(git -C "$PWD" rev-parse --show-toplevel)"

FORMAT_COMMAND=(lint --strict)
for arg in "$@"; do
  if [ "$arg" == "--fix" ]; then
    FORMAT_COMMAND=(format --in-place)
  fi
done

SWIFTFORMAT_BIN=${SWIFTFORMAT_BIN:-$(command -v swift-format)} || fatal "❌ SWIFTFORMAT_BIN unset and no swift-format on PATH"

git -C "${REPO_ROOT}" ls-files -z '*.swift' | xargs -0 "${SWIFTFORMAT_BIN}" "${FORMAT_COMMAND[@]}" --parallel \
&& SWIFT_FORMAT_RC=$? || SWIFT_FORMAT_RC=$?

if [ "${SWIFT_FORMAT_RC}" -ne 0 ]; then
  fatal "❌ Running swift-format produced errors.
  To fix, run the following command:
    % ./scripts/run-swift-format.sh --fix
  "
fi

log "✅ Ran swift-format with no errors."
