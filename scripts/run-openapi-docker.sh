#!/usr/bin/env bash
# OpenAPI Local Server
#
# This script serves OpenAPI files locally using an Nginx Docker container.
#
# It assumes that OpenAPI files are stored in the `openapi` directory at the
# root of the repository.
#
# Intended usage:
# - Local development and preview of OpenAPI specifications
# - Quick verification that OpenAPI files are accessible via HTTP
#
# The server runs until the Docker container is stopped.

set -euo pipefail

# Logging helpers
# All output is written to stderr for consistent local logs
log()   { printf -- "** %s\n" "$*" >&2; }
error() { printf -- "** ERROR: %s\n" "$*" >&2; }
fatal() { error "$@"; exit 1; }

# Resolve repository root
# Allows the script to be executed from any subdirectory
REPO_ROOT="$(git -C "$PWD" rev-parse --show-toplevel)"

# Location of OpenAPI files
# The directory is expected to contain one or more OpenAPI specifications
OPENAPI_YAML_LOCATION="${REPO_ROOT}/openapi"

# If the OpenAPI directory does not exist, skip serving gracefully
# This avoids failing for repositories without API definitions
if [ ! -d "${OPENAPI_YAML_LOCATION}" ]; then
    error "❗ OpenAPI location not found."
    exit 0
fi

# Default Docker container name
NAME="openapi-server"

# Default port mapping (host:container)
# Nginx listens on port 80 inside the container
PORT="8888:80"

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

# Serve the OpenAPI files using an Nginx Docker container
#
# - Mounts the OpenAPI directory as the Nginx HTML root
# - Publishes the configured port
# - Automatically removes the container when stopped
docker run --rm --name "${NAME}" \
    -v "${OPENAPI_YAML_LOCATION}:/usr/share/nginx/html" \
    -p "${PORT}" \
    nginx