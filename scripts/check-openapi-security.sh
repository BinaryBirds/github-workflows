#!/usr/bin/env bash
set -euo pipefail

log() { printf -- "** %s\n" "$*" >&2; }
error() { printf -- "** ERROR: %s\n" "$*" >&2; }
fatal() { error "$@"; exit 1; }

REPO_ROOT="$(git -C "$PWD" rev-parse --show-toplevel)"

OPENAPI_YAML_LOCATION="${REPO_ROOT}/openapi";
# Check if the OpenAPI directory exists
if ! [ -d "${OPENAPI_YAML_LOCATION}" ]; then
    log "❗Openapi location not found."
    exit 0
fi

# Run the owasp/zap2docker-weekly Docker container to check the OpenAPI YAML file for security issues
docker run --rm --name "check-openapi-security" \
    -v "${OPENAPI_YAML_LOCATION}:/app" \
    -t owasp/zap2docker-stable:latest zap-api-scan.py \
    -t /app/openapi.yaml -f openapi