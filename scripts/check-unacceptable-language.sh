#!/usr/bin/env bash
set -euo pipefail

log() { printf -- "** %s\n" "$*" >&2; }
error() { printf -- "** ERROR: %s\n" "$*" >&2; }
fatal() { error "$@"; exit 1; }

REPO_ROOT="$(git -C "$PWD" rev-parse --show-toplevel)"
UNACCEPTABLE_LANGUAGE_PATTERNS_PATH="${REPO_ROOT}/scripts/unacceptable-language.txt"

log "Checking for unacceptable language..."
PATHS_WITH_UNACCEPTABLE_LANGUAGE=$(git -C "${REPO_ROOT}" grep \
-l -F -w \
-f "${UNACCEPTABLE_LANGUAGE_PATTERNS_PATH}" \
-- ":(exclude)${UNACCEPTABLE_LANGUAGE_PATTERNS_PATH}" \
) || true | /usr/bin/paste -s -d " " -

if [ -n "${PATHS_WITH_UNACCEPTABLE_LANGUAGE}" ]; then
  fatal "❌ Found unacceptable language in files: ${PATHS_WITH_UNACCEPTABLE_LANGUAGE}."
fi

log "✅ Found no unacceptable language."
