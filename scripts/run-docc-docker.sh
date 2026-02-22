#!/usr/bin/env bash
# DocC Local Documentation Server
#
# This script serves generated DocC documentation locally using an Nginx
# Docker container.
#
# It assumes that documentation has already been generated into the `docs`
# directory (for example using a DocC generation script).
#
# Intended usage:
# - Local development and preview of DocC documentation
# - Quick verification of documentation structure and links
#
# The server runs until the Docker container is stopped.

set -euo pipefail

# Logging helpers
# All output is written to stderr for consistent local logs
log() { printf -- "** %s\n" "$*" >&2; }
error() { printf -- "** ERROR: %s\n" "$*" >&2; }
fatal() {
    error "$@"
    exit 1
}

# Resolve repository root
# Ensures the docs directory is located correctly even if the script
# is executed from a subdirectory
REPO_ROOT="$(git -C "$PWD" rev-parse --show-toplevel)"

# Location of generated DocC documentation
DOCC_DIR="${REPO_ROOT}/docs"

# Default Docker container name
NAME="docc-server"

# Default port mapping (host:container)
# Nginx listens on port 80 inside the container
PORT="8080:80"

# Validate that the documentation directory exists
# If documentation has not been generated yet, fail early with a clear error
if [ ! -d "${DOCC_DIR}" ]; then
    fatal "DocC output directory not found: ${DOCC_DIR}"
fi

# Parse optional CLI flags
#
# -n NAME   Override the Docker container name
# -p PORT   Override the port mapping (host:container)
while getopts ":n:p:" flag; do
    case "${flag}" in
        n) NAME="${OPTARG}" ;;
        p) PORT="${OPTARG}" ;;
        *) ;;
    esac
done

# Extract the local (host) port from the port mapping
# This is used only for printing a helpful browser URL
LOCAL_PORT="${PORT%%:*}"

# Print the URL where the documentation can be accessed
log "Open in browser: http://localhost:${LOCAL_PORT}/documentation/"
echo

# Serve the documentation using an Nginx Docker container
#
# - Mounts the docs directory as the Nginx HTML root
# - Publishes the configured port
# - Removes the container automatically when stopped
docker run --rm --name "${NAME}" \
    -v "${DOCC_DIR}:/usr/share/nginx/html" \
    -p "${PORT}" \
    nginx
