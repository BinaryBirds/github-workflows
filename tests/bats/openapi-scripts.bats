#!/usr/bin/env bats

load 'helpers/test_helper.bash'

@test "check-openapi-validation resolves .yml to .yaml and calls docker with expected mount" {
    repo="$(make_temp_repo)"
    copy_openapi_scripts_into_repo "$repo"
    install_docker_stub "$repo"

    mkdir -p "$repo/api"
    cat >"$repo/api/openapi.yaml" <<'YAML'
openapi: 3.0.0
info:
  title: Test API
  version: 1.0.0
paths: {}
YAML

    export DOCKER_LOG="$repo/docker.log"
    run bash -c "cd '$repo' && bash scripts/check-openapi-validation.sh -f '$repo/api/openapi.yml'"

    [ "$status" -eq 0 ]
    docker_call="$(cat "$DOCKER_LOG")"
    [[ "$docker_call" == *"-v $repo/api/openapi.yaml:/openapi.yaml"* ]]
    [[ "$docker_call" == *"pythonopenapi/openapi-spec-validator /openapi.yaml"* ]]
}

@test "check-openapi-validation supports debug mode" {
    repo="$(make_temp_repo)"
    copy_openapi_scripts_into_repo "$repo"
    install_docker_stub "$repo"

    mkdir -p "$repo/api"
    cat >"$repo/api/openapi.yaml" <<'YAML'
openapi: 3.0.0
info:
  title: Debug API
  version: 1.0.0
paths: {}
YAML

    export DOCKER_LOG="$repo/docker.log"
    run bash -c "cd '$repo' && bash scripts/check-openapi-validation.sh -d -f '$repo/api/openapi.yaml'"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Debug enabled."* ]]
    docker_call="$(cat "$DOCKER_LOG")"
    [[ "$docker_call" == *"-v $repo/api/openapi.yaml:/openapi.yaml"* ]]
}

@test "check-openapi-validation --detailed runs Spectral diagnostics after validator failure" {
    repo="$(make_temp_repo)"
    copy_openapi_scripts_into_repo "$repo"

    mkdir -p "$repo/fakebin"
    cat >"$repo/fakebin/docker" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
: "${DOCKER_LOG:?DOCKER_LOG is required}"
printf '%s\n' "$*" >> "$DOCKER_LOG"
if [[ "$*" == *"pythonopenapi/openapi-spec-validator"* ]]; then
  exit 1
fi
exit 0
STUB
    chmod +x "$repo/fakebin/docker"
    export PATH="$repo/fakebin:$PATH"

    mkdir -p "$repo/api"
    cat >"$repo/api/openapi.yaml" <<'YAML'
openapi: 3.0.0
info:
  title: Detailed API
  version: 1.0.0
paths: {}
YAML

    export DOCKER_LOG="$repo/docker.log"
    run bash -c "cd '$repo' && bash scripts/check-openapi-validation.sh --detailed -f '$repo/api/openapi.yaml'"

    [ "$status" -eq 1 ]
    docker_calls="$(cat "$DOCKER_LOG")"
    [[ "$docker_calls" == *"pythonopenapi/openapi-spec-validator /openapi.yaml"* ]]
    [[ "$docker_calls" == *"stoplight/spectral:latest lint /openapi.yaml"* ]]
}

@test "check-openapi-validation resolves .yaml to .json and calls docker with expected mount" {
    repo="$(make_temp_repo)"
    copy_openapi_scripts_into_repo "$repo"
    install_docker_stub "$repo"

    mkdir -p "$repo/api"
    cat >"$repo/api/openapi.json" <<'JSON'
{"openapi":"3.0.0","info":{"title":"JSON API","version":"1.0.0"},"paths":{}}
JSON

    export DOCKER_LOG="$repo/docker.log"
    run bash -c "cd '$repo' && bash scripts/check-openapi-validation.sh -f '$repo/api/openapi.yaml'"

    [ "$status" -eq 0 ]
    docker_call="$(cat "$DOCKER_LOG")"
    [[ "$docker_call" == *"-v $repo/api/openapi.json:/openapi.json"* ]]
    [[ "$docker_call" == *"pythonopenapi/openapi-spec-validator /openapi.json"* ]]
}

