#!/usr/bin/env bats

load 'helpers/test_helper.bash'

setup_valid_swift_package_layout() {
  local repo="$1"
  local year
  year="$(date +%Y)"

  mkdir -p "$repo/Sources/Demo" "$repo/Tests/DemoTests"
  cat > "$repo/.swift-format" <<'EOF'
{}
EOF
  : > "$repo/.swiftformatignore"
  cat > "$repo/Makefile" <<'EOF'
all:
	@echo ok
EOF
  cat > "$repo/README.md" <<'EOF'
# Demo
EOF
  cat > "$repo/LICENSE" <<EOF
Copyright ${year}
EOF
}

write_valid_package_swift() {
  local repo="$1"
  cat > "$repo/Package.swift" <<'EOF'
// swift-tools-version: 6.1
import PackageDescription

let defaultSwiftSettings: [SwiftSetting] = [
    .enableUpcomingFeature("NonisolatedNonsendingByDefault")
]

let package = Package(
    name: "Demo",
    products: [
        .library(name: "Demo", targets: ["Demo"])
    ],
    dependencies: [
        // [docc-plugin-placeholder]
    ],
    targets: [
        .target(
            name: "Demo",
            swiftSettings: defaultSwiftSettings
        ),
        .testTarget(
            name: "DemoTests",
            dependencies: ["Demo"],
            swiftSettings: defaultSwiftSettings
        )
    ]
)
EOF
}

install_swift_dump_stub_success() {
  local repo="$1"

  mkdir -p "$repo/fakebin"
  cat > "$repo/fakebin/swift" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [ "${1:-}" = "package" ] && [ "${2:-}" = "dump-package" ]; then
  cat <<'JSON'
{"dependencies":[],"targets":[{"name":"Demo"},{"name":"DemoTests"}]}
JSON
  exit 0
fi
exit 1
EOF
  chmod +x "$repo/fakebin/swift"
  export PATH="$repo/fakebin:$PATH"
}

install_swift_dump_stub_failure() {
  local repo="$1"

  mkdir -p "$repo/fakebin"
  cat > "$repo/fakebin/swift" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [ "${1:-}" = "package" ] && [ "${2:-}" = "dump-package" ]; then
  exit 1
fi
exit 1
EOF
  chmod +x "$repo/fakebin/swift"
  export PATH="$repo/fakebin:$PATH"
}

@test "check-swift-package fails clearly when Package.swift is missing" {
  repo="$(make_temp_repo)"
  copy_script_into_repo "$repo" "check-swift-package.sh"

  run bash -c "cd '$repo' && sh scripts/check-swift-package.sh"

  [ "$status" -eq 1 ]
  [[ "$output" == *"Package.swift missing"* ]]
}

@test "check-swift-package passes on valid package structure and settings" {
  repo="$(make_temp_repo)"
  copy_script_into_repo "$repo" "check-swift-package.sh"
  setup_valid_swift_package_layout "$repo"
  write_valid_package_swift "$repo"
  install_swift_dump_stub_success "$repo"

  run bash -c "cd '$repo' && sh scripts/check-swift-package.sh"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Swift Package validation passed"* ]]
}

@test "check-swift-package fails when swift-tools-version is below 6.1" {
  repo="$(make_temp_repo)"
  copy_script_into_repo "$repo" "check-swift-package.sh"
  setup_valid_swift_package_layout "$repo"
  write_valid_package_swift "$repo"
  install_swift_dump_stub_success "$repo"

  sed -i.bak 's|// swift-tools-version: 6.1|// swift-tools-version: 5.9|' "$repo/Package.swift"
  rm -f "$repo/Package.swift.bak"

  run bash -c "cd '$repo' && sh scripts/check-swift-package.sh"

  [ "$status" -eq 1 ]
  [[ "$output" == *"swift-tools-version too old"* ]]
}

@test "check-swift-package fails when docc placeholder is missing" {
  repo="$(make_temp_repo)"
  copy_script_into_repo "$repo" "check-swift-package.sh"
  setup_valid_swift_package_layout "$repo"
  write_valid_package_swift "$repo"
  install_swift_dump_stub_success "$repo"

  sed -i.bak '/docc-plugin-placeholder/d' "$repo/Package.swift"
  rm -f "$repo/Package.swift.bak"

  run bash -c "cd '$repo' && sh scripts/check-swift-package.sh"

  [ "$status" -eq 1 ]
  [[ "$output" == *"docc plugin placeholder missing"* ]]
}

