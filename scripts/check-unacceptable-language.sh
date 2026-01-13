#!/usr/bin/env bash
# Unacceptable Language Check
#
# This script scans the repository for the usage of unacceptable or
# discouraged terminology (e.g. blacklist/whitelist, master/slave, etc.).
#
# The goal is to:
# - Enforce inclusive and respectful language
# - Prevent accidental introduction of discouraged terms
#
# The script supports an optional ignore file:
#   .unacceptablelanguageignore
#
# Lines matching the ignore file are excluded from the scan.
# The script fails if any unacceptable language is found.

set -euo pipefail

# Logging helpers
# All output is written to stderr for consistent CI logs
log()   { printf -- "** %s\n" "$*" >&2; }
error() { printf -- "** ERROR: %s\n" "$*" >&2; }
fatal() { error "$@"; exit 1; }

# List of unacceptable or discouraged words
# The list is converted into a single regex later
UNACCEPTABLE_WORD_LIST="blacklist whitelist slave master sane sanity insane insanity kill killed killing hang hung hanged hanging"

# Will contain matches if any unacceptable language is found
PATHS_WITH_UNACCEPTABLE_LANGUAGE=""

# If an ignore file exists, use it to exclude paths from the search
#
# Each line in .unacceptablelanguageignore is treated as a git pathspec
# exclusion and passed to `git grep`.
if [[ -f .unacceptablelanguageignore ]]; then
    log "Found unacceptablelanguageignore file..."
    log "Checking for unacceptable language..."

    PATHS_WITH_UNACCEPTABLE_LANGUAGE=$(
        tr '\n' '\0' < .unacceptablelanguageignore \
        | xargs -0 -I% printf '":(exclude)%" ' \
        | xargs git grep -i -I -w -H -n --column -E "${UNACCEPTABLE_WORD_LIST// /|}" \
        | grep -v "ignore-unacceptable-language" \
        || true
    ) | /usr/bin/paste -s -d " " -
else
    log "Checking for unacceptable language..."

    PATHS_WITH_UNACCEPTABLE_LANGUAGE=$(
        git grep -i -I -w -H -n --column -E "${UNACCEPTABLE_WORD_LIST// /|}" \
        | grep -v "ignore-unacceptable-language" \
        || true
    ) | /usr/bin/paste -s -d " " -
fi

# If any matches were found, fail the script and print the affected files
if [ -n "${PATHS_WITH_UNACCEPTABLE_LANGUAGE}" ]; then
    fatal "❌ Found unacceptable language in files: ${PATHS_WITH_UNACCEPTABLE_LANGUAGE}."
fi

# Success
log "✅ Found no unacceptable language."