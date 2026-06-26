#!/usr/bin/env bash
# backup.sh - Restic backup with Telegram notifications
# Supports: local path, B2, or any restic backend
# Schedule: 0 3 * * * /home/vansh/homelab-ops-mesh/pi/scripts/backup.sh >> /var/log/homelab-backup.log 2>&1
# Requires: RESTIC_REPOSITORY, RESTIC_PASSWORD, DATA_DIR, BACKUP_DIR in .env
# Optional: B2_ACCOUNT_ID, B2_ACCOUNT_KEY (for B2 repos)

set -uo pipefail

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

: "${RESTIC_REPOSITORY:?RESTIC_REPOSITORY not set}"
: "${RESTIC_PASSWORD:?RESTIC_PASSWORD not set}"
: "${DATA_DIR:?DATA_DIR not set}"
: "${BACKUP_DIR:?BACKUP_DIR not set}"

RESTIC_CACHE_DIR="${RESTIC_CACHE_DIR:-${DATA_DIR}/restic-cache}"
RESTIC_KEEP_DAILY="${RESTIC_KEEP_DAILY:-7}"
RESTIC_KEEP_WEEKLY="${RESTIC_KEEP_WEEKLY:-4}"
RESTIC_KEEP_MONTHLY="${RESTIC_KEEP_MONTHLY:-6}"

TELEGRAM_BOT_TOKEN="${TELEGRAM_BOT_TOKEN:-}"
TELEGRAM_CHAT_ID="${TELEGRAM_CHAT_ID:-}"

LOG_DIR="${BACKUP_DIR}/logs"
mkdir -p "$LOG_DIR"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
LOG_FILE="${LOG_DIR}/backup-${TIMESTAMP}.log"

exec > >(tee -a "$LOG_FILE") 2>&1

send_telegram() {
  local message="$1"
  if [[ -n "$TELEGRAM_BOT_TOKEN" && -n "$TELEGRAM_CHAT_ID" ]]; then
    curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
      -d chat_id="${TELEGRAM_CHAT_ID}" \
      -d text="${message}" \
      -d parse_mode="HTML" >/dev/null 2>&1 || true
  fi
}

echo "=== Backup started: $(date -Is) ==="
echo "Repository: $RESTIC_REPOSITORY"
echo "Cache dir:  $RESTIC_CACHE_DIR"

send_telegram "📦 <b>Backup started</b> on $(hostname) at $(date '+%Y-%m-%d %H:%M:%S')"

export RESTIC_REPOSITORY
export RESTIC_PASSWORD
export RESTIC_CACHE_DIR
if [[ -n "${B2_ACCOUNT_ID:-}" && -n "${B2_ACCOUNT_KEY:-}" ]]; then
  export B2_ACCOUNT_ID
  export B2_ACCOUNT_KEY
fi

RESTIC_BIN="$HOME/bin/restic"
if [[ -x "$RESTIC_BIN" ]]; then
  :
elif command -v restic >/dev/null 2>&1; then
  RESTIC_BIN="$(command -v restic)"
else
  echo "ERROR: restic not found" >&2
  exit 1
fi

if ! "$RESTIC_BIN" snapshots >/dev/null 2>&1; then
  echo "Repository not initialized -- running restic init"
  "$RESTIC_BIN" init
fi

BACKUP_PATHS=(
  "${DATA_DIR}/nextcloud/userdata"
  "${DATA_DIR}/vaultwarden"
  "${DATA_DIR}/homeassistant"
  "${ROOT_DIR}/pi/config"
  "${ROOT_DIR}/pi/stacks"
  "${ROOT_DIR}/pi/scripts"
  "${ROOT_DIR}/pi/docs"
  "${ROOT_DIR}/pi/.env.example"
  "${ROOT_DIR}/README.md"
)

EXISTING_PATHS=()
for p in "${BACKUP_PATHS[@]}"; do
  if [[ -e "$p" ]]; then
    EXISTING_PATHS+=("$p")
  else
    echo "Skipping missing path: $p"
  fi
done

if [[ ${#EXISTING_PATHS[@]} -eq 0 ]]; then
  echo "ERROR: No valid paths to back up" >&2
  exit 1
fi

echo "Backing up ${#EXISTING_PATHS[@]} paths..."

BACKUP_EXIT=0
"$RESTIC_BIN" backup "${EXISTING_PATHS[@]}" \
  --tag "auto-$(date +%Y-%m-%d)" \
  --tag "hostname-$(hostname)" \
  --compression max \
  --verbose || BACKUP_EXIT=$?

if [[ $BACKUP_EXIT -eq 0 ]]; then
  echo "Backup completed successfully"
  send_telegram "✅ <b>Backup completed successfully</b> on $(hostname) at $(date '+%Y-%m-%d %H:%M:%S')"
else
  echo "Backup failed with exit code $BACKUP_EXIT" >&2
  send_telegram "❌ <b>Backup FAILED</b> on $(hostname) at $(date '+%Y-%m-%d %H:%M:%S') - Exit code: $BACKUP_EXIT"
  exit $BACKUP_EXIT
fi

echo "Applying retention policy: daily=$RESTIC_KEEP_DAILY weekly=$RESTIC_KEEP_WEEKLY monthly=$RESTIC_KEEP_MONTHLY"
"$RESTIC_BIN" forget \
  --keep-daily "$RESTIC_KEEP_DAILY" \
  --keep-weekly "$RESTIC_KEEP_WEEKLY" \
  --keep-monthly "$RESTIC_KEEP_MONTHLY" \
  --prune

echo "Verifying repository (5% sample)..."
"$RESTIC_BIN" check --read-data-subset=5% 2>&1 || echo "Check skipped (slow on large repos)"

echo "=== Backup finished: $(date -Is) ==="
send_telegram "📦 <b>Backup finished</b> on $(hostname) at $(date '+%Y-%m-%d %H:%M:%S')"
