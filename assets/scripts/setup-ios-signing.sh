#!/usr/bin/env bash
# One-time: fetch iOS distribution certs/profiles into the local keychain via
# fastlane match. Run before the first iOS release on a new machine.
#
# Required env: PROJECT_ROOT, MATCH_GIT_URL, MATCH_PASSWORD, APP_IDENTIFIER, TEAM_ID
# Optional env: MATCH_GIT_BRANCH (default: main), MATCH_DEPLOY_KEY_PATH

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_common.sh"

[ -n "${MATCH_GIT_URL:-}" ] || { echo "MATCH_GIT_URL not set" >&2; exit 1; }
[ -n "${MATCH_PASSWORD:-}" ] || { echo "MATCH_PASSWORD not set" >&2; exit 1; }
[ -n "$APP_IDENTIFIER" ] || { echo "APP_IDENTIFIER not set" >&2; exit 1; }

command -v fastlane >/dev/null || { echo "fastlane required. brew install fastlane" >&2; exit 1; }

# Trust the match repo's git host so SSH clone doesn't hang on a prompt.
MATCH_HOST="$(echo "$MATCH_GIT_URL" | sed -E 's|^git@([^:]+):.*|\1|')"
if [ -n "$MATCH_HOST" ] && [ "$MATCH_HOST" != "$MATCH_GIT_URL" ]; then
  mkdir -p ~/.ssh
  chmod 700 ~/.ssh
  if ! grep -q "$MATCH_HOST" ~/.ssh/known_hosts 2>/dev/null; then
    echo "→ Adding $MATCH_HOST to ~/.ssh/known_hosts"
    ssh-keyscan -H "$MATCH_HOST" >> ~/.ssh/known_hosts 2>/dev/null
  fi
fi

if [ -n "${MATCH_DEPLOY_KEY_PATH:-}" ]; then
  [ -f "$MATCH_DEPLOY_KEY_PATH" ] || {
    echo "MATCH_DEPLOY_KEY_PATH points to missing file: $MATCH_DEPLOY_KEY_PATH" >&2
    exit 1
  }
  chmod 600 "$MATCH_DEPLOY_KEY_PATH"
  ABS_KEY_PATH="$(cd "$(dirname "$MATCH_DEPLOY_KEY_PATH")" && pwd)/$(basename "$MATCH_DEPLOY_KEY_PATH")"
  export GIT_SSH_COMMAND="ssh -i $ABS_KEY_PATH -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=$HOME/.ssh/known_hosts"
  echo "→ Using dedicated deploy key: $ABS_KEY_PATH"
fi

echo "→ Fetching iOS distribution certs via fastlane match (read-only)"
echo "  repo:   $MATCH_GIT_URL"
echo "  branch: $MATCH_GIT_BRANCH"
echo "  app:    $APP_IDENTIFIER"

fastlane match appstore \
  --readonly \
  --git_url="$MATCH_GIT_URL" \
  --git_branch="$MATCH_GIT_BRANCH" \
  --app_identifier="$APP_IDENTIFIER" \
  --shallow_clone \
  --verbose \
  ${TEAM_ID:+--team_id="$TEAM_ID"}

echo ""
echo "✓ iOS signing assets installed in your keychain"
