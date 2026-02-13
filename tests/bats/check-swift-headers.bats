#!/usr/bin/env bats

load 'helpers/test_helper.bash'

REPO_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd)"

setup() {
    TMP_ROOT="$(mktemp -d)"
    TMPDIR="$TMP_ROOT/HeaderProject"
    mkdir -p "$TMPDIR"

    copy_script_into_repo "$TMPDIR" "check-swift-headers.sh"
}

teardown() {
    rm -rf "$TMP_ROOT"
}

init_git() {
    git -C "$TMPDIR" init -q
    git -C "$TMPDIR" config user.name "Test User"
    git -C "$TMPDIR" config user.email "test@example.com"
    git -C "$TMPDIR" add -A
    GIT_AUTHOR_DATE="2026-02-12T12:00:00Z" \
        GIT_COMMITTER_DATE="2026-02-12T12:00:00Z" \
        git -C "$TMPDIR" commit -q -m "init fixtures"
}

run_checker() {
    (cd "$TMPDIR" && bash scripts/check-swift-headers.sh "$@")
}

@test "valid header with single dot passes without changes" {
    cp "$REPO_ROOT/tests/fixtures/valid_single_dot.swift" \
        "$TMPDIR/Address.swift"

    init_git

    run run_checker
    [ "$status" -eq 0 ]

    diff -u \
        "$REPO_ROOT/tests/fixtures/valid_single_dot.swift" \
        "$TMPDIR/Address.swift"
}

@test "legacy double-dot header is normalized but not duplicated" {
    cp "$REPO_ROOT/tests/fixtures/legacy_double_dot.swift" \
        "$TMPDIR/Address.swift"

    init_git

    run run_checker --fix
    [ "$status" -eq 0 ]

    diff -u \
        "$REPO_ROOT/tests/fixtures/legacy_double_dot_fixed.swift" \
        "$TMPDIR/Address.swift"

    run run_checker
    [ "$status" -eq 0 ]
}

@test "wrong project name is fixed but author and date are preserved" {
    cp "$REPO_ROOT/tests/fixtures/wrong_project.swift" \
        "$TMPDIR/WrongProject.swift"

    init_git

    run run_checker --fix
    [ "$status" -eq 0 ]

    diff -u \
        "$REPO_ROOT/tests/fixtures/wrong_project_fixed.swift" \
        "$TMPDIR/WrongProject.swift"

    run run_checker
    [ "$status" -eq 0 ]
}

@test "wrong project name fails in check mode" {
    cp "$REPO_ROOT/tests/fixtures/wrong_project.swift" \
        "$TMPDIR/WrongProject.swift"

    init_git

    run run_checker
    [ "$status" -ne 0 ]
    [[ "$output" == *"Header is invalid"* ]]
}

@test "missing header fails in check mode" {
    cp "$REPO_ROOT/tests/fixtures/missing_header.swift" \
        "$TMPDIR/Foo.swift"

    init_git

    run run_checker
    [ "$status" -ne 0 ]
}

@test "missing header with leading random comments fails in check mode" {
    cat >"$TMPDIR/Foo.swift" <<'EOF2'
// random comment one
// random comment two
import Foundation

struct Foo {
    let value: Int
}
EOF2

    init_git

    run run_checker
    [ "$status" -ne 0 ]
    [[ "$output" == *"Header missing"* ]]
}

@test "missing header is inserted in fix mode" {
    cp "$REPO_ROOT/tests/fixtures/missing_header.swift" \
        "$TMPDIR/Foo.swift"

    init_git

    run run_checker --fix
    [ "$status" -eq 0 ]

    diff -u \
        "$REPO_ROOT/tests/fixtures/missing_header_fixed.swift" \
        "$TMPDIR/Foo.swift"

    run run_checker
    [ "$status" -eq 0 ]
}

