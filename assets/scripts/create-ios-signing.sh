#!/usr/bin/env bash
# Create a Distribution cert + AppStore provisioning profile and install them
# locally via fastlane cert/sigh. Use this when you don't have a match repo.
#
# Required env: PROJECT_ROOT, APP_IDENTIFIER, TEAM_ID, ASC_API_KEY_JSON_PATH

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_common.sh"

[ -n "$APP_IDENTIFIER" ] || { echo "APP_IDENTIFIER not set" >&2; exit 1; }
[ -n "$TEAM_ID" ] || { echo "TEAM_ID not set" >&2; exit 1; }
[ -n "${ASC_API_KEY_JSON_PATH:-}" ] || { echo "ASC_API_KEY_JSON_PATH not set" >&2; exit 1; }
[ -f "$ASC_API_KEY_JSON_PATH" ] || { echo "ASC API key not found at: $ASC_API_KEY_JSON_PATH" >&2; exit 1; }
command -v fastlane >/dev/null || { echo "fastlane required. brew install fastlane" >&2; exit 1; }

echo "→ Step 1: Apple Distribution certificate (team $TEAM_ID)"
fastlane cert \
  --development false \
  --team_id "$TEAM_ID" \
  --api_key_path "$ASC_API_KEY_JSON_PATH"

echo ""
echo "→ Step 2: AppStore provisioning profile for $APP_IDENTIFIER"
fastlane sigh \
  --app_identifier "$APP_IDENTIFIER" \
  --team_id "$TEAM_ID" \
  --api_key_path "$ASC_API_KEY_JSON_PATH"

mkdir -p "$HOME/Library/MobileDevice/Provisioning Profiles"
shopt -s nullglob
for p in *.mobileprovision; do
  mv "$p" "$HOME/Library/MobileDevice/Provisioning Profiles/"
done
shopt -u nullglob

echo ""
echo "✓ Done."
