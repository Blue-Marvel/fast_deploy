#!/usr/bin/env bash
# Pre-flight: report which CLIs and project files are present. Run on
# project add to surface what's missing before the user kicks off a deploy.
#
# Required env: PROJECT_ROOT
# Output: machine-readable lines of the form `KEY=value`

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
set -uo pipefail
source "$SCRIPT_DIR/_common.sh" || true

emit() { echo "$1=$2"; }

# CLIs
for tool in shorebird fastlane xcodebuild flutter security; do
  if command -v "$tool" >/dev/null 2>&1; then
    ver="$("$tool" --version 2>/dev/null | head -n1 | tr -d '\r')"
    emit "${tool}_installed" "true"
    emit "${tool}_version" "$ver"
  else
    emit "${tool}_installed" "false"
  fi
done

# Project files
[ -f "$PROJECT_ROOT/.env" ] && emit "env_file" "true" || emit "env_file" "false"
[ -f "$PROJECT_ROOT/android/key.properties" ] && emit "android_keystore" "true" || emit "android_keystore" "false"
[ -d "$PROJECT_ROOT/ios/Runner.xcodeproj" ] && emit "ios_project" "true" || emit "ios_project" "false"
[ -f "$PROJECT_ROOT/pubspec.yaml" ] && emit "pubspec" "true" || emit "pubspec" "false"
[ -f "$PROJECT_ROOT/shorebird.yaml" ] && emit "shorebird_yaml" "true" || emit "shorebird_yaml" "false"

# Code-signing identities (just the count, don't leak names)
DIST_COUNT="$(security find-identity -v -p codesigning 2>/dev/null | grep -c 'Apple Distribution' || true)"
emit "apple_distribution_certs" "$DIST_COUNT"
