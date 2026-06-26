#!/usr/bin/env bash
# Weekly OS backup script for Pi 4B
# Backups root filesystem to /mnt/nas/backup/os/
# Keeps 4 weekly backups, then monthly

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
ENV_FILE="${ROOT_DIR}/.env"

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

BACKUP_DIR="${BACKUP_DIR:-/mnt/nas/backup}/os"
RETENTION_WEEKLY=4
DATE=$(date +%Y-%m-%d)
BACKUP_PATH="${BACKUP_DIR}/${DATE}"

mkdir -p "${BACKUP_PATH}"

echo "[$(date)] Starting OS backup to ${BACKUP_PATH}"

rsync -aAXv \
  --delete \
  --exclude={"/dev/*","/proc/*","/sys/*","/tmp/*","/run/*","/mnt/*","/media/*","/lost+found","/swapfile","/var/swap"} \
  / "${BACKUP_PATH}/" \
  > "${BACKUP_DIR}/backup-${DATE}.log" 2>&1

echo "[$(date)] Backup complete: ${BACKUP_PATH}"

ls -1dt "${BACKUP_DIR}"/*/ 2>/dev/null | tail -n +$((RETENTION_WEEKLY + 1)) | while read -r old; do
  echo "[$(date)] Removing old backup: ${old}"
  rm -rf "${old}"
done

echo "[$(date)] Done"
