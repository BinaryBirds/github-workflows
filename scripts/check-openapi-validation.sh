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
log()   { printf -- "** %s\n" "$*" >&2; }
error() { printf -- "** ERROR: %s\n" "$*" >&2; }
fatal() { error "$@"; exit 1; }

# Resolve the repository root
# Allows the script to be run from any subdirectory
REPO_ROOT="$(git -C "$PWD" rev-parse --show-toplevel)"

# Location of the OpenAPI specification directory
# The directory is expected to contain an `openapi.yaml` file
OPENAPI_YAML_LOCATION="${REPO_ROOT}/openapi"

# If the OpenAPI directory does not exist, skip validation gracefully
# This avoids failing CI for repositories that do not define APIs
if [ ! -d "${OPENAPI_YAML_LOCATION}" ]; then
    log "❗ OpenAPI location not found — skipping validation."
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
    -v "${OPENAPI_YAML_LOCATION}/openapi.yaml:/openapi.yaml" \
    pythonopenapi/openapi-spec-validator /openapi.yaml