@test "check-swift-package fails when a target misses swiftSettings: defaultSwiftSettings" {
  repo="$(make_temp_repo)"
  copy_script_into_repo "$repo" "check-swift-package.sh"
  setup_valid_swift_package_layout "$repo"
  cat > "$repo/Package.swift" <<'EOF'
// swift-tools-version: 6.1
import PackageDescription

let defaultSwiftSettings: [SwiftSetting] = [
    .enableUpcomingFeature("NonisolatedNonsendingByDefault")
]

let package = Package(
    name: "Demo",
    products: [
        .library(name: "Demo", targets: ["Demo"])
    ],
    dependencies: [
        // [docc-plugin-placeholder]
    ],
    targets: [
        .target(
            name: "Demo",
            swiftSettings: defaultSwiftSettings
        ),
        .testTarget(
            name: "DemoTests",
            dependencies: ["Demo"]
        )
    ]
)
EOF
  install_swift_dump_stub_success "$repo"

  run bash -c "cd '$repo' && sh scripts/check-swift-package.sh"

  [ "$status" -eq 1 ]
  [[ "$output" == *"DemoTests missing swiftSettings: defaultSwiftSettings"* ]]
}

@test "check-swift-package fails when LICENSE does not contain current year" {
  repo="$(make_temp_repo)"
  copy_script_into_repo "$repo" "check-swift-package.sh"
  setup_valid_swift_package_layout "$repo"
  write_valid_package_swift "$repo"
  install_swift_dump_stub_success "$repo"

  cat > "$repo/LICENSE" <<'EOF'
Copyright 2001
EOF

  run bash -c "cd '$repo' && sh scripts/check-swift-package.sh"

  [ "$status" -eq 1 ]
  [[ "$output" == *"LICENSE does not contain current year"* ]]
}

@test "check-swift-package fails when Sources directory is missing" {
  repo="$(make_temp_repo)"
  copy_script_into_repo "$repo" "check-swift-package.sh"
  setup_valid_swift_package_layout "$repo"
  write_valid_package_swift "$repo"
  install_swift_dump_stub_success "$repo"

  rm -rf "$repo/Sources"

  run bash -c "cd '$repo' && sh scripts/check-swift-package.sh"

  [ "$status" -eq 1 ]
  [[ "$output" == *"Sources directory missing"* ]]
}

@test "check-swift-package fails when Tests directory is missing" {
  repo="$(make_temp_repo)"
  copy_script_into_repo "$repo" "check-swift-package.sh"
  setup_valid_swift_package_layout "$repo"
  write_valid_package_swift "$repo"
  install_swift_dump_stub_success "$repo"

  rm -rf "$repo/Tests"

  run bash -c "cd '$repo' && sh scripts/check-swift-package.sh"

  [ "$status" -eq 1 ]
  [[ "$output" == *"Tests directory missing"* ]]
}

@test "check-swift-package fails when swift package dump-package fails" {
  repo="$(make_temp_repo)"
  copy_script_into_repo "$repo" "check-swift-package.sh"
  setup_valid_swift_package_layout "$repo"
  write_valid_package_swift "$repo"
  install_swift_dump_stub_failure "$repo"

  run bash -c "cd '$repo' && sh scripts/check-swift-package.sh"

  [ "$status" -eq 1 ]
  [[ "$output" == *"Failed to parse Package.swift via SwiftPM"* ]]
}

@test "check-swift-package fails when NonisolatedNonsendingByDefault is missing" {
  repo="$(make_temp_repo)"
  copy_script_into_repo "$repo" "check-swift-package.sh"
  setup_valid_swift_package_layout "$repo"
  write_valid_package_swift "$repo"
  install_swift_dump_stub_success "$repo"

  sed -i.bak '/NonisolatedNonsendingByDefault/d' "$repo/Package.swift"
  rm -f "$repo/Package.swift.bak"

  run bash -c "cd '$repo' && sh scripts/check-swift-package.sh"

  [ "$status" -eq 1 ]
  [[ "$output" == *"NonisolatedNonsendingByDefault missing"* ]]
}
