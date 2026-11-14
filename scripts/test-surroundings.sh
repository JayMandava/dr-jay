#!/usr/bin/env bash
# Run the production Foundation-only weather/food logic and its real XCTest files
# on Linux or macOS without requiring SwiftUI, SwiftData, CoreLocation or Xcode.
set -euo pipefail
repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_dir="$(mktemp -d "${TMPDIR:-/tmp}/dr-jay-surroundings.XXXXXX")"
trap 'rm -rf "$test_dir"' EXIT
mkdir -p "$test_dir/Sources/Roastie" "$test_dir/Tests/RoastieTests"
cp "$repo_dir/Shared/Surroundings.swift" "$test_dir/Sources/Roastie/"
cp "$repo_dir/RoastieTests/SurroundingsTests.swift" "$test_dir/Tests/RoastieTests/"
cp "$repo_dir/RoastieTests/SurroundingsFoodRotationTests.swift" "$test_dir/Tests/RoastieTests/"
cat > "$test_dir/Package.swift" <<'SWIFT'
// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "SurroundingsChecks", targets: [
    .target(name: "Roastie"),
    .testTarget(name: "RoastieTests", dependencies: ["Roastie"])
])
SWIFT
swift test --package-path "$test_dir"
