#!/usr/bin/env bash
# backup.sh - Restic backup to Backblaze B2 with Telegram notifications
# Schedule: 0 3 * * * /home/vansh/homelab-prod/scripts/backup.sh >> /var/log/homelab-backup.log 2>&1
# Requires: RESTIC_REPOSITORY, RESTIC_PASSWORD, B2_ACCOUNT_ID, B2_ACCOUNT_KEY, TELEGRAM_BOT_TOKEN, TELEGRAM_CHAT_ID in .env

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
ENV_FILE="${ROOT_DIR}/.env"

# Load environment
if [[ -f "$ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  set -a; source "$ENV_FILE"; set +a
else
  echo "ERROR: .env not found at $ENV_FILE" >&2
  exit 1
fi

# Required variables
: "${RESTIC_REPOSITORY:?RESTIC_REPOSITORY not set}"
: "${RESTIC_PASSWORD:?RESTIC_PASSWORD not set}"
: "${B2_ACCOUNT_ID:?B2_ACCOUNT_ID not set}"
: "${B2_ACCOUNT_KEY:?B2_ACCOUNT_KEY not set}"
: "${DATA_DIR:?DATA_DIR not set}"
: "${BACKUP_DIR:?BACKUP_DIR not set}"

# Optional with defaults
RESTIC_CACHE_DIR="${RESTIC_CACHE_DIR:-${DATA_DIR}/restic-cache}"
RESTIC_KEEP_DAILY="${RESTIC_KEEP_DAILY:-7}"
RESTIC_KEEP_WEEKLY="${RESTIC_KEEP_WEEKLY:-4}"
RESTIC_KEEP_MONTHLY="${RESTIC_KEEP_MONTHLY:-6}"

# Telegram (optional)
TELEGRAM_BOT_TOKEN="${TELEGRAM_BOT_TOKEN:-}"
TELEGRAM_CHAT_ID="${TELEGRAM_CHAT_ID:-}"

# Log file
LOG_DIR="${BACKUP_DIR}/logs"
mkdir -p "$LOG_DIR"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
LOG_FILE="${LOG_DIR}/backup-${TIMESTAMP}.log"

exec > >(tee -a "$LOG_FILE") 2>&1

# Telegram notification function
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

# Export for restic
export RESTIC_REPOSITORY
export RESTIC_PASSWORD
export B2_ACCOUNT_ID
export B2_ACCOUNT_KEY
export RESTIC_CACHE_DIR

# Ensure repo exists (idempotent)
if ! restic snapshots >/dev/null 2>&1; then
  echo "Repository not initialized -- running restic init"
  restic init
fi

# Paths to back up
BACKUP_PATHS=(
  "${DATA_DIR}/nextcloud/userdata"
  "${DATA_DIR}/vaultwarden"
  "${DATA_DIR}/homeassistant"
  "${DATA_DIR}/pihole"
  "${DATA_DIR}/grafana"
  "${DATA_DIR}/prometheus"
  "${ROOT_DIR}/config"
  "${ROOT_DIR}/stacks"
  "${ROOT_DIR}/scripts"
  "${ROOT_DIR}/docs"
  "${ROOT_DIR}/.env.example"
  "${ROOT_DIR}/Makefile"
  "${ROOT_DIR}/README.md"
  "${ROOT_DIR}/CHANGELOG.md"
  "${ROOT_DIR}/VERSION_ROADMAP.md"
  "${ROOT_DIR}/renovate.json"
)

# Filter existing paths
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

# Run backup
restic backup "${EXISTING_PATHS[@]}" \
  --tag "auto-$(date +%Y-%m-%d)" \
  --tag "hostname-$(hostname)" \
  --compression max \
  --verbose

BACKUP_EXIT=$?

if [[ $BACKUP_EXIT -eq 0 ]]; then
  echo "Backup completed successfully"
  send_telegram "✅ <b>Backup completed successfully</b> on $(hostname) at $(date '+%Y-%m-%d %H:%M:%S')"
else
  echo "Backup failed with exit code $BACKUP_EXIT" >&2
  send_telegram "❌ <b>Backup FAILED</b> on $(hostname) at $(date '+%Y-%m-%d %H:%M:%S') - Exit code: $BACKUP_EXIT"
  exit $BACKUP_EXIT
fi

# Forget/prune old snapshots per retention policy
echo "Applying retention policy: daily=$RESTIC_KEEP_DAILY weekly=$RESTIC_KEEP_WEEKLY monthly=$RESTIC_KEEP_MONTHLY"
restic forget \
  --keep-daily "$RESTIC_KEEP_DAILY" \
  --keep-weekly "$RESTIC_KEEP_WEEKLY" \
  --keep-monthly "$RESTIC_KEEP_MONTHLY" \
  --prune \
  --tag "hostname-$(hostname)"

# Verify repository readability (5% sample)
echo "Verifying repository (5% sample)..."
restic check --read-data-subset=5%

echo "=== Backup finished: $(date -Is) ==="
send_telegram "📦 <b>Backup finished</b> on $(hostname) at $(date '+%Y-%m-%d %H:%M:%S')"