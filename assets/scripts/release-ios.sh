#!/usr/bin/env bash
# Build & ship an iOS release locally via Shorebird, then optionally upload to
# TestFlight via fastlane pilot.
#
# Required env (injected by the app):
#   PROJECT_ROOT           target Flutter project
#   APP_IDENTIFIER         e.g. com.creditcliq.app
#   TEAM_ID                Apple team ID
# Optional env:
#   FLUTTER_VERSION        default: 3.41.9
#   ASC_API_KEY_JSON_PATH  abs path; if set, uploads to TestFlight
# Flags:
#   --no-upload            build only

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_common.sh"

SKIP_UPLOAD=false
OPEN_XCODE=false
for arg in "$@"; do
  case "$arg" in
    --no-upload|--skip-upload) SKIP_UPLOAD=true ;;
    --open-xcode) OPEN_XCODE=true; SKIP_UPLOAD=true ;;
  esac
done

[ -f .env ] || { echo "Missing .env at project root: $PROJECT_ROOT/.env" >&2; exit 1; }
[ -n "$APP_IDENTIFIER" ] || { echo "APP_IDENTIFIER not set" >&2; exit 1; }
[ -n "$TEAM_ID" ] || { echo "TEAM_ID not set" >&2; exit 1; }
command -v shorebird >/dev/null || { echo "shorebird CLI not installed" >&2; exit 1; }

# Xcode SDK check — App Store Connect rejects uploads built with old SDKs.
if XCODE_RAW="$(xcodebuild -version 2>/dev/null | head -n1 | awk '{print $2}')"; then
  XCODE_MAJOR="${XCODE_RAW%%.*}"
  if [ -n "$XCODE_MAJOR" ] && [ "$XCODE_MAJOR" -lt 26 ] 2>/dev/null; then
    echo "⚠ Xcode $XCODE_RAW is selected — App Store Connect requires Xcode 26+ for new uploads." >&2
    echo "  Switch with: sudo xcode-select -s /Applications/Xcode-26.x.app/Contents/Developer" >&2
    if ! $SKIP_UPLOAD; then
      echo "  Continuing, but TestFlight upload will likely fail validation." >&2
    fi
  fi
fi

if ! security find-identity -v -p codesigning 2>/dev/null | grep -q "Apple Distribution"; then
  echo "" >&2
  echo "✗ No 'Apple Distribution' certificate found in keychain." >&2
  echo "  Run setup-ios-signing first to install certs via match." >&2
  exit 1
fi

# Flip Xcode project to manual signing for the duration of the build, then
# restore the original project file so the repo stays clean.
XCODEPROJ_DIR="ios/Runner.xcodeproj"
PROJECT_FILE="$XCODEPROJ_DIR/project.pbxproj"
PROJECT_BACKUP="$(mktemp -t pbxproj.XXXXXX)"
cp "$PROJECT_FILE" "$PROJECT_BACKUP"
restore_project() {
  if [ -f "$PROJECT_BACKUP" ]; then
    cp "$PROJECT_BACKUP" "$PROJECT_FILE"
    rm -f "$PROJECT_BACKUP"
    echo "→ Restored $PROJECT_FILE to its original state"
  fi
}
trap restore_project EXIT

# Find an AppStore profile that matches our team + app identifier.
find_appstore_profile_name() {
  local target_app="$1"
  local target_team="$2"
  for dir in "$HOME/Library/MobileDevice/Provisioning Profiles" "$HOME/Library/Developer/Xcode/UserData/Provisioning Profiles"; do
    [ -d "$dir" ] || continue
    while IFS= read -r -d '' profile; do
      local plist
      plist="$(security cms -D -i "$profile" 2>/dev/null)" || continue
      local name team appid devices
      name="$(echo "$plist" | /usr/libexec/PlistBuddy -c 'Print Name' /dev/stdin 2>/dev/null || echo '')"
      team="$(echo "$plist" | /usr/libexec/PlistBuddy -c 'Print TeamIdentifier:0' /dev/stdin 2>/dev/null || echo '')"
      appid="$(echo "$plist" | /usr/libexec/PlistBuddy -c 'Print Entitlements:application-identifier' /dev/stdin 2>/dev/null || echo '')"
      devices="$(echo "$plist" | /usr/libexec/PlistBuddy -c 'Print ProvisionedDevices' /dev/stdin 2>&1 || true)"
      if [ "$team" = "$target_team" ] \
          && [ "$appid" = "$target_team.$target_app" ] \
          && [[ "$devices" == *"Does Not Exist"* ]]; then
        echo "$name"
        return 0
      fi
    done < <(find "$dir" -name "*.mobileprovision" -print0 2>/dev/null)
  done
  return 1
}

