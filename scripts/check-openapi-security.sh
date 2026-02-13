#!/usr/bin/env bash
# OpenAPI Security Check (OWASP ZAP)
#
# This script runs an OWASP ZAP API security scan against an OpenAPI
# specification located in the repository.
#
# It is designed to be:
# - Safe for CI (no side effects)
# - Optional (exits successfully if no OpenAPI spec is present)
#
# The scan helps identify common API security issues early in the pipeline.

set -euo pipefail

# Logging helpers
# All output goes to stderr for consistent CI logs
log() { printf -- "** %s\n" "$*" >&2; }
error() { printf -- "** ERROR: %s\n" "$*" >&2; }
fatal() {
    error "$@"
    exit 1
}

# Resolve script directory
# This allows the script to be run from any subdirectory.
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
    # Relative paths are resolved from repository root.
    REPO_ROOT="$(resolve_repo_root)"
    OPENAPI_ABS_PATH="${REPO_ROOT}/${OPENAPI_PATH}"
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
        log "❗ OpenAPI spec not found in directory ${OPENAPI_ABS_PATH} — skipping security scan."
        exit 0
    fi
else
    log "❗ OpenAPI path not found — skipping security scan."
    exit 0
fi

# Run OWASP ZAP API scan in a Docker container
#
# - Mounts the OpenAPI file into the container
# - Uses the OpenAPI specification as the scan target
# - Fails the script if security issues are detected
#
# The container is removed after execution to keep the environment clean
docker run --rm --name "check-openapi-security" \
    -v "${OPENAPI_SPEC_FILE}:/app/openapi.yaml" \
    -t zaproxy/zap-stable:latest zap-api-scan.py \
    -t /app/openapi.yaml -f openapi
