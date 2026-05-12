#!/usr/bin/env bash
# Shared bootstrap for fast_deploy bundled scripts.
# These scripts live in the app's support directory, NOT in the target
# Flutter project. PROJECT_ROOT is injected by the caller (Flutter app).
#
# Every other script `source`s this file as its first action.

set -euo pipefail

PROJECT_ROOT="${PROJECT_ROOT:?PROJECT_ROOT env var must be set by caller}"
[ -d "$PROJECT_ROOT" ] || { echo "PROJECT_ROOT does not exist: $PROJECT_ROOT" >&2; exit 1; }

cd "$PROJECT_ROOT"

# Defaults that callers can override via env.
FLUTTER_VERSION="${FLUTTER_VERSION:-3.41.9}"
APP_IDENTIFIER="${APP_IDENTIFIER:-}"
PACKAGE_NAME="${PACKAGE_NAME:-$APP_IDENTIFIER}"
TEAM_ID="${TEAM_ID:-}"
PLAY_TRACK="${PLAY_TRACK:-internal}"
MATCH_GIT_BRANCH="${MATCH_GIT_BRANCH:-main}"

# Optional .env.deploy override file inside the target project (gives users
# an escape hatch to add settings the UI doesn't cover yet).
if [ -f "$PROJECT_ROOT/scripts/.env.deploy" ]; then
  set -a; source "$PROJECT_ROOT/scripts/.env.deploy"; set +a
fi
