#!/usr/bin/env bats

load 'helpers/test_helper.bash'

@test "install-swift-openapi-generator fails when latest version cannot be resolved" {
    repo="$(make_temp_repo)"
    copy_script_into_repo "$repo" "install-swift-openapi-generator.sh"

    mkdir -p "$repo/fakebin"
    cat >"$repo/fakebin/git" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-}" == "ls-remote" ]]; then
  exit 0
fi
exit 0
STUB
    cat >"$repo/fakebin/curl" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
exit 0
STUB
    cat >"$repo/fakebin/tar" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
exit 0
STUB
    cat >"$repo/fakebin/swift" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
exit 0
STUB
    cat >"$repo/fakebin/install" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
exit 0
STUB
    chmod +x "$repo/fakebin/git" "$repo/fakebin/curl" "$repo/fakebin/tar" "$repo/fakebin/swift" "$repo/fakebin/install"
    export PATH="$repo/fakebin:$PATH"

    run bash -c "cd '$repo' && bash scripts/install-swift-openapi-generator.sh"

    [ "$status" -eq 1 ]
    [[ "$output" == *"Unable to resolve swift-openapi-generator version"* ]]
}

@test "install-swift-openapi-generator uses fail-fast curl flags" {
    repo="$(make_temp_repo)"
    copy_script_into_repo "$repo" "install-swift-openapi-generator.sh"

    mkdir -p "$repo/fakebin"
    cat >"$repo/fakebin/git" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
exit 0
STUB
    cat >"$repo/fakebin/curl" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
: "${CURL_LOG:?CURL_LOG is required}"
printf '%s\n' "$*" >> "$CURL_LOG"
exit 0
STUB
    cat >"$repo/fakebin/tar" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
mkdir -p "swift-openapi-generator-v1.2.3"
exit 0
STUB
    cat >"$repo/fakebin/swift" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
exit 0
STUB
    cat >"$repo/fakebin/install" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
exit 0
STUB
    chmod +x "$repo/fakebin/git" "$repo/fakebin/curl" "$repo/fakebin/tar" "$repo/fakebin/swift" "$repo/fakebin/install"
    export PATH="$repo/fakebin:$PATH"
    export CURL_LOG="$repo/curl.log"

    run bash -c "cd '$repo' && bash scripts/install-swift-openapi-generator.sh -v v1.2.3"

    [ "$status" -eq 0 ]
    curl_call="$(cat "$CURL_LOG")"
    [[ "$curl_call" == *"-fL -o v1.2.3.tar.gz"* ]]
}
