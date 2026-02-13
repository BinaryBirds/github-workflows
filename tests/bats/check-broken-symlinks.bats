#!/usr/bin/env bats

load 'helpers/test_helper.bash'

@test "check-broken-symlinks passes when all symlinks are valid" {
  repo="$(make_temp_repo)"
  copy_script_into_repo "$repo" "check-broken-symlinks.sh"

  cat > "$repo/target.txt" <<'TXT'
hello
TXT
  ln -s target.txt "$repo/link.txt"
  commit_all "$repo"

  run bash -c "cd '$repo' && bash scripts/check-broken-symlinks.sh"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Found 0 broken symlinks"* ]]
}

@test "check-broken-symlinks fails when symlink target is missing" {
  repo="$(make_temp_repo)"
  copy_script_into_repo "$repo" "check-broken-symlinks.sh"

  ln -s missing.txt "$repo/broken.txt"
  commit_all "$repo"

  run bash -c "cd '$repo' && bash scripts/check-broken-symlinks.sh"

  [ "$status" -eq 1 ]
  [[ "$output" == *"Broken symlink: broken.txt"* ]]
}

@test "check-broken-symlinks ignores regular files even if they mention missing paths" {
  repo="$(make_temp_repo)"
  copy_script_into_repo "$repo" "check-broken-symlinks.sh"

  cat > "$repo/notes.txt" <<'TXT'
This mentions a missing file path: ./does-not-exist.txt
TXT
  commit_all "$repo"

  run bash -c "cd '$repo' && bash scripts/check-broken-symlinks.sh"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Found 0 broken symlinks"* ]]
}

@test "check-broken-symlinks checks only tracked symlinks" {
  repo="$(make_temp_repo)"
  copy_script_into_repo "$repo" "check-broken-symlinks.sh"

  cat > "$repo/tracked.txt" <<'TXT'
ok
TXT
  git -C "$repo" add tracked.txt
  git -C "$repo" commit -q -m "baseline"
  ln -s missing.txt "$repo/untracked-broken.txt"

  run bash -c "cd '$repo' && bash scripts/check-broken-symlinks.sh"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Found 0 broken symlinks"* ]]
}
