#!/usr/bin/env bash
# secrets-rotation.sh - Check and notify about secrets rotation status
# Called by homelab-secrets-rotation.timer (weekly)
# This script checks the age of secrets and sends a Telegram notification
# if any are older than the rotation threshold.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
ENV_FILE="${ROOT_DIR}/.env"

load_env() {
  local f="$1"
  if [[ ! -f "$f" ]]; then
    echo "ERROR: .env not found at $f" >&2
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

ROTATION_DAYS="${SECRETS_ROTATION_DAYS:-90}"
TELEGRAM_BOT_TOKEN="${TELEGRAM_BOT_TOKEN:-}"
TELEGRAM_CHAT_ID="${ADMIN_CHAT_IDS:-${TELEGRAM_CHAT_ID:-}}"

send_telegram() {
  local message="$1"
  if [[ -n "$TELEGRAM_BOT_TOKEN" && -n "$TELEGRAM_CHAT_ID" ]]; then
    curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
      -d chat_id="${TELEGRAM_CHAT_ID%%,*}" \
      -d text="${message}" \
      -d parse_mode="HTML" >/dev/null 2>&1 || true
  fi
}

NOW=$(date +%s)
THRESHOLD=$((ROTATION_DAYS * 86400))
NEEDS_ROTATION=()

for envfile in "${ROOT_DIR}"/.env "${ROOT_DIR}"/windows/.env; do
  if [[ -f "$envfile" ]]; then
    FILE_AGE=$(( NOW - $(stat -c %Y "$envfile" 2>/dev/null || stat -f %m "$envfile" 2>/dev/null || echo 0) ))
    if [[ $FILE_AGE -gt $THRESHOLD ]]; then
      NEEDS_ROTATION+=("$(basename "$envfile") (${FILE_AGE} days old)")
    fi
  fi
done

if [[ ${#NEEDS_ROTATION[@]} -gt 0 ]]; then
  MSG="<b>Secrets Rotation Reminder</b> on $(hostname)%0A%0A"
  for item in "${NEEDS_ROTATION[@]}"; do
    MSG+="- ${item}%0A"
  done
  MSG+="%0ARotation threshold: ${ROTATION_DAYS} days"
  send_telegram "$MSG"
else
  send_telegram "<b>Secrets Rotation Check</b> on $(hostname): All secrets within rotation threshold (${ROTATION_DAYS} days)"
fi
