#!/usr/bin/env bash
# OpenAPI Security Lint (Spectral)
#
# This script runs fast static security lint checks against an OpenAPI
# specification using Spectral in Docker.
#
# It is designed to be:
# - Fast for CI and local runs
# - Optional (exits successfully if no OpenAPI spec is present)
# - Static (no running API server required)

set -euo pipefail

# Logging helpers
log() { printf -- "** %s\n" "$*" >&2; }
error() { printf -- "** ERROR: %s\n" "$*" >&2; }
fatal() {
    error "$@"
    exit 1
}

SCRIPT_SOURCE="${BASH_SOURCE[0]-$0}"
SCRIPT_DIR="$(cd -- "$(dirname -- "${SCRIPT_SOURCE}")" && pwd)"

OPENAPI_PATH="openapi"
RULESET_FILE=""
RULESET_CONTAINER_PATH="/tmp/spectral-security-ruleset.yaml"

resolve_repo_root() {
    if root="$(git rev-parse --show-toplevel 2>/dev/null)"; then
        printf '%s\n' "${root}"
        return 0
    fi

    if [ -d "${SCRIPT_DIR}/../.git" ]; then
        (
            cd -- "${SCRIPT_DIR}/.."
            pwd
        )
        return 0
    fi

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

cleanup() {
    if [ -n "${RULESET_FILE}" ]; then
        rm -f "${RULESET_FILE}"
    fi
}
trap cleanup EXIT

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
    OPENAPI_ABS_PATH="${OPENAPI_PATH}"
else
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
        log "❗ OpenAPI spec not found in directory ${OPENAPI_ABS_PATH} — skipping security lint."
        exit 0
    fi
else
    log "❗ OpenAPI path not found — skipping security lint."
    exit 0
fi

RULESET_FILE="$(mktemp "${TMPDIR:-/tmp}/spectral-security-ruleset.XXXXXX.yaml")"
cat >"${RULESET_FILE}" <<'EOF'
extends:
  - spectral:oas
rules:
  security-requirement-defined:
    description: "Define security requirements at root and/or operation level."
    severity: error
    given:
      - "$"
    then:
      field: security
      function: truthy
  no-http-server-urls:
    description: "Server URLs should use HTTPS."
    severity: error
    given: "$.servers[*].url"
    then:
      function: pattern
      functionOptions:
        match: "^https://"
EOF

OPENAPI_SPEC_BASENAME="$(basename "${OPENAPI_SPEC_FILE}")"
docker run --rm --name "check-openapi-security-lint" \
    -v "${OPENAPI_SPEC_FILE}:/app/${OPENAPI_SPEC_BASENAME}" \
    -v "${RULESET_FILE}:${RULESET_CONTAINER_PATH}" \
    stoplight/spectral:latest lint "/app/${OPENAPI_SPEC_BASENAME}" \
    --fail-severity error \
    --display-only-failures \
    --ruleset "${RULESET_CONTAINER_PATH}"
