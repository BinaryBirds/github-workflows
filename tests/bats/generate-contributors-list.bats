#!/usr/bin/env bats

load 'helpers/test_helper.bash'

@test "generate-contributors-list creates CONTRIBUTORS.txt from git history" {
  repo="$(make_temp_repo)"
  copy_script_into_repo "$repo" "generate-contributors-list.sh"

  cat > "$repo/file.txt" <<'TXT'
content
TXT
  commit_all "$repo"

  run bash -c "cd '$repo' && bash scripts/generate-contributors-list.sh"

  [ "$status" -eq 0 ]
  [ -f "$repo/CONTRIBUTORS.txt" ]

  contributors_content="$(cat "$repo/CONTRIBUTORS.txt")"
  [[ "$contributors_content" == *"### Contributors"* ]]
  [[ "$contributors_content" == *"Test User <test@example.com>"* ]]
}

@test "generate-contributors-list exits cleanly in repository with no commits" {
  repo="$(make_temp_repo)"
  copy_script_into_repo "$repo" "generate-contributors-list.sh"

  run bash -c "cd '$repo' && bash scripts/generate-contributors-list.sh"

  [ "$status" -eq 0 ]
  [[ "$output" == *"No contributors found"* ]]
  [ ! -f "$repo/CONTRIBUTORS.txt" ]
}

@test "generate-contributors-list writes CONTRIBUTORS.txt at repo root from subdirectory" {
  repo="$(make_temp_repo)"
  copy_script_into_repo "$repo" "generate-contributors-list.sh"
  mkdir -p "$repo/subdir"

  cat > "$repo/file.txt" <<'TXT'
content
TXT
  commit_all "$repo"

  run bash -c "cd '$repo/subdir' && bash ../scripts/generate-contributors-list.sh"

  [ "$status" -eq 0 ]
  [ -f "$repo/CONTRIBUTORS.txt" ]
}

@test "generate-contributors-list output includes mailmap guidance" {
  repo="$(make_temp_repo)"
  copy_script_into_repo "$repo" "generate-contributors-list.sh"

  cat > "$repo/file.txt" <<'TXT'
content
TXT
  commit_all "$repo"

  run bash -c "cd '$repo' && bash scripts/generate-contributors-list.sh"

  [ "$status" -eq 0 ]
  contributors_content="$(cat "$repo/CONTRIBUTORS.txt")"
  [[ "$contributors_content" == *"./.mailmap"* ]]
}
