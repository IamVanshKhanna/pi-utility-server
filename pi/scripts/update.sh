#!/usr/bin/env bash
# update.sh - Pull latest images and recreate all stacks with Telegram notifications
# Schedule: 0 4 * * 0 bash /home/vansh/homelab-ops-mesh/pi/scripts/update.sh >> /var/log/homelab-update.log 2>&1

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
ENV_FILE="${REPO_DIR}/.env"

load_env() {
  local f="$1"
  if [[ -f "$f" ]]; then
    while IFS='=' read -r key val; do
      [[ -z "$key" || "$key" == \#* ]] && continue
      val="${val#\"}" val="${val%\"}"
      val="${val#\'}" val="${val%\'}"
      export "$key=$val"
    done < "$f"
  fi
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

STACKS=(
  "pi/stacks/core/docker-compose.yml"
  "pi/stacks/network/docker-compose.yml"
  "pi/stacks/headscale/docker-compose.yml"
  "pi/stacks/gitops/docker-compose.yml"
  "pi/stacks/apps/docker-compose.yml"
  "pi/stacks/smarthome/docker-compose.yml"
  "pi/stacks/uptime-kuma/docker-compose.yml"
  "pi/stacks/crowdsec/docker-compose.yml"
  "pi/stacks/nas/docker-compose.yml"
  "pi/stacks/portfolio/docker-compose.yml"
  "pi/stacks/monitoring/docker-compose.yml"
)

log "Starting pre-update health check..."
send_telegram "🔄 <b>Update started</b> on $(hostname) at $(date '+%Y-%m-%d %H:%M:%S')"
bash "$REPO_DIR/pi/scripts/health-check.sh" || log "WARNING: Pre-update health check had failures"

log "Running pre-update backup..."
bash "$REPO_DIR/pi/scripts/backup.sh" || log "WARNING: Pre-update backup had failures"

log "Starting update of all stacks..."

for STACK in "${STACKS[@]}"; do
  FULL_PATH="$REPO_DIR/$STACK"
  if [[ -f "$FULL_PATH" ]]; then
    log "Updating: $STACK"
    docker compose -f "$FULL_PATH" --env-file "$ENV_FILE" pull
    docker compose -f "$FULL_PATH" --env-file "$ENV_FILE" up -d --remove-orphans
    log "  OK: $STACK"
  else
    log "  SKIP (not found): $FULL_PATH"
  fi
done

log "Pruning unused images..."
docker image prune -f

log "Ensuring act-runner systemd service is running..."
systemctl --user is-active act-runner.service >/dev/null 2>&1 || systemctl --user start act-runner.service

log "Running post-update health check..."
sleep 30
HEALTH_OK=true
bash "$REPO_DIR/pi/scripts/health-check.sh" || HEALTH_OK=false

if $HEALTH_OK; then
  send_telegram "✅ <b>Update completed</b> on $(hostname) at $(date '+%Y-%m-%d %H:%M:%S')"
  log "All stacks updated successfully."
else
  send_telegram "⚠️ <b>Update completed with health check failures</b> on $(hostname) at $(date '+%Y-%m-%d %H:%M:%S') — investigate immediately"
  log "WARNING: Post-update health check had failures"
fi