@test "check-openapi-validation accepts direct .yml input" {
    repo="$(make_temp_repo)"
    copy_openapi_scripts_into_repo "$repo"
    install_docker_stub "$repo"

    mkdir -p "$repo/api"
    cat >"$repo/api/openapi.yml" <<'YAML'
openapi: 3.0.0
info:
  title: YML API
  version: 1.0.0
paths: {}
YAML

    export DOCKER_LOG="$repo/docker.log"
    run bash -c "cd '$repo' && bash scripts/check-openapi-validation.sh -f '$repo/api/openapi.yml'"

    [ "$status" -eq 0 ]
    docker_call="$(cat "$DOCKER_LOG")"
    [[ "$docker_call" == *"-v $repo/api/openapi.yml:/openapi.yml"* ]]
    [[ "$docker_call" == *"pythonopenapi/openapi-spec-validator /openapi.yml"* ]]
}

@test "check-openapi-validation accepts direct .json input" {
    repo="$(make_temp_repo)"
    copy_openapi_scripts_into_repo "$repo"
    install_docker_stub "$repo"

    mkdir -p "$repo/api"
    cat >"$repo/api/openapi.json" <<'JSON'
{"openapi":"3.0.0","info":{"title":"Direct JSON API","version":"1.0.0"},"paths":{}}
JSON

    export DOCKER_LOG="$repo/docker.log"
    run bash -c "cd '$repo' && bash scripts/check-openapi-validation.sh -f '$repo/api/openapi.json'"

    [ "$status" -eq 0 ]
    docker_call="$(cat "$DOCKER_LOG")"
    [[ "$docker_call" == *"-v $repo/api/openapi.json:/openapi.json"* ]]
    [[ "$docker_call" == *"pythonopenapi/openapi-spec-validator /openapi.json"* ]]
}

@test "check-openapi-security exits successfully when OpenAPI path is missing" {
    repo="$(make_temp_repo)"
    copy_openapi_scripts_into_repo "$repo"
    install_docker_stub "$repo"

    export DOCKER_LOG="$repo/docker.log"
    run bash -c "cd '$repo' && bash scripts/check-openapi-security.sh -f '$repo/does-not-exist'"

    [ "$status" -eq 0 ]
    [[ "$output" == *"skipping security lint"* ]]
    [ ! -f "$DOCKER_LOG" ]
}

@test "check-openapi-security resolves .yml to .json and calls docker with expected mount" {
    repo="$(make_temp_repo)"
    copy_openapi_scripts_into_repo "$repo"
    install_docker_stub "$repo"

    mkdir -p "$repo/spec"
    cat >"$repo/spec/openapi.json" <<'JSON'
{"openapi":"3.0.0","info":{"title":"Security JSON API","version":"1.0.0"},"paths":{}}
JSON

    export DOCKER_LOG="$repo/docker.log"
    run bash -c "cd '$repo' && bash scripts/check-openapi-security.sh -f '$repo/spec/openapi.yml'"

    [ "$status" -eq 0 ]
    docker_call="$(cat "$DOCKER_LOG")"
    [[ "$docker_call" == *"-v $repo/spec/openapi.json:/app/openapi.json"* ]]
    [[ "$docker_call" == *"stoplight/spectral:latest lint /app/openapi.json"* ]]
    [[ "$docker_call" == *"--ruleset /tmp/spectral-security-ruleset.yaml"* ]]
}

