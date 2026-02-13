#!/usr/bin/env bash

PROJECT_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd)"

make_temp_repo() {
    local repo
    repo="$(mktemp -d)"

    git -C "$repo" init -q
    git -C "$repo" config user.name "Test User"
    git -C "$repo" config user.email "test@example.com"

    printf '%s\n' "$repo"
}

copy_script_into_repo() {
    local repo="$1"
    local script_name="$2"

    mkdir -p "$repo/scripts"
    cp "$PROJECT_ROOT/scripts/$script_name" "$repo/scripts/$script_name"
    chmod +x "$repo/scripts/$script_name"
}

copy_openapi_scripts_into_repo() {
    local repo="$1"
    copy_script_into_repo "$repo" "check-openapi-validation.sh"
    copy_script_into_repo "$repo" "check-openapi-security.sh"
    copy_script_into_repo "$repo" "run-openapi-docker.sh"
}

install_docker_stub() {
    local repo="$1"

    mkdir -p "$repo/fakebin"
    cat >"$repo/fakebin/docker" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
: "${DOCKER_LOG:?DOCKER_LOG is required}"
printf '%s\n' "$*" >> "$DOCKER_LOG"
exit "${DOCKER_EXIT_CODE:-0}"
STUB
    chmod +x "$repo/fakebin/docker"

    export PATH="$repo/fakebin:$PATH"
}

commit_all() {
    local repo="$1"
    local message="${2:-test commit}"

    git -C "$repo" add -A
    git -C "$repo" commit -q -m "$message"
}
