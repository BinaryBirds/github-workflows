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
log()   { printf -- "** %s\n" "$*" >&2; }
error() { printf -- "** ERROR: %s\n" "$*" >&2; }
fatal() { error "$@"; exit 1; }

# Resolve repository root
# This allows the script to be run from any subdirectory
REPO_ROOT="$(git -C "$PWD" rev-parse --show-toplevel)"

# Expected location of the OpenAPI specification
# The directory is expected to contain an `openapi.yaml` file
OPENAPI_YAML_LOCATION="${REPO_ROOT}/openapi"

# If no OpenAPI directory exists, skip the check gracefully
# This allows repositories without APIs to pass without failure
if [ ! -d "${OPENAPI_YAML_LOCATION}" ]; then
    log "❗ OpenAPI location not found — skipping security scan."
    exit 0
fi

# Run OWASP ZAP API scan in a Docker container
#
# - Mounts the OpenAPI directory into the container
# - Uses the OpenAPI specification as the scan target
# - Fails the script if security issues are detected
#
# The container is removed after execution to keep the environment clean
docker run --rm --name "check-openapi-security" \
    -v "${OPENAPI_YAML_LOCATION}:/app" \
    -t owasp/zap2docker-stable:latest zap-api-scan.py \
    -t /app/openapi.yaml -f openapi