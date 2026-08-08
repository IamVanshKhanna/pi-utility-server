#!/usr/bin/env bash
# backup-os.sh - Full system (rsync) backup of the Raspberry Pi OS
# Schedule (cron):
#   0 2 * * 6 PI_ENV_FILE=/home/vansh/.secrets/pi-utility-server.env \
#     /mnt/nas/02. shared/01. PI Files/01. pi-utility-server/pi/scripts/backup-os.sh
# Backs up the root filesystem to BACKUP_DIR (default /mnt/nas/backup/backup-os).
# Virtual filesystems, mounted NAS shares, swap, and the backup dir itself
# are excluded. Docker volumes stay in /var/lib/docker and are covered by
# backup.sh; they are NOT duplicated here.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"

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

BACKUP_PATH="${BACKUP_DIR:-/mnt/nas/backup}/backup-os"
BACKUP_LOGS="${BACKUP_DIR:-/mnt/nas/backup}/logs"

mkdir -p "$BACKUP_PATH" "$BACKUP_LOGS"

TIMESTAMP=$(date +%Y%m%d-%H%M%S)
LOG_FILE="${BACKUP_LOGS}/backup-os-${TIMESTAMP}.log"

# Only keep the last 4 full system snapshots to bound disk usage.
KEEP_LAST=4

exec > >(tee -a "$LOG_FILE") 2>&1

echo "=== OS backup started: $(date -Is) ==="
echo "Source: /"
echo "Target: $BACKUP_PATH"
echo "Env file: $ENV_FILE"

# Root rsync. Explicit --exclude args (NOT --exclude={...}: brace expansion
# does not happen inside quotes) plus --one-file-system so mounted volumes
# (NAS shares, /boot/firmware is fine) are never walked.
rsync -aAXHv \
  --delete \
  --delete-excluded \
  --one-file-system \
  --exclude=/dev/* \
  --exclude=/proc/* \
  --exclude=/sys/* \
  --exclude=/tmp/* \
  --exclude=/run/* \
  --exclude=/mnt/* \
  --exclude=/media/* \
  --exclude=/swapfile \
  --exclude=/lost+found/* \
  --exclude="${BACKUP_DIR:-/mnt/nas/backup}/*" \
  / "${BACKUP_PATH}/"

RSYNC_EXIT=$?
if [[ $RSYNC_EXIT -ne 0 ]]; then
  echo "rsync failed with exit code $RSYNC_EXIT" >&2
  exit $RSYNC_EXIT
fi

# Prune old snapshots (keep newest KEEP_LAST).
SNAPSHOTS=()
while IFS= read -r -d '' dir; do
  SNAPSHOTS+=("$dir")
done < <(find "$BACKUP_PATH" -mindepth 1 -maxdepth 1 -type d -printf '%T@\t%p\0' | sort -rz)

if [[ ${#SNAPSHOTS[@]} -gt 0 ]]; then
  echo "Retaining the most recent $KEEP_LAST snapshot(s)..."
  for ((i = KEEP_LAST; i < ${#SNAPSHOTS[@]}; i++)); do
    path="${SNAPSHOTS[$i]#*$'\t'}"
    echo "Removing old snapshot: $path"
    rm -rf "$path"
  done
fi

echo "=== OS backup finished: $(date -Is) ==="
