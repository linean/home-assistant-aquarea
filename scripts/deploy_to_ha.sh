#!/usr/bin/env bash
# Sync custom_components/aquarea/ to a remote Home Assistant instance over SSH,
# restart HA, wait for it to come back, and print a confirmation.
#
# Usage:
#   deploy_to_ha.sh <host> [options]
#
# Options:
#   -u, --user USER          SSH user (default: root)
#   -p, --ssh-port PORT      SSH port (default: 22)
#   -c, --config-path PATH   Remote HA config root (default: /config)
#   -P, --ha-port PORT       HA HTTP port for liveness check (default: 80)
#   -r, --restart-cmd CMD    Remote command that restarts HA (default: "ha core restart")
#   -t, --timeout SECS       Seconds to wait for restart (default: 180)
#   -n, --dry-run            rsync --dry-run, skip restart
#   -h, --help               Show this help

set -euo pipefail

SSH_USER="root"
SSH_PORT="22"
CONFIG_PATH="/config"
HA_PORT="80"
RESTART_CMD="ha core restart"
WAIT_TIMEOUT="180"
DRY_RUN="0"
HOST=""

usage() {
  sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'
}

while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    -u|--user) SSH_USER="$2"; shift 2 ;;
    -p|--ssh-port) SSH_PORT="$2"; shift 2 ;;
    -c|--config-path) CONFIG_PATH="$2"; shift 2 ;;
    -P|--ha-port) HA_PORT="$2"; shift 2 ;;
    -r|--restart-cmd) RESTART_CMD="$2"; shift 2 ;;
    -t|--timeout) WAIT_TIMEOUT="$2"; shift 2 ;;
    -n|--dry-run) DRY_RUN="1"; shift ;;
    --) shift; break ;;
    -*) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
    *)
      if [ -z "$HOST" ]; then
        HOST="$1"; shift
      else
        echo "Unexpected positional argument: $1" >&2; exit 2
      fi
      ;;
  esac
done

if [ -z "$HOST" ]; then
  echo "Error: <host> is required" >&2
  usage >&2
  exit 2
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LOCAL_SRC="$REPO_ROOT/custom_components/aquarea/"
REMOTE_PATH="$CONFIG_PATH/custom_components/aquarea"
REMOTE_DEST="$SSH_USER@$HOST:$REMOTE_PATH/"

SSH_OPTS=(-p "$SSH_PORT" -o StrictHostKeyChecking=accept-new)

LOCAL_VERSION="$(python3 -c "import json; print(json.load(open('$REPO_ROOT/custom_components/aquarea/manifest.json'))['version'])")"

log() { printf '\033[1;36m[deploy]\033[0m %s\n' "$*"; }
err() { printf '\033[1;31m[deploy]\033[0m %s\n' "$*" >&2; }

for cmd in rsync ssh curl python3; do
  command -v "$cmd" >/dev/null 2>&1 || { err "$cmd not found in PATH"; exit 1; }
done

log "Local version: $LOCAL_VERSION"
log "Target: $SSH_USER@$HOST -> $REMOTE_PATH/"

RSYNC_ARGS=(
  -avz
  --delete
  --exclude '__pycache__'
  --exclude '*.pyc'
  -e "ssh -p $SSH_PORT -o StrictHostKeyChecking=accept-new"
)
if [ "$DRY_RUN" = "1" ]; then
  RSYNC_ARGS+=(--dry-run)
  log "DRY RUN: no files will be changed and HA will not be restarted"
fi

log "Syncing files..."
rsync "${RSYNC_ARGS[@]}" "$LOCAL_SRC" "$REMOTE_DEST"

if [ "$DRY_RUN" = "1" ]; then
  log "Dry run complete."
  exit 0
fi

log "Restarting HA via SSH ('$RESTART_CMD')..."
ssh "${SSH_OPTS[@]}" "$SSH_USER@$HOST" "$RESTART_CMD" || true

log "Waiting for HA to come back on port $HA_PORT (timeout ${WAIT_TIMEOUT}s)..."
deadline=$(( $(date +%s) + WAIT_TIMEOUT ))
sleep 5
while :; do
  if [ "$(date +%s)" -gt "$deadline" ]; then
    printf '\n'
    err "Timed out waiting for HA to come back."
    exit 1
  fi
  code=$(curl -fsS -o /dev/null -w '%{http_code}' --max-time 5 \
    "http://$HOST:$HA_PORT/" 2>/dev/null || echo 000)
  if [[ "$code" =~ ^(2|3)[0-9][0-9]$ ]]; then
    break
  fi
  printf '.'
  sleep 3
done
printf '\n'
log "HA is back online."

log "Reading deployed version from remote manifest..."
remote_version=$(ssh "${SSH_OPTS[@]}" "$SSH_USER@$HOST" \
  "python3 -c 'import json; print(json.load(open(\"$REMOTE_PATH/manifest.json\"))[\"version\"])'" \
  2>/dev/null || echo "unknown")

if [ "$remote_version" = "$LOCAL_VERSION" ]; then
  log "Deployed version matches local: $remote_version ✓"
else
  err "Version mismatch — local=$LOCAL_VERSION remote=$remote_version"
  exit 1
fi
