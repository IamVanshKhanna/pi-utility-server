#!/usr/bin/env bash
# update.sh - Pull latest images and recreate all stacks with Telegram notifications
# Schedule: 0 4 * * 0 bash /home/vansh/homelab-prod/scripts/update.sh >> /var/log/homelab-update.log 2>&1

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.."; pwd)"
ENV_FILE="${REPO_DIR}/.env"

# Load environment for Telegram
if [[ -f "$ENV_FILE" ]]; then
  set -a; source "$ENV_FILE"; set +a
fi
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

STACKS=(
  "stacks/core/docker-compose.yml"
  "stacks/network/docker-compose.yml"
  "stacks/secrets/docker-compose.yml"
  "stacks/auth/docker-compose.yml"
  "stacks/monitoring/docker-compose.yml"
  "stacks/apps/docker-compose.yml"
  "stacks/smarthome/docker-compose.yml"
  "stacks/uptime-kuma/docker-compose.yml"
  "stacks/crowdsec/docker-compose.yml"
  "stacks/tracing/docker-compose.yml"
  "stacks/nas/docker-compose.yml"
)

log "Starting pre-update health check..."
send_telegram "🔄 <b>Update started</b> on $(hostname) at $(date '+%Y-%m-%d %H:%M:%S')"
bash "$REPO_DIR/scripts/health-check.sh" || log "WARNING: Pre-update health check had failures"

log "Running pre-update backup..."
bash "$REPO_DIR/scripts/backup.sh" || log "WARNING: Pre-update backup had failures"

log "Starting update of all stacks..."

for STACK in "${STACKS[@]}"; do
  FULL_PATH="$REPO_DIR/$STACK"
  if [[ -f "$FULL_PATH" ]]; then
    log "Updating: $STACK"
    docker compose -f "$FULL_PATH" pull
    docker compose -f "$FULL_PATH" up -d --remove-orphans
    log "  OK: $STACK"
  else
    log "  SKIP (not found): $FULL_PATH"
  fi
done

log "Pruning unused images..."
docker image prune -f

log "Running post-update health check..."
sleep 30
bash "$REPO_DIR/scripts/health-check.sh" || log "WARNING: Post-update health check had failures"

send_telegram "✅ <b>Update completed</b> on $(hostname) at $(date '+%Y-%m-%d %H:%M:%S')"
log "All stacks updated successfully."
