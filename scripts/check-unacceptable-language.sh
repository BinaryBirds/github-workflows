#!/usr/bin/env bash
set -euo pipefail

log() { printf -- "** %s\n" "$*" >&2; }
error() { printf -- "** ERROR: %s\n" "$*" >&2; }
fatal() { error "$@"; exit 1; }

UNACCEPTABLE_WORD_LIST="blacklist whitelist slave master sane sanity insane insanity kill killed killing hang hung hanged hanging"

PATHS_WITH_UNACCEPTABLE_LANGUAGE=
if [[ -f .unacceptablelanguageignore ]]; then
    log "Found unacceptablelanguageignore file..."
    log "Checking for unacceptable language..."
    PATHS_WITH_UNACCEPTABLE_LANGUAGE=$(tr '\n' '\0' < .unacceptablelanguageignore | xargs -0 -I% printf '":(exclude)%" '| xargs git grep -i -I -w -H -n --column -E "${UNACCEPTABLE_WORD_LIST// /|}" | grep -v "ignore-unacceptable-language") || true | /usr/bin/paste -s -d " " -
else
    log "Checking for unacceptable language..."
    PATHS_WITH_UNACCEPTABLE_LANGUAGE=$(git grep -i -I -w -H -n --column -E "${UNACCEPTABLE_WORD_LIST// /|}" | grep -v "ignore-unacceptable-language") || true | /usr/bin/paste -s -d " " -
fi

if [ -n "${PATHS_WITH_UNACCEPTABLE_LANGUAGE}" ]; then
  fatal "❌ Found unacceptable language in files: ${PATHS_WITH_UNACCEPTABLE_LANGUAGE}."
fi

log "✅ Found no unacceptable language."
