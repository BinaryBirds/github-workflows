#!/usr/bin/env bats

load 'helpers/test_helper.bash'

@test "check-unacceptable-language passes when no banned terms exist" {
    repo="$(make_temp_repo)"
    copy_script_into_repo "$repo" "check-unacceptable-language.sh"

    cat >"$repo/good.txt" <<'TXT'
This file uses inclusive and neutral wording.
TXT
    commit_all "$repo"

    cat >"$repo/.unacceptablelanguageignore" <<'TXT'
scripts/check-unacceptable-language.sh
TXT
    commit_all "$repo" "add ignore file"

    run bash -c "cd '$repo' && bash scripts/check-unacceptable-language.sh"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Found no unacceptable language"* ]]
}

@test "check-unacceptable-language fails when banned terms exist" {
    repo="$(make_temp_repo)"
    copy_script_into_repo "$repo" "check-unacceptable-language.sh"

    cat >"$repo/bad.txt" <<'TXT'
This line contains blacklist and should fail.
TXT
    commit_all "$repo"

    run bash -c "cd '$repo' && bash scripts/check-unacceptable-language.sh"

    [ "$status" -eq 1 ]
    [[ "$output" == *"Found unacceptable language"* ]]
    [[ "$output" == *"bad.txt"* ]]
}

@test "check-unacceptable-language respects .unacceptablelanguageignore" {
    repo="$(make_temp_repo)"
    copy_script_into_repo "$repo" "check-unacceptable-language.sh"

    cat >"$repo/bad.txt" <<'TXT'
This line contains blacklist.
TXT
    cat >"$repo/.unacceptablelanguageignore" <<'TXT'
bad.txt
scripts/check-unacceptable-language.sh
TXT
    commit_all "$repo"

    run bash -c "cd '$repo' && bash scripts/check-unacceptable-language.sh"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Found no unacceptable language"* ]]
}

@test "check-unacceptable-language ignores lines with ignore-unacceptable-language marker" {
    repo="$(make_temp_repo)"
    copy_script_into_repo "$repo" "check-unacceptable-language.sh"

    cat >"$repo/allowed.txt" <<'TXT'
blacklist // ignore-unacceptable-language
TXT
    cat >"$repo/.unacceptablelanguageignore" <<'TXT'
scripts/check-unacceptable-language.sh
TXT
    commit_all "$repo"

    run bash -c "cd '$repo' && bash scripts/check-unacceptable-language.sh"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Found no unacceptable language"* ]]
}

@test "check-unacceptable-language handles an empty ignore file" {
    repo="$(make_temp_repo)"
    copy_script_into_repo "$repo" "check-unacceptable-language.sh"

    cat >"$repo/good.txt" <<'TXT'
Inclusive wording only.
TXT
    : >"$repo/.unacceptablelanguageignore"
    git -C "$repo" add good.txt .unacceptablelanguageignore
    git -C "$repo" commit -q -m "add fixtures"

    run bash -c "cd '$repo' && bash scripts/check-unacceptable-language.sh"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Found no unacceptable language"* ]]
}

@test "check-unacceptable-language matches whole words only" {
    repo="$(make_temp_repo)"
    copy_script_into_repo "$repo" "check-unacceptable-language.sh"

    cat >"$repo/words.txt" <<'TXT'
mastery and blacklisting should not match whole-word checks.
TXT
    git -C "$repo" add words.txt
    git -C "$repo" commit -q -m "add words fixture"

    run bash -c "cd '$repo' && bash scripts/check-unacceptable-language.sh"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Found no unacceptable language"* ]]
}