@test "check-openapi-security accepts direct .yml input" {
    repo="$(make_temp_repo)"
    copy_openapi_scripts_into_repo "$repo"
    install_docker_stub "$repo"

    mkdir -p "$repo/spec"
    cat >"$repo/spec/openapi.yml" <<'YAML'
openapi: 3.0.0
info:
  title: Security YML API
  version: 1.0.0
paths: {}
YAML

    export DOCKER_LOG="$repo/docker.log"
    run bash -c "cd '$repo' && bash scripts/check-openapi-security.sh -f '$repo/spec/openapi.yml'"

    [ "$status" -eq 0 ]
    docker_call="$(cat "$DOCKER_LOG")"
    [[ "$docker_call" == *"-v $repo/spec/openapi.yml:/app/openapi.yml"* ]]
    [[ "$docker_call" == *"stoplight/spectral:latest lint /app/openapi.yml"* ]]
}

@test "check-openapi-security with directory uses openapi.json when yaml/yml are absent" {
    repo="$(make_temp_repo)"
    copy_openapi_scripts_into_repo "$repo"
    install_docker_stub "$repo"

    mkdir -p "$repo/openapi"
    cat >"$repo/openapi/openapi.json" <<'JSON'
{"openapi":"3.0.0","info":{"title":"Security Dir JSON API","version":"1.0.0"},"paths":{}}
JSON

    export DOCKER_LOG="$repo/docker.log"
    run bash -c "cd '$repo' && bash scripts/check-openapi-security.sh -f '$repo/openapi'"

    [ "$status" -eq 0 ]
    docker_call="$(cat "$DOCKER_LOG")"
    [[ "$docker_call" == *"-v $repo/openapi/openapi.json:/app/openapi.json"* ]]
    [[ "$docker_call" == *"stoplight/spectral:latest lint /app/openapi.json"* ]]
}

@test "run-openapi-docker mounts parent directory for file input and respects name/port" {
    repo="$(make_temp_repo)"
    copy_openapi_scripts_into_repo "$repo"
    install_docker_stub "$repo"

    mkdir -p "$repo/spec"
    cat >"$repo/spec/openapi.yaml" <<'YAML'
openapi: 3.0.0
info:
  title: Preview API
  version: 1.0.0
paths: {}
YAML

    export DOCKER_LOG="$repo/docker.log"
    run bash -c "cd '$repo' && bash scripts/run-openapi-docker.sh -n preview -p 9999:80 -f '$repo/spec/openapi.yaml'"

    [ "$status" -eq 0 ]
    docker_call="$(cat "$DOCKER_LOG")"
    [[ "$docker_call" == *"--name preview"* ]]
    [[ "$docker_call" == *"-v $repo/spec:/usr/share/nginx/html"* ]]
    [[ "$docker_call" == *"-p 9999:80 nginx"* ]]
}

@test "run-openapi-docker resolves .yaml to .json and mounts parent directory" {
    repo="$(make_temp_repo)"
    copy_openapi_scripts_into_repo "$repo"
    install_docker_stub "$repo"

    mkdir -p "$repo/spec"
    cat >"$repo/spec/openapi.json" <<'JSON'
{"openapi":"3.0.0","info":{"title":"Preview JSON API","version":"1.0.0"},"paths":{}}
JSON

    export DOCKER_LOG="$repo/docker.log"
    run bash -c "cd '$repo' && bash scripts/run-openapi-docker.sh -f '$repo/spec/openapi.yaml'"

    [ "$status" -eq 0 ]
    docker_call="$(cat "$DOCKER_LOG")"
    [[ "$docker_call" == *"-v $repo/spec:/usr/share/nginx/html"* ]]
}

@test "run-openapi-docker accepts direct .yml input and mounts parent directory" {
    repo="$(make_temp_repo)"
    copy_openapi_scripts_into_repo "$repo"
    install_docker_stub "$repo"

    mkdir -p "$repo/spec"
    cat >"$repo/spec/openapi.yml" <<'YAML'
openapi: 3.0.0
info:
  title: Preview YML API
  version: 1.0.0
paths: {}
YAML

    export DOCKER_LOG="$repo/docker.log"
    run bash -c "cd '$repo' && bash scripts/run-openapi-docker.sh -f '$repo/spec/openapi.yml'"

    [ "$status" -eq 0 ]
    docker_call="$(cat "$DOCKER_LOG")"
    [[ "$docker_call" == *"-v $repo/spec:/usr/share/nginx/html"* ]]
}

