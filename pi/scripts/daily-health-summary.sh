#!/usr/bin/env bash
# daily-health-summary.sh - Send a daily Telegram health summary for the Pi
# Schedule (systemd timer):
#   homelab-daily-summary.timer -> homelab-daily-summary.service
# Requires: TELEGRAM_BOT_TOKEN, TELEGRAM_CHAT_ID, RESTIC_REPOSITORY,
#           RESTIC_PASSWORD in env (PI_ENV_FILE).

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

while IFS='=' read -r key val; do
  [[ -z "$key" || "$key" == \#* ]] && continue
  val="${val#\"}" val="${val%\"}"
  val="${val#\'}" val="${val%\'}"
  export "$key=$val"
done < "$ENV_FILE"

: "${TELEGRAM_BOT_TOKEN:?TELEGRAM_BOT_TOKEN not set}"
: "${TELEGRAM_CHAT_ID:?TELEGRAM_CHAT_ID not set}"

TEMP_FILE=$(mktemp "${HOME}/.health-summary.XXXXXX")

# Rest of the script in a subshell so TEMP_FILE cleanup is preserved
(
  set -uo pipefail

  HOSTNAME="$(hostname)"
  UPTIME_INFO=$(uptime -p)
  LOAD_AVG=$(cut -d' ' -f1-3 /proc/loadavg)
  DATE_STR=$(date '+%Y-%m-%d %H:%M:%S %Z')

  # CPU temp + throttling
  TEMP=$(vcgencmd measure_temp 2>/dev/null | cut -d= -f2 || echo "N/A")
  THROTTLED=$(vcgencmd get_throttled 2>/dev/null | sed "s/throttled=//" || echo "N/A")

  # Memory + disk
  MEM_TOTAL=$(free -m | awk '/Mem:/{printf "%.0f", $2}')
  MEM_USED=$(free -m | awk '/Mem:/{printf "%.0f", $3}')
  MEM_PCT=$(awk -v u="$MEM_USED" -v t="$MEM_TOTAL" 'BEGIN {printf "%.0f", u/t*100}')
  DISK_PCT=$(df / | awk 'NR==2 {print $5}')
  NAS_PCT=$(df /mnt/nas | awk 'NR==2 {print $5}')
  DISK_USED=$(df -h / | awk 'NR==2 {print $3}')

  # Uptime / last restic snapshot
  LAST_RESTIC="N/A"
  if command -v restic >/dev/null 2>&1 || [[ -x "$HOME/bin/restic" ]]; then
    R_BIN="$HOME/bin/restic"; [[ -x "$R_BIN" ]] || R_BIN="$(command -v restic)"
    LAST_RESTIC=$(RESTIC_PASSWORD="$RESTIC_PASSWORD" RESTIC_REPOSITORY="$RESTIC_REPOSITORY" RESTIC_CACHE_DIR="${RESTIC_CACHE_DIR:-}" "$R_BIN" snapshots --latest 1 --no-lock 2>/dev/null | awk 'NR==4{print $3" "$4}' || echo "N/A")
  fi

  # Containers
  TOTAL_CONTAINERS=$(docker ps -q | wc -l)
  HEALTHY_CONTAINERS=$(docker ps --filter "health=healthy" -q | wc -l)
  RESTARTED=$(docker ps --format '{{.Names}} {{.Status}}' | grep -i "restart" || true)

  # Network (tailscale + ethernet)
  TS_STATUS="N/A"
  if command -v tailscale >/dev/null 2>&1; then
    TS_STATUS=$(tailscale status 2>/dev/null | head -n 1 || true)
  fi
  IPV4=$(ip -4 addr show eth0 | awk '/inet /{print $2}' | cut -d/ -f1)

  # Backups within last 36h?
  LAST_BACKUP_FILE=$(find "${BACKUP_DIR:-/mnt/nas/backup}/logs" -name "backup-*.log" -mmin -2160 2>/dev/null | sort | tail -n 1 || true)
  if [[ -n "$LAST_BACKUP_FILE" ]]; then
    BACKUP_STATUS="within last 36h (see $LAST_BACKUP_FILE)"
  else
    BACKUP_STATUS="NONE in last 36h -- check!"
  fi

  MESSAGE="<b>Pi Health Summary</b> - ${DATE_STR}
<b>Host:</b> ${HOSTNAME}
<b>Uptime:</b> ${UPTIME_INFO}
<b>CPU Temp:</b> ${TEMP} | <b>Throttled:</b> ${THROTTLED}
<b>Load (1/5/15):</b> ${LOAD_AVG}

<b>Memory:</b> ${MEM_USED}/${MEM_TOTAL} MB (${MEM_PCT}%)
<b>Root disk:</b> ${DISK_USED} used (${DISK_PCT})
<b>NAS disk:</b> ${NAS_PCT}

<b>Containers:</b> ${TOTAL_CONTAINERS} running, ${HEALTHY_CONTAINERS} healthy
<b>Tailscale:</b> ${TS_STATUS}
<b>Ethernet IP:</b> ${IPV4}

<b>Last restic snapshot:</b> ${LAST_RESTIC}
<b>Backup status:</b> ${BACKUP_STATUS}
"

  if [[ -n "$RESTARTED" ]]; then
    MESSAGE="${MESSAGE}
<b>⚠️ Restarting containers:</b>
${RESTARTED}
"
  fi

  curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
    -d chat_id="${TELEGRAM_CHAT_ID}" \
    -d text="${MESSAGE}" \
    -d parse_mode="HTML" >/dev/null 2>&1 || true
) >"$TEMP_FILE" 2>&1 || true

rm -f "$TEMP_FILE"
