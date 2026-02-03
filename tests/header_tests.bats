#!/usr/bin/env bats

setup() {
  ROOT_TMP="$(mktemp -d)"
  TMPDIR="$ROOT_TMP/github-workflows"

  mkdir -p "$TMPDIR/scripts"

  # Resolve repo root reliably
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"

  # Copy script under test
  cp "$REPO_ROOT/scripts/check-swift-headers.sh" \
     "$TMPDIR/scripts/check-swift-headers.sh"
  chmod +x "$TMPDIR/scripts/check-swift-headers.sh"
}

teardown() {
  rm -rf "$ROOT_TMP"
}

run_checker() {
  ( cd "$TMPDIR" && ./scripts/check-swift-headers.sh "$@" )
}

init_git() {
  git init -q "$TMPDIR"
  git -C "$TMPDIR" add .

  GIT_AUTHOR_DATE="2026-01-01T12:00:00Z" \
  GIT_COMMITTER_DATE="2026-01-01T12:00:00Z" \
    git -C "$TMPDIR" commit -qm "init"
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
}

@test "missing header fails in check mode" {
  cp "$REPO_ROOT/tests/fixtures/missing_header.swift" \
     "$TMPDIR/Foo.swift"

  init_git

  run run_checker
  [ "$status" -ne 0 ]
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