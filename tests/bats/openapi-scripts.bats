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

@test "check-openapi-security exits successfully when OpenAPI path is missing" {
    repo="$(make_temp_repo)"
    copy_openapi_scripts_into_repo "$repo"
    install_docker_stub "$repo"

    export DOCKER_LOG="$repo/docker.log"
    run bash -c "cd '$repo' && bash scripts/check-openapi-security.sh -f '$repo/does-not-exist'"

    [ "$status" -eq 0 ]
    [[ "$output" == *"skipping security scan"* ]]
    [ ! -f "$DOCKER_LOG" ]
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
    [[ "$docker_call" == *"zap-api-scan.py"* ]]
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
