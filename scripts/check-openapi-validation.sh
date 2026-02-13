#!/usr/bin/env bash
# OpenAPI Specification Validation
#
# This script validates an OpenAPI specification using a Docker-based
# OpenAPI schema validator.
#
# The goal is to ensure that the OpenAPI document:
# - Is syntactically valid
# - Conforms to the OpenAPI specification
#
# The check is optional:
# - If no OpenAPI specification is present, the script exits successfully
# - This allows repositories without APIs to pass CI without failures

set -euo pipefail

# Logging helpers
# All output is written to stderr for consistent CI logs
log() { printf -- "** %s\n" "$*" >&2; }
error() { printf -- "** ERROR: %s\n" "$*" >&2; }
fatal() {
    error "$@"
    exit 1
}

# Resolve script directory
# Allows the script to be run from any subdirectory.
SCRIPT_SOURCE="${BASH_SOURCE[0]-$0}"
SCRIPT_DIR="$(cd -- "$(dirname -- "${SCRIPT_SOURCE}")" && pwd)"

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
Usage: $0 [-f openapi_path]

Options:
  -f PATH   OpenAPI path (file or directory). Relative paths are resolved
            from repository root (default: ${OPENAPI_PATH})
EOF
}

while getopts ":f:h" flag; do
    case "${flag}" in
        f) OPENAPI_PATH="${OPTARG}" ;;
        h)
            usage
            exit 0
            ;;
        \?) fatal "Unknown option: -${OPTARG}" ;;
        :) fatal "Option -${OPTARG} requires an argument." ;;
    esac
done

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

if [ -f "${OPENAPI_ABS_PATH}" ]; then
    OPENAPI_SPEC_FILE="${OPENAPI_ABS_PATH}"
elif [ -d "${OPENAPI_ABS_PATH}" ]; then
    if [ -f "${OPENAPI_ABS_PATH}/openapi.yaml" ]; then
        OPENAPI_SPEC_FILE="${OPENAPI_ABS_PATH}/openapi.yaml"
    elif [ -f "${OPENAPI_ABS_PATH}/openapi.yml" ]; then
        OPENAPI_SPEC_FILE="${OPENAPI_ABS_PATH}/openapi.yml"
    else
        log "❗ OpenAPI spec not found in directory ${OPENAPI_ABS_PATH} — skipping validation."
        exit 0
    fi
else
    log "❗ OpenAPI path not found — skipping validation."
    exit 0
fi

# Validate the OpenAPI specification using a Docker container
#
# - Mounts the OpenAPI YAML file into the container
# - Runs a strict OpenAPI schema validation
# - Fails the script if the specification is invalid
#
# The container is removed after execution to keep the environment clean
docker run --rm --name "check-openapi-validation" \
    -v "${OPENAPI_SPEC_FILE}:/openapi.yaml" \
    pythonopenapi/openapi-spec-validator /openapi.yaml
