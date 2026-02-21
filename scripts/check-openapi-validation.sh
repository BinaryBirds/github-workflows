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
DEBUG=false
DETAILED=false

# Support long option for detailed diagnostics.
NORMALIZED_ARGS=()
for arg in "$@"; do
    if [ "$arg" = "--detailed" ]; then
        NORMALIZED_ARGS+=("-D")
    else
        NORMALIZED_ARGS+=("$arg")
    fi
done
if [ "${#NORMALIZED_ARGS[@]}" -gt 0 ]; then
    set -- "${NORMALIZED_ARGS[@]}"
else
    set --
fi

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
Usage: $0 [-f openapi_path] [-d] [--detailed]

Options:
  -f PATH   OpenAPI path (file or directory). Relative paths are resolved
            from repository root (default: ${OPENAPI_PATH})
  -d        Enable debug tracing (resolved paths + docker command trace)
  --detailed Run additional detailed Spectral diagnostics when validation fails
EOF
}

while getopts ":f:dDh" flag; do
    case "${flag}" in
        f) OPENAPI_PATH="${OPTARG}" ;;
        d) DEBUG=true ;;
        D) DETAILED=true ;;
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

# Allow extension fallback among .yml, .yaml, and .json.
if [ ! -e "${OPENAPI_ABS_PATH}" ]; then
    # If the requested extension does not exist, try sibling extensions.
    if [[ "${OPENAPI_ABS_PATH}" == *.yml ]] && [ -f "${OPENAPI_ABS_PATH%.yml}.yaml" ]; then
        OPENAPI_ABS_PATH="${OPENAPI_ABS_PATH%.yml}.yaml"
    elif [[ "${OPENAPI_ABS_PATH}" == *.yml ]] && [ -f "${OPENAPI_ABS_PATH%.yml}.json" ]; then
        OPENAPI_ABS_PATH="${OPENAPI_ABS_PATH%.yml}.json"
    elif [[ "${OPENAPI_ABS_PATH}" == *.yaml ]] && [ -f "${OPENAPI_ABS_PATH%.yaml}.yml" ]; then
        OPENAPI_ABS_PATH="${OPENAPI_ABS_PATH%.yaml}.yml"
    elif [[ "${OPENAPI_ABS_PATH}" == *.yaml ]] && [ -f "${OPENAPI_ABS_PATH%.yaml}.json" ]; then
        OPENAPI_ABS_PATH="${OPENAPI_ABS_PATH%.yaml}.json"
    elif [[ "${OPENAPI_ABS_PATH}" == *.json ]] && [ -f "${OPENAPI_ABS_PATH%.json}.yaml" ]; then
        OPENAPI_ABS_PATH="${OPENAPI_ABS_PATH%.json}.yaml"
    elif [[ "${OPENAPI_ABS_PATH}" == *.json ]] && [ -f "${OPENAPI_ABS_PATH%.json}.yml" ]; then
        OPENAPI_ABS_PATH="${OPENAPI_ABS_PATH%.json}.yml"
    fi
fi

if [ -f "${OPENAPI_ABS_PATH}" ]; then
    OPENAPI_SPEC_FILE="${OPENAPI_ABS_PATH}"
elif [ -d "${OPENAPI_ABS_PATH}" ]; then
    if [ -f "${OPENAPI_ABS_PATH}/openapi.yaml" ]; then
        OPENAPI_SPEC_FILE="${OPENAPI_ABS_PATH}/openapi.yaml"
    elif [ -f "${OPENAPI_ABS_PATH}/openapi.yml" ]; then
        OPENAPI_SPEC_FILE="${OPENAPI_ABS_PATH}/openapi.yml"
    elif [ -f "${OPENAPI_ABS_PATH}/openapi.json" ]; then
        OPENAPI_SPEC_FILE="${OPENAPI_ABS_PATH}/openapi.json"
    else
        log "❗ OpenAPI spec not found in directory ${OPENAPI_ABS_PATH} — skipping validation."
        exit 0
    fi
else
    log "❗ OpenAPI path not found — skipping validation."
    exit 0
fi

if [ "${DEBUG}" = true ]; then
    log "Debug enabled."
    log "Resolved OpenAPI path: ${OPENAPI_ABS_PATH}"
    log "Selected OpenAPI spec file: ${OPENAPI_SPEC_FILE}"
    log "Detailed diagnostics on failure: ${DETAILED}"
fi

# Validate the OpenAPI specification using a Docker container
#
# - Mounts the OpenAPI file into the container
# - Runs a strict OpenAPI schema validation
# - Fails the script if the specification is invalid
#
# The container is removed after execution to keep the environment clean
OPENAPI_SPEC_BASENAME="$(basename "${OPENAPI_SPEC_FILE}")"
if [ "${DEBUG}" = true ]; then
    log "Running validator in Docker against /${OPENAPI_SPEC_BASENAME}"
    set -x
fi
set +e
docker run --rm --name "check-openapi-validation" \
    -v "${OPENAPI_SPEC_FILE}:/${OPENAPI_SPEC_BASENAME}" \
    pythonopenapi/openapi-spec-validator "/${OPENAPI_SPEC_BASENAME}"
VALIDATION_RC=$?
set -e
if [ "${DEBUG}" = true ]; then
    set +x
fi

if [ "${VALIDATION_RC}" -ne 0 ] && [ "${DETAILED}" = true ]; then
    log "Validation failed — running detailed Spectral diagnostics."
    set +e
    docker run --rm --name "check-openapi-validation-detailed" \
        -v "${OPENAPI_SPEC_FILE}:/${OPENAPI_SPEC_BASENAME}" \
        stoplight/spectral:latest lint "/${OPENAPI_SPEC_BASENAME}"
    SPECTRAL_RC=$?
    set -e

    if [ "${SPECTRAL_RC}" -ne 0 ]; then
        log "Detailed diagnostics reported additional issues."
    else
        log "Detailed diagnostics completed."
    fi
fi

exit "${VALIDATION_RC}"
