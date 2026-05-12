#!/usr/bin/env bash
# Diagnostic: show what's installed locally for iOS code signing.
#
# Required env: PROJECT_ROOT, APP_IDENTIFIER, TEAM_ID

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Don't `set -e` here — we want diagnostics to keep running on partial failures.
set -uo pipefail
source "$SCRIPT_DIR/_common.sh" || true

echo "─── Installed code-signing certs ───────────────────────────────────"
security find-identity -v -p codesigning | grep -E "Apple (Distribution|Development)" || echo "  (none)"

echo ""
echo "─── Provisioning profiles ──────────────────────────────────────────"
LEGACY_DIR="$HOME/Library/MobileDevice/Provisioning Profiles"
NEW_DIR="$HOME/Library/Developer/Xcode/UserData/Provisioning Profiles"

for dir in "$LEGACY_DIR" "$NEW_DIR"; do
  echo ""
  echo "📁 $dir"
  if [ ! -d "$dir" ]; then
    echo "  (directory does not exist)"
    continue
  fi
  count=0
  while IFS= read -r -d '' profile; do
    count=$((count + 1))
    plist="$(security cms -D -i "$profile" 2>/dev/null)"
    name="$(echo "$plist" | /usr/libexec/PlistBuddy -c 'Print Name' /dev/stdin 2>/dev/null || echo '?')"
    teamid="$(echo "$plist" | /usr/libexec/PlistBuddy -c 'Print TeamIdentifier:0' /dev/stdin 2>/dev/null || echo '?')"
    appid="$(echo "$plist" | /usr/libexec/PlistBuddy -c 'Print Entitlements:application-identifier' /dev/stdin 2>/dev/null || echo '?')"
    echo "  • $(basename "$profile")"
    echo "      Name:    $name"
    echo "      Team:    $teamid"
    echo "      AppID:   $appid"
  done < <(find "$dir" -name "*.mobileprovision" -print0 2>/dev/null)
  if [ "$count" -eq 0 ]; then
    echo "  (no profiles installed)"
  fi
done

echo ""
echo "─── Looking for AppStore profile for $APP_IDENTIFIER (team $TEAM_ID) ─"
FOUND=""
FOUND_NAME=""
for dir in "$LEGACY_DIR" "$NEW_DIR"; do
  [ -d "$dir" ] || continue
  while IFS= read -r -d '' profile; do
    plist="$(security cms -D -i "$profile" 2>/dev/null)"
    team="$(echo "$plist" | /usr/libexec/PlistBuddy -c 'Print TeamIdentifier:0' /dev/stdin 2>/dev/null || echo '')"
    appid="$(echo "$plist" | /usr/libexec/PlistBuddy -c 'Print Entitlements:application-identifier' /dev/stdin 2>/dev/null || echo '')"
    devices="$(echo "$plist" | /usr/libexec/PlistBuddy -c 'Print ProvisionedDevices' /dev/stdin 2>&1 || true)"
    name="$(echo "$plist" | /usr/libexec/PlistBuddy -c 'Print Name' /dev/stdin 2>/dev/null || echo '')"
    if [ "$team" = "$TEAM_ID" ] \
        && [ "$appid" = "$TEAM_ID.$APP_IDENTIFIER" ] \
        && [[ "$devices" == *"Does Not Exist"* ]]; then
      FOUND="$profile"
      FOUND_NAME="$name"
      break 2
    fi
  done < <(find "$dir" -name "*.mobileprovision" -print0 2>/dev/null)
done

echo ""
if [ -n "$FOUND" ]; then
  echo "✓ Match: $FOUND_NAME"
  echo "  $FOUND"
else
  echo "✗ No matching AppStore profile installed."
  echo "  Run setup-ios-signing or create-ios-signing."
fi
