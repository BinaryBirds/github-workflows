#!/usr/bin/env bash
set -euo pipefail

log() { printf -- "** %s\n" "$*" >&2; }
error() { printf -- "** ERROR: %s\n" "$*" >&2; }
fatal() { error "$@"; exit 1; }

REPO_ROOT="$(git -C "$PWD" rev-parse --show-toplevel)"

OPENAPI_YAML_LOCATION="${REPO_ROOT}/openapi";
# Check if the OpenAPI directory exists
if ! [ -d "${OPENAPI_YAML_LOCATION}" ]; then
    error "❗Openapi location not found."
    exit 0
fi

NAME="openapi-server"
PORT="8888:80"
while getopts ":n:p:": flag
do
    case "${flag}" in
        n) NAME=${OPTARG};;
        p) PORT=${OPTARG};;
        *)
    esac
done

# Run the Docker container to serve the OpenAPI files using Nginx
docker run --rm --name "${NAME}" \
    -v "${OPENAPI_YAML_LOCATION}:/usr/share/nginx/html" \
    -p "${PORT}" nginx
