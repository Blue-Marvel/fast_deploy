#!/usr/bin/env bash
# Ship an iOS Shorebird patch (OTA Dart update) against an existing release.
#
# Required env: PROJECT_ROOT
# Optional env: RELEASE_VERSION (default: latest)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_common.sh"

RELEASE_VERSION="${RELEASE_VERSION:-latest}"

[ -f .env ] || { echo "Missing .env at project root" >&2; exit 1; }
command -v shorebird >/dev/null || { echo "shorebird CLI not installed" >&2; exit 1; }

if XCODE_RAW="$(xcodebuild -version 2>/dev/null | head -n1 | awk '{print $2}')"; then
  XCODE_MAJOR="${XCODE_RAW%%.*}"
  if [ -n "$XCODE_MAJOR" ] && [ "$XCODE_MAJOR" -lt 26 ] 2>/dev/null; then
    echo "⚠ Xcode $XCODE_RAW is older than the SDK your release likely used." >&2
    echo "  Patch may be ABI-incompatible on production devices." >&2
  fi
fi

echo "→ Building iOS patch via Shorebird (release: $RELEASE_VERSION)"
shorebird patch ios \
  --release-version="$RELEASE_VERSION" \
  -- --no-codesign

echo "✓ iOS patch shipped"