PROFILE_NAME="$(find_appstore_profile_name "$APP_IDENTIFIER" "$TEAM_ID" || true)"
if [ -z "$PROFILE_NAME" ]; then
  echo "" >&2
  echo "✗ No AppStore provisioning profile found for $APP_IDENTIFIER on team $TEAM_ID." >&2
  echo "  Run setup-ios-signing or create-ios-signing first." >&2
  exit 1
fi
echo "→ Using provisioning profile: $PROFILE_NAME"

echo "→ Switching Xcode project to manual signing for this build"
fastlane run update_code_signing_settings \
  path:"$XCODEPROJ_DIR" \
  use_automatic_signing:false \
  team_id:"$TEAM_ID" \
  code_sign_identity:"Apple Distribution" \
  profile_name:"$PROFILE_NAME" \
  bundle_identifier:"$APP_IDENTIFIER" \
  targets:"Runner" >/dev/null

rm -f build/ios/ipa/*.ipa 2>/dev/null || true

echo "→ Building iOS release with Shorebird (Flutter $FLUTTER_VERSION)"
shorebird release ios \
  --flutter-version="$FLUTTER_VERSION" \
  ${FLAVOR:+--flavor "$FLAVOR"} \
  ${TARGET:+-t "lib/$TARGET"} \
  --export-method app-store \
  -- --obfuscate --split-debug-info=build/ios/symbols

IPA_PATH="$(ls -1 build/ios/ipa/*.ipa 2>/dev/null | head -n1 || true)"
if [ -z "$IPA_PATH" ]; then
  echo "" >&2
  echo "✗ No IPA produced this run." >&2
  echo "  Shorebird's release was published (patches will work), but" >&2
  echo "  flutter build ipa failed — usually a signing problem locally." >&2
  exit 1
fi

if $OPEN_XCODE; then
  echo "→ Opening Xcode archive viewer"
  open -a Xcode "$PROJECT_ROOT/ios/Runner.xcworkspace"
fi

if $SKIP_UPLOAD; then
  echo "✓ Skipping TestFlight upload"
  echo "IPA: $PROJECT_ROOT/$IPA_PATH"
  exit 0
fi

if [ -z "${ASC_API_KEY_JSON_PATH:-}" ]; then
  echo "⚠ ASC_API_KEY_JSON_PATH not set; skipping TestFlight upload."
  echo "  IPA ready at: $PROJECT_ROOT/$IPA_PATH"
  exit 0
fi

[ -f "$ASC_API_KEY_JSON_PATH" ] || {
  echo "ASC API key not found at: $ASC_API_KEY_JSON_PATH" >&2
  exit 1
}
command -v fastlane >/dev/null || {
  echo "fastlane required for TestFlight upload. brew install fastlane" >&2
  exit 1
}

echo "→ Uploading $IPA_PATH to TestFlight"
fastlane pilot upload \
  --api_key_path "$ASC_API_KEY_JSON_PATH" \
  --app_identifier "$APP_IDENTIFIER" \
  ${TEAM_ID:+--team_id "$TEAM_ID"} \
  --ipa "$IPA_PATH" \
  --skip_waiting_for_build_processing true \
  --skip_submission true

echo "✓ iOS release uploaded to TestFlight"
