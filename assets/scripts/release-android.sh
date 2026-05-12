#!/usr/bin/env bash
# Build & ship an Android release locally via Shorebird, then optionally upload
# the AAB to Play Console.
#
# Required env (injected by the app):
#   PROJECT_ROOT                          target Flutter project
# Optional env:
#   FLUTTER_VERSION                       default: 3.41.9
#   PACKAGE_NAME                          e.g. com.creditcliq.app
#   PLAY_TRACK                            internal | alpha | beta | production
#   PLAY_STORE_SERVICE_ACCOUNT_JSON_PATH  abs path; if set, uploads to Play
# Flags:
#   --no-upload   build only, leave AAB on disk

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_common.sh"

SKIP_UPLOAD=false
for arg in "$@"; do
  case "$arg" in
    --no-upload|--skip-upload) SKIP_UPLOAD=true ;;
  esac
done

[ -f .env ] || { echo "Missing .env at project root: $PROJECT_ROOT/.env" >&2; exit 1; }
[ -f android/key.properties ] || { echo "Missing android/key.properties" >&2; exit 1; }
command -v shorebird >/dev/null || {
  echo "shorebird CLI not installed." >&2
  echo "  Install: curl --proto '=https' --tlsv1.2 https://raw.githubusercontent.com/shorebirdtech/install/main/install.sh -sSf | bash" >&2
  exit 1
}

echo "→ Building Android release with Shorebird (Flutter $FLUTTER_VERSION)"
shorebird release android \
  --flutter-version="$FLUTTER_VERSION" \
  ${FLAVOR:+--flavor "$FLAVOR"} \
  ${TARGET:+-t "lib/$TARGET"}

if [ -n "$FLAVOR" ]; then
  AAB_PATH="build/app/outputs/bundle/${FLAVOR}Release/app-${FLAVOR}-release.aab"
else
  AAB_PATH="build/app/outputs/bundle/release/app-release.aab"
fi
[ -f "$AAB_PATH" ] || { echo "AAB not found at $AAB_PATH after build" >&2; exit 1; }

if $SKIP_UPLOAD; then
  echo "✓ Skipping Play Console upload (--no-upload)"
  echo "AAB: $PROJECT_ROOT/$AAB_PATH"
  exit 0
fi

if [ -z "${PLAY_STORE_SERVICE_ACCOUNT_JSON_PATH:-}" ]; then
  echo "⚠ PLAY_STORE_SERVICE_ACCOUNT_JSON_PATH not set; skipping Play upload."
  echo "  Add it in the app's iOS/Android keys screen to enable auto-upload."
  echo "  AAB ready at: $PROJECT_ROOT/$AAB_PATH"
  exit 0
fi

[ -f "$PLAY_STORE_SERVICE_ACCOUNT_JSON_PATH" ] || {
  echo "Service account JSON not found at: $PLAY_STORE_SERVICE_ACCOUNT_JSON_PATH" >&2
  exit 1
}
command -v fastlane >/dev/null || {
  echo "fastlane required for Play upload. brew install fastlane" >&2
  exit 1
}

if [ -z "${PACKAGE_NAME:-}" ]; then
  echo "PACKAGE_NAME not set — required for Play upload" >&2
  exit 1
fi

echo "→ Uploading $AAB_PATH to Play Console (track: $PLAY_TRACK)"
fastlane supply \
  --aab "$AAB_PATH" \
  --package_name "$PACKAGE_NAME" \
  --track "$PLAY_TRACK" \
  --json_key "$PLAY_STORE_SERVICE_ACCOUNT_JSON_PATH" \
  --skip_upload_metadata true \
  --skip_upload_changelogs true \
  --skip_upload_images true \
  --skip_upload_screenshots true

echo "✓ Android release uploaded to $PLAY_TRACK track"
