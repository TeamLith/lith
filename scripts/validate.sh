#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF' >&2
Usage: scripts/validate.sh [--log-dir PATH] [--fail-on-generated-diff] [--package-only] [--ui-tests]
EOF
}

log_dir=""
fail_on_generated_diff=0
package_only=0
ui_tests=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --package-only)
      package_only=1
      shift
      ;;
    --ui-tests)
      ui_tests=1
      shift
      ;;
    --log-dir)
      if [[ $# -lt 2 ]]; then
        usage
        exit 1
      fi
      log_dir="$2"
      shift 2
      ;;
    --fail-on-generated-diff)
      fail_on_generated_diff=1
      shift
      ;;
    *)
      usage
      exit 1
      ;;
  esac
done

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

if [[ -z "$log_dir" ]]; then
  log_dir="$(mktemp -d "${TMPDIR:-/tmp}/lith-validation.XXXXXX")"
fi

mkdir -p "$log_dir"

require_tool() {
  local tool_name="$1"
  if ! command -v "$tool_name" >/dev/null 2>&1; then
    echo "Missing required tool: $tool_name" >&2
    exit 1
  fi
}

run_logged_step() {
  local step_name="$1"
  shift

  local log_file="$log_dir/${step_name}.log"
  echo "==> $step_name"

  set +e
  "$@" 2>&1 | tee "$log_file"
  local status=${PIPESTATUS[0]}
  set -e

  if [[ $status -ne 0 ]]; then
    echo "Step failed: $step_name" >&2
    echo "Log file: $log_file" >&2
    exit "$status"
  fi
}

require_tool xcodegen
require_tool swift
require_tool python3
require_tool git

if [[ $package_only -eq 1 && $ui_tests -eq 1 ]]; then
  echo "--ui-tests requires full Xcode validation, not --package-only." >&2
  exit 1
fi
if [[ $package_only -eq 0 ]]; then
  require_tool xcodebuild
  if ! xcodebuild -version >/dev/null 2>&1; then
    echo "Full Xcode is required for app builds. Use --package-only for CLT package tests and macOS source typechecking." >&2
    exit 1
  fi
fi

run_logged_step xcodegen-generate python3 scripts/generate-project.py
run_logged_step project-generator-tests python3 -B -m unittest discover -s Tests/Tooling -v

project_status="$(git status --short -- LithApps.xcodeproj)"
if [[ -n "$project_status" && $fail_on_generated_diff -eq 1 ]]; then
  echo "Generated Xcode project is out of sync with project.yml. Commit the resulting LithApps.xcodeproj changes." >&2
  printf '%s\n' "$project_status" >&2
  exit 1
fi

# Standalone Command Line Tools ships Testing outside SwiftPM's default search path.
# Full Xcode selects its own framework paths and does not need this override.
swift_flags=()
developer_dir="$(xcode-select -p)"
if [[ "$developer_dir" == */CommandLineTools ]]; then
  testing_frameworks="$developer_dir/Library/Developer/Frameworks"
  testing_libraries="$developer_dir/Library/Developer/usr/lib"
  if [[ -d "$testing_frameworks/Testing.framework" ]]; then
    swift_flags=(-Xswiftc "-F$testing_frameworks" -Xlinker "-F$testing_frameworks"
      -Xlinker -rpath -Xlinker "$testing_frameworks"
      -Xlinker -rpath -Xlinker "$testing_libraries")
  fi
fi
run_logged_step swift-build swift build --jobs "${LITH_BUILD_JOBS:-2}" "${swift_flags[@]}"
run_logged_step swift-test swift test --jobs "${LITH_BUILD_JOBS:-2}" "${swift_flags[@]}"

if [[ $package_only -eq 1 ]]; then
  require_tool rg
  app_sources=()
  while IFS= read -r -d '' file; do app_sources+=("$file"); done < <(rg --files -0 -g '*.swift' Apps/LithApp/Sources/Shared Apps/LithApp/Sources/macOS)
  modules="$(swift build --show-bin-path)/Modules"
  run_logged_step macos-source-typecheck swiftc -typecheck -parse-as-library -I "$modules" -target "$(uname -m)-apple-macosx14.0" "${app_sources[@]}"
  echo "Package validation passed. Xcode app builds, iOS compilation, signing, and UI tests were not run."
else
  run_logged_step xcodebuild-macos xcodebuild -scheme LithmacOS -project LithApps.xcodeproj -configuration Debug -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO build-for-testing
  run_logged_step xcodebuild-ios xcodebuild -scheme LithiOS -project LithApps.xcodeproj -configuration Debug -destination "generic/platform=iOS Simulator" CODE_SIGNING_ALLOWED=NO build-for-testing
  if [[ $ui_tests -eq 1 ]]; then
    if [[ -z "${LITH_IOS_TEST_DESTINATION:-}" ]]; then
      echo "Set LITH_IOS_TEST_DESTINATION to an installed iOS simulator destination before --ui-tests." >&2
      exit 1
    fi
    run_logged_step ui-tests-macos xcodebuild -scheme LithmacOS -project LithApps.xcodeproj -configuration Debug -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO test
    run_logged_step ui-tests-ios xcodebuild -scheme LithiOS -project LithApps.xcodeproj -configuration Debug -destination "$LITH_IOS_TEST_DESTINATION" CODE_SIGNING_ALLOWED=NO test
  fi
  echo "Validation completed successfully."
fi
echo "Logs: $log_dir"
