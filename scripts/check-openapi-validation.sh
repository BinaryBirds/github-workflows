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

# Run the Docker container to validate the OpenAPI YAML file
docker run --rm --name "check-openapi-validation" \
    -v "${OPENAPI_YAML_LOCATION}/openapi.yaml:/openapi.yaml" \
    pythonopenapi/openapi-spec-validator /openapi.yaml
