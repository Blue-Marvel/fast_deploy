#!/usr/bin/env bash
# Build an Android release locally via plain Flutter (no Shorebird), with
# optional Play Console upload via fastlane supply.
#
# Required env (injected by the app):
#   PROJECT_ROOT                          target Flutter project
# Optional env:
#   FLUTTER_VERSION                       default: 3.41.9
#   PACKAGE_NAME                          e.g. com.creditcliq.app (required for --upload)
#   PLAY_TRACK                            internal | alpha | beta | production
#   PLAY_STORE_SERVICE_ACCOUNT_JSON_PATH  abs path; required when --upload is passed
# Flags:
#   --upload   upload AAB to Play Console after build (via fastlane supply)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_common.sh"

DO_UPLOAD=false
for arg in "$@"; do
  case "$arg" in
    --upload) DO_UPLOAD=true ;;
  esac
done

[ -f .env ] || { echo "Missing .env at project root: $PROJECT_ROOT/.env" >&2; exit 1; }
[ -f android/key.properties ] || { echo "Missing android/key.properties" >&2; exit 1; }

echo "→ Building Android release with Flutter (no Shorebird)"
flutter build appbundle --release

AAB_PATH="build/app/outputs/bundle/release/app-release.aab"
[ -f "$AAB_PATH" ] || { echo "AAB not found at $AAB_PATH after build" >&2; exit 1; }

if ! $DO_UPLOAD; then
  echo "✓ Android build complete"
  echo "AAB: $PROJECT_ROOT/$AAB_PATH"
  exit 0
fi

if [ -z "${PLAY_STORE_SERVICE_ACCOUNT_JSON_PATH:-}" ]; then
  echo "✗ PLAY_STORE_SERVICE_ACCOUNT_JSON_PATH not set; cannot upload to Play Console." >&2
  echo "  Add it in the app's keys screen, or run with --no-upload." >&2
  echo "  AAB ready at: $PROJECT_ROOT/$AAB_PATH" >&2
  exit 1
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

echo "→ Uploading $AAB_PATH to Play Console (track: ${PLAY_TRACK:-internal})"
fastlane supply \
  --aab "$AAB_PATH" \
  --package_name "$PACKAGE_NAME" \
  --track "${PLAY_TRACK:-internal}" \
  --json_key "$PLAY_STORE_SERVICE_ACCOUNT_JSON_PATH" \
  --skip_upload_metadata true \
  --skip_upload_changelogs true \
  --skip_upload_images true \
  --skip_upload_screenshots true

echo "✓ Android release uploaded to ${PLAY_TRACK:-internal} track"