@test "missing header with leading random comments is fixed in fix mode" {
    cat >"$TMPDIR/Foo.swift" <<'EOF2'
// random comment one
// random comment two
import Foundation

struct Foo {
    let value: Int
}
EOF2

    init_git

    run run_checker --fix
    [ "$status" -eq 0 ]

    content="$(cat "$TMPDIR/Foo.swift")"
    [[ "$content" == *"//  Foo.swift"* ]]
    [[ "$content" == *"//  Created by Binary Birds on"* ]]
    [[ "$content" == *"// random comment one"* ]]
    [[ "$content" == *"// random comment two"* ]]

    run run_checker
    [ "$status" -eq 0 ]
}

@test "fix mode is idempotent" {
    cp "$REPO_ROOT/tests/fixtures/legacy_double_dot.swift" \
        "$TMPDIR/Address.swift"

    init_git

    run run_checker --fix
    [ "$status" -eq 0 ]

    cp "$TMPDIR/Address.swift" "$TMPDIR/once.swift"

    run run_checker --fix
    [ "$status" -eq 0 ]

    diff -u "$TMPDIR/once.swift" "$TMPDIR/Address.swift"
}

@test "--author without value fails with clear error" {
    cp "$REPO_ROOT/tests/fixtures/missing_header.swift" \
        "$TMPDIR/Foo.swift"

    init_git

    run run_checker --fix --author
    [ "$status" -ne 0 ]
    [[ "$output" == *"--author requires a value"* ]]
}

@test "unknown argument fails with clear error" {
    cp "$REPO_ROOT/tests/fixtures/missing_header.swift" \
        "$TMPDIR/Foo.swift"

    init_git

    run run_checker --unknown
    [ "$status" -ne 0 ]
    [[ "$output" == *"Unknown argument: --unknown"* ]]
}

@test "Package.swift is skipped even without header" {
    cat >"$TMPDIR/Package.swift" <<'EOF2'
// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "HeaderProject",
    targets: []
)
EOF2
    cp "$REPO_ROOT/tests/fixtures/valid_single_dot.swift" \
        "$TMPDIR/Address.swift"

    init_git

    run run_checker
    [ "$status" -eq 0 ]
}

@test "invalid header fails in check mode" {
    cat >"$TMPDIR/Bad.swift" <<'EOF2'
//
//  WrongName.swift
//  HeaderProject
//
//  Created by Test User on 2026. 02. 12.

struct Bad {}
EOF2

    init_git

    run run_checker
    [ "$status" -ne 0 ]
    [[ "$output" == *"Header is invalid"* ]]
}

@test "invalid header is fixed while preserving author and date" {
    cat >"$TMPDIR/Preserve.swift" <<'EOF2'
//
//  WrongName.swift
//  WrongProject
//
//  Created by Alice Doe on 2026. 02. 12.

struct Preserve {}
EOF2

    init_git

    run run_checker --fix
    [ "$status" -eq 0 ]

    content="$(cat "$TMPDIR/Preserve.swift")"
    [[ "$content" == *"//  Preserve.swift"* ]]
    [[ "$content" == *"//  HeaderProject"* ]]
    [[ "$content" == *"//  Created by Alice Doe on 2026. 02. 12."* ]]

    run run_checker
    [ "$status" -eq 0 ]
}

@test ".swiftheaderignore supports comments and blank lines" {
    cp "$REPO_ROOT/tests/fixtures/missing_header.swift" \
        "$TMPDIR/Ignored.swift"
    cp "$REPO_ROOT/tests/fixtures/valid_single_dot.swift" \
        "$TMPDIR/Address.swift"
    cat >"$TMPDIR/.swiftheaderignore" <<'EOF2'
# Ignore this swift file
Ignored.swift

# Also ignore helper shell scripts
scripts/**
.swiftheaderignore
EOF2

    init_git

    run run_checker
    [ "$status" -eq 0 ]
}

@test "running from subdirectory behaves the same" {
    mkdir -p "$TMPDIR/Sources"
    cp "$REPO_ROOT/tests/fixtures/missing_header.swift" \
        "$TMPDIR/Sources/Foo.swift"

    init_git

    run bash -c "cd '$TMPDIR/Sources' && ../scripts/check-swift-headers.sh"
    [ "$status" -ne 0 ]
    [[ "$output" == *"Header missing"* ]]
}