@test "run-openapi-docker accepts direct .json input and mounts parent directory" {
    repo="$(make_temp_repo)"
    copy_openapi_scripts_into_repo "$repo"
    install_docker_stub "$repo"

    mkdir -p "$repo/spec"
    cat >"$repo/spec/openapi.json" <<'JSON'
{"openapi":"3.0.0","info":{"title":"Preview Direct JSON API","version":"1.0.0"},"paths":{}}
JSON

    export DOCKER_LOG="$repo/docker.log"
    run bash -c "cd '$repo' && bash scripts/run-openapi-docker.sh -f '$repo/spec/openapi.json'"

    [ "$status" -eq 0 ]
    docker_call="$(cat "$DOCKER_LOG")"
    [[ "$docker_call" == *"-v $repo/spec:/usr/share/nginx/html"* ]]
}

@test "check-openapi-validation with directory prefers openapi.yaml over openapi.yml" {
    repo="$(make_temp_repo)"
    copy_openapi_scripts_into_repo "$repo"
    install_docker_stub "$repo"

    mkdir -p "$repo/openapi"
    cat >"$repo/openapi/openapi.yaml" <<'YAML'
openapi: 3.0.0
info: {title: YAML, version: 1.0.0}
paths: {}
YAML
    cat >"$repo/openapi/openapi.yml" <<'YAML'
openapi: 3.0.0
info: {title: YML, version: 1.0.0}
paths: {}
YAML

    export DOCKER_LOG="$repo/docker.log"
    run bash -c "cd '$repo' && bash scripts/check-openapi-validation.sh -f '$repo/openapi'"

    [ "$status" -eq 0 ]
    docker_call="$(cat "$DOCKER_LOG")"
    [[ "$docker_call" == *"-v $repo/openapi/openapi.yaml:/openapi.yaml"* ]]
}

@test "check-openapi-validation with directory uses openapi.json when yaml/yml are absent" {
    repo="$(make_temp_repo)"
    copy_openapi_scripts_into_repo "$repo"
    install_docker_stub "$repo"

    mkdir -p "$repo/openapi"
    cat >"$repo/openapi/openapi.json" <<'JSON'
{"openapi":"3.0.0","info":{"title":"JSON Dir API","version":"1.0.0"},"paths":{}}
JSON

    export DOCKER_LOG="$repo/docker.log"
    run bash -c "cd '$repo' && bash scripts/check-openapi-validation.sh -f '$repo/openapi'"

    [ "$status" -eq 0 ]
    docker_call="$(cat "$DOCKER_LOG")"
    [[ "$docker_call" == *"-v $repo/openapi/openapi.json:/openapi.json"* ]]
}

@test "check-openapi-validation exits successfully when directory has no openapi spec" {
    repo="$(make_temp_repo)"
    copy_openapi_scripts_into_repo "$repo"
    install_docker_stub "$repo"

    mkdir -p "$repo/openapi-empty"
    export DOCKER_LOG="$repo/docker.log"
    run bash -c "cd '$repo' && bash scripts/check-openapi-validation.sh -f '$repo/openapi-empty'"

    [ "$status" -eq 0 ]
    [[ "$output" == *"skipping validation"* ]]
    [ ! -f "$DOCKER_LOG" ]
}

@test "check-openapi-security returns non-zero when docker scan fails" {
    repo="$(make_temp_repo)"
    copy_openapi_scripts_into_repo "$repo"
    install_docker_stub "$repo"

    mkdir -p "$repo/openapi"
    cat >"$repo/openapi/openapi.yaml" <<'YAML'
openapi: 3.0.0
info:
  title: Test API
  version: 1.0.0
paths: {}
YAML

    export DOCKER_LOG="$repo/docker.log"
    export DOCKER_EXIT_CODE=1
    run bash -c "cd '$repo' && bash scripts/check-openapi-security.sh -f '$repo/openapi/openapi.yaml'"

    [ "$status" -eq 1 ]
    docker_call="$(cat "$DOCKER_LOG")"
    [[ "$docker_call" == *"stoplight/spectral:latest lint /app/openapi.yaml"* ]]
}

