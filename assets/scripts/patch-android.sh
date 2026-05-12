#!/usr/bin/env bash
# Ship an Android Shorebird patch (OTA Dart update) against an existing release.
#
# Required env: PROJECT_ROOT
# Optional env: RELEASE_VERSION (default: latest)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_common.sh"

RELEASE_VERSION="${RELEASE_VERSION:-latest}"

[ -f .env ] || { echo "Missing .env at project root" >&2; exit 1; }
[ -f android/key.properties ] || { echo "Missing android/key.properties" >&2; exit 1; }
command -v shorebird >/dev/null || { echo "shorebird CLI not installed" >&2; exit 1; }

echo "→ Building Android patch via Shorebird (release: $RELEASE_VERSION)"
shorebird patch android --release-version="$RELEASE_VERSION"

echo "✓ Android patch shipped"
