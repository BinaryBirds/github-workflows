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
log() { printf -- "** %s\n" "$*" >&2; }
error() { printf -- "** ERROR: %s\n" "$*" >&2; }
fatal() {
    error "$@"
    exit 1
}

# Resolve script directory
# Allows the script to be executed from any subdirectory.
SCRIPT_SOURCE="${BASH_SOURCE[0]-$0}"
SCRIPT_DIR="$(cd -- "$(dirname -- "${SCRIPT_SOURCE}")" && pwd)"

# Default Docker container name
NAME="openapi-server"

# Default port mapping (host:container)
# Nginx listens on port 80 inside the container
PORT="8888:80"

# Default OpenAPI path (file or directory)
# If a file is provided, its parent directory will be mounted.
OPENAPI_PATH="openapi"

resolve_repo_root() {
    # Prefer git root for local execution and subdirectory calls.
    if root="$(git rev-parse --show-toplevel 2>/dev/null)"; then
        printf '%s\n' "${root}"
        return 0
    fi

    # Fallback for checked-out scripts under a conventional ./scripts layout.
    if [ -d "${SCRIPT_DIR}/../.git" ]; then
        (
            cd -- "${SCRIPT_DIR}/.."
            pwd
        )
        return 0
    fi

    # Last resort for piped execution (for example: curl | bash).
    pwd
}

usage() {
    cat >&2 <<EOF
Usage: $0 [-n name] [-p host_port:container_port] [-f openapi_path]

Options:
  -n NAME   Docker container name (default: ${NAME})
  -p PORT   Port mapping (default: ${PORT})
  -f PATH   OpenAPI path (file or directory). Relative paths are resolved
            from repository root (default: ${OPENAPI_PATH})
EOF
}

# Parse optional CLI flags
#
# -n NAME   Override the Docker container name
# -p PORT   Override the port mapping (host:container)
# -f PATH   Override OpenAPI path (file or directory)
while getopts ":n:p:f:h" flag; do
    case "${flag}" in
        n) NAME="${OPTARG}" ;;
        p) PORT="${OPTARG}" ;;
        f) OPENAPI_PATH="${OPTARG}" ;;
        h)
            usage
            exit 0
            ;;
        \?) fatal "Unknown option: -${OPTARG}" ;;
        :) fatal "Option -${OPTARG} requires an argument." ;;
    esac
done

# Resolve OpenAPI path to an absolute path
if [[ "${OPENAPI_PATH}" = /* ]]; then
    # Absolute paths are used as-is.
    OPENAPI_ABS_PATH="${OPENAPI_PATH}"
else
    # Relative paths prefer repository root, then current working directory.
    REPO_ROOT="$(resolve_repo_root)"
    REPO_OPENAPI_PATH="${REPO_ROOT}/${OPENAPI_PATH}"
    CWD_OPENAPI_PATH="$(pwd)/${OPENAPI_PATH}"

    if [ -e "${REPO_OPENAPI_PATH}" ]; then
        OPENAPI_ABS_PATH="${REPO_OPENAPI_PATH}"
    elif [ -e "${CWD_OPENAPI_PATH}" ]; then
        OPENAPI_ABS_PATH="${CWD_OPENAPI_PATH}"
    else
        OPENAPI_ABS_PATH="${REPO_OPENAPI_PATH}"
    fi
fi

# Allow extension fallback between .yml and .yaml.
if [ ! -e "${OPENAPI_ABS_PATH}" ]; then
    # If the requested extension does not exist, try the sibling extension.
    if [[ "${OPENAPI_ABS_PATH}" == *.yml ]] && [ -f "${OPENAPI_ABS_PATH%.yml}.yaml" ]; then
        OPENAPI_ABS_PATH="${OPENAPI_ABS_PATH%.yml}.yaml"
    elif [[ "${OPENAPI_ABS_PATH}" == *.yaml ]] && [ -f "${OPENAPI_ABS_PATH%.yaml}.yml" ]; then
        OPENAPI_ABS_PATH="${OPENAPI_ABS_PATH%.yaml}.yml"
    fi
fi

# Determine directory to mount in the container.
if [ -d "${OPENAPI_ABS_PATH}" ]; then
    OPENAPI_MOUNT_DIR="${OPENAPI_ABS_PATH}"
elif [ -f "${OPENAPI_ABS_PATH}" ]; then
    OPENAPI_MOUNT_DIR="$(dirname "${OPENAPI_ABS_PATH}")"
else
    error "❗ OpenAPI path not found: ${OPENAPI_ABS_PATH}"
    exit 0
fi

# Serve the OpenAPI files using an Nginx Docker container
#
# - Mounts the OpenAPI directory as the Nginx HTML root
# - Publishes the configured port
# - Automatically removes the container when stopped
docker run --rm --name "${NAME}" \
    -v "${OPENAPI_MOUNT_DIR}:/usr/share/nginx/html" \
    -p "${PORT}" \
    nginx
