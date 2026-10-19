#!/usr/bin/env bats

load 'helpers/test_helper.bash'

@test "generate-docc restores Package.swift after failure without a placeholder" {
    repo="$(make_temp_repo)"
    copy_script_into_repo "$repo" "generate-docc.sh"

    cat >"$repo/Package.swift" <<'SWIFT'
// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "DocCTest",
    dependencies: [
    ],
    targets: [
        .target(name: "DocCTest")
    ]
)
SWIFT
    echo "DocCTest" >"$repo/.docctargetlist"
    commit_all "$repo"

    mkdir -p "$repo/fakebin"
    cat >"$repo/fakebin/swift" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
if [[ "$*" == "package dump-package" ]]; then
  cat <<'JSON'
{"targets":[{"type":"regular","name":"DocCTest"}]}
JSON
  exit 0
fi
if [[ "$*" == "package add-dependency "* ]]; then
  printf '\n// temporary DocC dependency\n' >> Package.swift
  exit 0
fi
if [[ "$*" == *"generate-documentation"* ]]; then
  exit 1
fi
exit 0
STUB
    chmod +x "$repo/fakebin/swift"
    export PATH="$repo/fakebin:$PATH"

    run bash -c "cd '$repo' && bash scripts/generate-docc.sh"

    [ "$status" -eq 1 ]
    run bash -c "grep -q 'temporary DocC dependency' '$repo/Package.swift'"
    [ "$status" -eq 1 ]
}

@test "generate-docc deploy generation works without a placeholder and restores Package.swift" {
    repo="$(make_temp_repo)"
    copy_script_into_repo "$repo" "generate-docc.sh"

    cat >"$repo/Package.swift" <<'SWIFT'
// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "DocCTest",
    dependencies: [],
    targets: [
        .target(name: "DocCTest")
    ]
)
SWIFT
    echo "DocCTest" >"$repo/.docctargetlist"
    commit_all "$repo"

    mkdir -p "$repo/fakebin"
    cat >"$repo/fakebin/swift" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
if [[ "$*" == "package add-dependency "* ]]; then
  printf '\n// temporary DocC dependency\n' >> Package.swift
  exit 0
fi
if [[ "$*" == "package dump-package" ]]; then
  cat <<'JSON'
{"targets":[{"type":"regular","name":"DocCTest"}]}
JSON
  exit 0
fi
if [[ "$*" == *"generate-documentation"* ]]; then
  while [[ $# -gt 0 ]]; do
    if [[ "$1" == "--output-path" ]]; then
      mkdir -p "$2/documentation/DocCTest"
      printf '<html></html>\n' >"$2/documentation/DocCTest/index.html"
      exit 0
    fi
    shift
  done
  exit 1
fi
exit 1
STUB
    chmod +x "$repo/fakebin/swift"
    export PATH="$repo/fakebin:$PATH"

    run bash -c "cd '$repo' && bash scripts/generate-docc.sh --name DocCTest"

    [ "$status" -eq 0 ]
    [ -f "$repo/docs/index.html" ]
    [ -f "$repo/docs/documentation/index.html" ]
    run bash -c "grep -q 'temporary DocC dependency' '$repo/Package.swift'"
    [ "$status" -eq 1 ]
}
