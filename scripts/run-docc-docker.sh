#!/usr/bin/env bash
set -euo pipefail

log()   { printf -- "** %s\n" "$*" >&2; }
error() { printf -- "** ERROR: %s\n" "$*" >&2; }
fatal() { error "$@"; exit 1; }

REPO_ROOT="$(git -C "$PWD" rev-parse --show-toplevel)"
DOCC_DIR="${REPO_ROOT}/docs"
NAME="docc-server"
PORT="8080:80"

# Validate docs directory
if ! [ -d "${DOCC_DIR}" ]; then
    fatal "DocC output directory not found: ${DOCC_DIR}"
fi

# Parse optional CLI flags
while getopts ":n:p:" flag; do
    case "${flag}" in
        n) NAME="${OPTARG}" ;;
        p) PORT="${OPTARG}" ;;
        *) ;;
    esac
done

LOCAL_PORT="${PORT%%:*}"
log "Open in browser:  http://localhost:${LOCAL_PORT}/documentation/"
echo

# Serve using Docker nginx
docker run --rm --name "${NAME}" \
    -v "${DOCC_DIR}:/usr/share/nginx/html" \
    -p "${PORT}" \
    nginx