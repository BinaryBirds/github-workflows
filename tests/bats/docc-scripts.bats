#!/usr/bin/env bats

load 'helpers/test_helper.bash'

@test "check-docc-warnings restores Package.swift when analysis fails after plugin injection" {
    repo="$(make_temp_repo)"
    copy_script_into_repo "$repo" "check-docc-warnings.sh"

    cat >"$repo/Package.swift" <<'SWIFT'
// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "DocCTest",
    dependencies: [
        // [docc-plugin-placeholder]
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
if [[ "$*" == *"plugin generate-documentation"* ]]; then
  exit 1
fi
exit 0
STUB
    chmod +x "$repo/fakebin/swift"
    export PATH="$repo/fakebin:$PATH"

    run bash -c "cd '$repo' && bash scripts/check-docc-warnings.sh"

    [ "$status" -eq 1 ]
    run bash -c "grep -q 'swift-docc-plugin' '$repo/Package.swift'"
    [ "$status" -eq 1 ]
}

@test "generate-docc restores Package.swift when generation fails after plugin injection" {
    repo="$(make_temp_repo)"
    copy_script_into_repo "$repo" "generate-docc.sh"

    cat >"$repo/Package.swift" <<'SWIFT'
// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "DocCTest",
    dependencies: [
        // [docc-plugin-placeholder]
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
if [[ "$*" == *"generate-documentation"* ]]; then
  exit 1
fi
exit 0
STUB
    chmod +x "$repo/fakebin/swift"
    export PATH="$repo/fakebin:$PATH"

    run bash -c "cd '$repo' && bash scripts/generate-docc.sh"

    [ "$status" -eq 1 ]
    run bash -c "grep -q 'swift-docc-plugin' '$repo/Package.swift'"
    [ "$status" -eq 1 ]
}
