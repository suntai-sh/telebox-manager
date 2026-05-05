#!/usr/bin/env bash
set -euo pipefail

WORKSPACE="${TELEBOX_WORKSPACE:-/workspace}"
DATA_DIR="${TELEBOX_DATA:-/data}"
REPO_URL="${TELEBOX_REPO:-https://github.com/TeleBoxOrg/TeleBox.git}"
BRANCH="${TELEBOX_BRANCH:-main}"
LOCKFILE_HASH_FILE="$DATA_DIR/temp/.package-lock.sha256"

log() {
  printf '[telebox-entrypoint] %s\n' "$*"
}

mkdir -p "$WORKSPACE" "$DATA_DIR/plugins" "$DATA_DIR/assets" "$DATA_DIR/logs" "$DATA_DIR/temp" "$DATA_DIR/my_session"

if [ ! -d "$WORKSPACE/.git" ]; then
  log "workspace empty, cloning official repo: $REPO_URL#$BRANCH"
  rm -rf "$WORKSPACE"/* "$WORKSPACE"/.[!.]* "$WORKSPACE"/..?* 2>/dev/null || true
  git clone --depth 1 --branch "$BRANCH" "$REPO_URL" "$WORKSPACE"
else
  log "existing workspace detected, reusing checked out repo"
fi

cd "$WORKSPACE"

if [ ! -f "$DATA_DIR/config.json" ]; then
  log "creating initial config.json"
  cat > "$DATA_DIR/config.json" <<'EOF'
{
  "api_id": 0,
  "api_hash": "",
  "session": ""
}
EOF
fi

rm -rf plugins assets logs temp my_session config.json
ln -sfn "$DATA_DIR/plugins" plugins
ln -sfn "$DATA_DIR/assets" assets
ln -sfn "$DATA_DIR/logs" logs
ln -sfn "$DATA_DIR/temp" temp
ln -sfn "$DATA_DIR/my_session" my_session
ln -sfn "$DATA_DIR/config.json" config.json

needs_install=0
if [ ! -d node_modules ] || [ -z "$(ls -A node_modules 2>/dev/null || true)" ]; then
  needs_install=1
elif [ -f package-lock.json ]; then
  current_hash=$(sha256sum package-lock.json | cut -d' ' -f1)
  saved_hash=""
  [ -f "$LOCKFILE_HASH_FILE" ] && saved_hash=$(cat "$LOCKFILE_HASH_FILE" || true)
  if [ "$current_hash" != "$saved_hash" ]; then
    needs_install=1
  fi
fi

if [ "$needs_install" -eq 1 ]; then
  log "installing project dependencies"
  npm install
  if [ -f package-lock.json ]; then
    sha256sum package-lock.json | cut -d' ' -f1 > "$LOCKFILE_HASH_FILE"
  fi
else
  log "dependencies already up to date"
fi

exec "$@"
