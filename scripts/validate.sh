#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF' >&2
Usage: scripts/validate.sh [--log-dir PATH] [--fail-on-generated-diff]
EOF
}

log_dir=""
fail_on_generated_diff=0

while [[ $# -gt 0 ]]; do
  case "$1" in
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
require_tool xcodebuild
require_tool git

run_logged_step xcodegen-generate xcodegen generate --use-cache

project_status="$(git status --short -- LithApps.xcodeproj)"
if [[ -n "$project_status" && $fail_on_generated_diff -eq 1 ]]; then
  echo "Generated Xcode project is out of sync with project.yml. Commit the resulting LithApps.xcodeproj changes." >&2
  printf '%s\n' "$project_status" >&2
  exit 1
fi

run_logged_step swift-build swift build
run_logged_step swift-test swift test
run_logged_step xcodebuild-macos xcodebuild -scheme LithmacOS -project LithApps.xcodeproj -configuration Debug -destination "platform=macOS" build
run_logged_step xcodebuild-ios xcodebuild -scheme LithiOS -project LithApps.xcodeproj -configuration Debug -destination "generic/platform=iOS Simulator" build

echo "Validation completed successfully."
echo "Logs: $log_dir"
