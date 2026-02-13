#!/usr/bin/env bats

load 'helpers/test_helper.bash'

@test "check-local-swift-dependencies passes when no .package(path:) is present" {
    repo="$(make_temp_repo)"
    copy_script_into_repo "$repo" "check-local-swift-dependencies.sh"

    cat >"$repo/Package.swift" <<'SWIFT'
// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "Demo",
    dependencies: [
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.0.0")
    ],
    targets: []
)
SWIFT
    commit_all "$repo"

    run bash -c "cd '$repo' && bash scripts/check-local-swift-dependencies.sh"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Found 0 local Swift package dependency references"* ]]
}

@test "check-local-swift-dependencies fails when .package(path:) exists" {
    repo="$(make_temp_repo)"
    copy_script_into_repo "$repo" "check-local-swift-dependencies.sh"

    cat >"$repo/Package.swift" <<'SWIFT'
// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "Demo",
    dependencies: [
        .package(path: "../LocalPackage")
    ],
    targets: []
)
SWIFT
    commit_all "$repo"

    run bash -c "cd '$repo' && bash scripts/check-local-swift-dependencies.sh"

    [ "$status" -eq 1 ]
    [[ "$output" == *"contains local Swift package reference"* ]]
}

@test "check-local-swift-dependencies ignores untracked Package.swift" {
    repo="$(make_temp_repo)"
    copy_script_into_repo "$repo" "check-local-swift-dependencies.sh"

    cat >"$repo/Package.swift" <<'SWIFT'
// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "Demo",
    dependencies: [
        .package(path: "../LocalPackage")
    ],
    targets: []
)
SWIFT
    cat >"$repo/README.md" <<'TXT'
fixture
TXT
    git -C "$repo" add README.md
    git -C "$repo" commit -q -m "tracked file only"

    run bash -c "cd '$repo' && bash scripts/check-local-swift-dependencies.sh"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Found 0 local Swift package dependency references"* ]]
}

@test "check-local-swift-dependencies passes when no Package.swift is tracked" {
    repo="$(make_temp_repo)"
    copy_script_into_repo "$repo" "check-local-swift-dependencies.sh"

    cat >"$repo/README.md" <<'TXT'
fixture
TXT
    git -C "$repo" add README.md
    git -C "$repo" commit -q -m "no package swift"

    run bash -c "cd '$repo' && bash scripts/check-local-swift-dependencies.sh"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Found 0 local Swift package dependency references"* ]]
}
