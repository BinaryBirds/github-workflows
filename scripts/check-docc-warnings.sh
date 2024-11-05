#!/usr/bin/env bash
set -euo pipefail

log() { printf -- "** %s\n" "$*" >&2; }
error() { printf -- "** ERROR: %s\n" "$*" >&2; }
fatal() { error "$@"; exit 1; }

REPO_ROOT="$(git -C "$PWD" rev-parse --show-toplevel)"

log "Checking required environment variables..."
test -n "${DOCC_TARGET:-}" || fatal "DOCC_TARGET unset"

swift package --package-path "${REPO_ROOT}" plugin generate-documentation \
  --product "${DOCC_TARGET}" \
  --analyze \
  --level detailed \
  --warnings-as-errors \
  && DOCC_PLUGIN_RC=$? || DOCC_PLUGIN_RC=$?

if [ "${DOCC_PLUGIN_RC}" -ne 0 ]; then
  fatal "❌ Generating documentation produced warnings and/or errors."
  exit "${DOCC_PLUGIN_RC}"
fi

log "✅ Generated documentation with no warnings."