@test "check-openapi-validation resolves default openapi path from repo root when run from subdirectory" {
    repo="$(make_temp_repo)"
    copy_openapi_scripts_into_repo "$repo"
    install_docker_stub "$repo"

    mkdir -p "$repo/openapi" "$repo/subdir"
    cat >"$repo/openapi/openapi.yaml" <<'YAML'
openapi: 3.0.0
info:
  title: Root API
  version: 1.0.0
paths: {}
YAML

    export DOCKER_LOG="$repo/docker.log"
    run bash -c "cd '$repo/subdir' && bash ../scripts/check-openapi-validation.sh"

    [ "$status" -eq 0 ]
    docker_call="$(cat "$DOCKER_LOG")"
    [[ "$docker_call" == *"/openapi/openapi.yaml:/openapi.yaml"* ]]
}

@test "check-openapi-validation works when script is piped to bash" {
    repo="$(make_temp_repo)"
    copy_openapi_scripts_into_repo "$repo"
    install_docker_stub "$repo"

    mkdir -p "$repo/openapi"
    cat >"$repo/openapi/openapi.yaml" <<'YAML'
openapi: 3.0.0
info:
  title: Pipe API
  version: 1.0.0
paths: {}
YAML

    export DOCKER_LOG="$repo/docker.log"
    run bash -c "cd '$repo' && cat scripts/check-openapi-validation.sh | bash"

    [ "$status" -eq 0 ]
    docker_call="$(cat "$DOCKER_LOG")"
    [[ "$docker_call" == *"/openapi/openapi.yaml:/openapi.yaml"* ]]
}

@test "check-openapi-validation supports piped execution with -f path relative to git root" {
    repo="$(make_temp_repo)"
    copy_openapi_scripts_into_repo "$repo"
    install_docker_stub "$repo"

    mkdir -p "$repo/mail-examples/mail-example-openapi/openapi"
    cat >"$repo/mail-examples/mail-example-openapi/openapi/openapi.yaml" <<'YAML'
openapi: 3.0.0
info:
  title: Nested API
  version: 1.0.0
paths: {}
YAML

    export DOCKER_LOG="$repo/docker.log"
    run bash -c "cd '$repo' && cat scripts/check-openapi-validation.sh | bash -s -- -f mail-examples/mail-example-openapi/openapi/openapi.yaml"

    [ "$status" -eq 0 ]
    docker_call="$(cat "$DOCKER_LOG")"
    [[ "$docker_call" == *"/mail-examples/mail-example-openapi/openapi/openapi.yaml:/openapi.yaml"* ]]
}

@test "check-openapi-validation default path works for copied script in nested project scripts folder" {
    repo="$(make_temp_repo)"
    install_docker_stub "$repo"

    mkdir -p "$repo/mail-examples/mail-example-openapi/scripts"
    mkdir -p "$repo/mail-examples/mail-example-openapi/openapi"
    cp "$PROJECT_ROOT/scripts/check-openapi-validation.sh" \
        "$repo/mail-examples/mail-example-openapi/scripts/check-openapi-validation.sh"
    chmod +x "$repo/mail-examples/mail-example-openapi/scripts/check-openapi-validation.sh"

    cat >"$repo/mail-examples/mail-example-openapi/openapi/openapi.yaml" <<'YAML'
openapi: 3.0.0
info:
  title: Nested Local API
  version: 1.0.0
paths: {}
YAML

    export DOCKER_LOG="$repo/docker.log"
    run bash -c "cd '$repo/mail-examples/mail-example-openapi' && bash ./scripts/check-openapi-validation.sh"

    [ "$status" -eq 0 ]
    docker_call="$(cat "$DOCKER_LOG")"
    [[ "$docker_call" == *"/mail-example-openapi/openapi/openapi.yaml:/openapi.yaml"* ]]
}
