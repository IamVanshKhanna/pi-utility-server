#!/bin/bash
# Weekly OS backup script for Pi 4B
# Backups root filesystem to /mnt/data/backups/os/
# Keeps 4 weekly backups, then monthly

set -euo pipefail

BACKUP_DIR="${BACKUP_DIR:-/mnt/data/backups/os}"
RETENTION_WEEKLY=4
DATE=$(date +%Y-%m-%d)
BACKUP_PATH="${BACKUP_DIR}/${DATE}"

# Ensure backup directory exists
mkdir -p "${BACKUP_PATH}"

echo "[$(date)] Starting OS backup to ${BACKUP_PATH}"

# rsync root (excluding special dirs and data partition)
rsync -aAXv   --delete   --exclude={"/dev/*","/proc/*","/sys/*","/tmp/*","/run/*","/mnt/*","/media/*","/lost+found","/swapfile","/var/swap"}   / "${BACKUP_PATH}/"   > "${BACKUP_DIR}/backup-${DATE}.log" 2>&1

echo "[$(date)] Backup complete: ${BACKUP_PATH}"

# Prune old weekly backups (keep last 4)
ls -1dt "${BACKUP_DIR}"/*/ | tail -n +$((RETENTION_WEEKLY + 1)) | while read old; do
  echo "[$(date)] Removing old backup: ${old}"
  rm -rf "${old}"
done

echo "[$(date)] Done"
