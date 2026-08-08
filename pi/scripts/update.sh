#!/usr/bin/env bash
# update.sh - Pull latest images and recreate all stacks
# Schedule (optional cron): 0 4 * * 0 PI_ENV_FILE=... pi/scripts/update.sh
# Pulls from the origin remote, then refreshes digest-pinned images (pull the
# latest tag for each "pinned-from" ref and re-pin the compose files), then for
# each stack: docker compose pull + up. Pre/post health checks and a pre-update
# backup guard the rollout.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
STACKS_DIR="${ROOT_DIR}/pi/stacks"

# Stacks in dependency order: headscale first (mesh/DERP), then network
# (unbound + pihole), then gitops/apps, nas, monitoring, uis, portfolio.
STACKS=(
  headscale
  network
  gitops
  apps
  nas
  monitoring
  uptime-kuma
  portfolio
  vansh-portfolio
)

# Resolve env file: explicit override > repo-root .env > live secrets file
if [[ -n "${PI_ENV_FILE:-}" ]]; then
  ENV_FILE="$PI_ENV_FILE"
elif [[ -f "${ROOT_DIR}/.env" ]]; then
  ENV_FILE="${ROOT_DIR}/.env"
elif [[ -f /home/vansh/.secrets/pi-utility-server.env ]]; then
  ENV_FILE=/home/vansh/.secrets/pi-utility-server.env
elif [[ -f "${ROOT_DIR}/pi/.env" ]]; then
  ENV_FILE="${ROOT_DIR}/pi/.env"
else
  echo "ERROR: no env file found (set PI_ENV_FILE)" >&2
  exit 1
fi

load_env() {
  local f="$1"
  if [[ ! -f "$f" ]]; then
    echo "ERROR: env file not found at $f" >&2
    exit 1
  fi
  while IFS='=' read -r key val; do
    [[ -z "$key" || "$key" == \#* ]] && continue
    val="${val#\"}" val="${val%\"}"
    val="${val#\'}" val="${val%\'}"
    export "$key=$val"
  done < "$f"
}

load_env "$ENV_FILE"

TELEGRAM_BOT_TOKEN="${TELEGRAM_BOT_TOKEN:-}"
TELEGRAM_CHAT_ID="${TELEGRAM_CHAT_ID:-}"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"; }

send_telegram() {
  local message="$1"
  if [[ -n "$TELEGRAM_BOT_TOKEN" && -n "$TELEGRAM_CHAT_ID" ]]; then
    curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
      -d chat_id="${TELEGRAM_CHAT_ID}" \
      -d text="${message}" \
      -d parse_mode="HTML" >/dev/null 2>&1 || true
  fi
}

send_telegram "🔄 <b>Update started</b> on $(hostname) at $(date '+%Y-%m-%d %H:%M:%S')"

log "Pulling latest from origin..."
git -C "$ROOT_DIR" pull --ff-only || log "WARNING: git pull failed (continuing with local files)"

log "Running pre-update health check..."
bash "$SCRIPT_DIR/health-check.sh" || log "WARNING: Pre-update health check had failures"

log "Running pre-update backup..."
bash "$SCRIPT_DIR/backup.sh" || log "WARNING: Pre-update backup had failures"

# Image refs are digest-pinned (see pin-images-to-digest.sh). Pull the latest
# tag for each pinned-from ref, re-pin the compose files to the new digests,
# and commit the re-pin so the recreate step below uses current images.
PINNED_REFS=$(grep -rhoE 'pinned-from:[[:space:]]*[^ ]+' "$STACKS_DIR" --include='docker-compose.yml' 2>/dev/null | sed -E 's/.*pinned-from:[[:space:]]*//' | sort -u)
if [[ -n "$PINNED_REFS" ]]; then
  log "Refreshing pinned image tags..."
  for ref in $PINNED_REFS; do
    if docker pull "$ref" >/dev/null 2>&1; then
      log "  pulled $ref"
    else
      log "WARNING: pull failed for $ref (keeping current pin)"
    fi
  done
  log "Re-pinning compose files to updated digests..."
  bash "$SCRIPT_DIR/pin-images-to-digest.sh" >/dev/null 2>&1 || log "WARNING: re-pin script failed"
  if ! git -C "$ROOT_DIR" diff --quiet -- pi/stacks; then
    git -C "$ROOT_DIR" add pi/stacks
    git -C "$ROOT_DIR" commit -q -m "chore: re-pin image digests after update"
    log "Committed re-pinned digests"
  fi
fi

log "Starting update of all stacks (env-file: $ENV_FILE)..."

for stack in "${STACKS[@]}"; do
  COMPOSE_FILE="${STACKS_DIR}/${stack}/docker-compose.yml"
  if [[ ! -f "$COMPOSE_FILE" ]]; then
    log "SKIP (not found): $stack"
    continue
  fi
  log "Updating: $stack"
  if docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" pull; then
    docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" up -d --remove-orphans \
      || log "WARNING: '$stack' up failed"
  else
    log "WARNING: '$stack' pull failed (still attempting up)"
    docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" up -d --remove-orphans \
      || log "WARNING: '$stack' up failed"
  fi
done

log "Pruning unused images..."
docker image prune -f

log "Running post-update health check..."
sleep 30
HEALTH_OK=true
bash "$SCRIPT_DIR/health-check.sh" || HEALTH_OK=false

if $HEALTH_OK; then
  send_telegram "✅ <b>Update completed</b> on $(hostname) at $(date '+%Y-%m-%d %H:%M:%S')"
  log "All stacks updated successfully."
else
  send_telegram "⚠️ <b>Update completed with health check failures</b> on $(hostname) at $(date '+%Y-%m-%d %H:%M:%S') — investigate immediately"
  log "WARNING: Post-update health check had failures"
fi
