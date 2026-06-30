#!/usr/bin/env bash
# daily-health-summary.sh - Generate and send daily health summary via Telegram
# Intended to run via systemd timer daily at 08:00 (homelab-daily-summary.timer)

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

# Required
: "${TELEGRAM_BOT_TOKEN:?TELEGRAM_BOT_TOKEN not set}"
: "${TELEGRAM_CHAT_ID:?TELEGRAM_CHAT_ID not set}"


generate_summary() {
  local date_str=$(date '+%Y-%m-%d %H:%M:%S')
  local hostname=$(hostname)
  
  # Pi system metrics
  local mem_info=$(free -h | awk '/Mem:/ {print $3 "/" $2}')
  local disk_nas=$(df -h /mnt/nas | awk 'NR==2 {print $3 "/" $2 " (" $5 ")"}')
  local cpu_temp=$(vcgencmd measure_temp 2>/dev/null | cut -d= -f2 | cut -d"'" -f1 || echo "N/A")
  
  # Pi container status
  local pi_total=$(docker ps -q | wc -l)
  local pi_unhealthy=$(docker ps --filter "health=unhealthy" -q | wc -l)
  
  # Windows metrics from Prometheus
  local win_targets_up="N/A"
  local alerts_firing="N/A"
  if [[ -n "${WINDOWS_IP:-}" ]]; then
    win_targets_up=$(curl -s --max-time 5 "http://${WINDOWS_IP}:9090/api/v1/query?query=count(up==1)" 2>/dev/null \
      | jq -r '.data.result[0].value[1] // empty' 2>/dev/null || echo "N/A")
    alerts_firing=$(curl -s --max-time 5 "http://${WINDOWS_IP}:9090/api/v1/alerts" 2>/dev/null \
      | jq -r '[.data.alerts[] | select(.state=="firing")] | length' 2>/dev/null || echo "N/A")
  fi
  
  # Backup info
  local restic_bin="${HOME}/bin/restic"
  if [[ -x "$restic_bin" ]]; then
    :
  elif command -v restic >/dev/null 2>&1; then
    restic_bin=$(command -v restic)
  fi
  local last_backup=$("$restic_bin" snapshots --latest 1 --json 2>/dev/null | jq -r '.[0].time' 2>/dev/null | cut -dT -f1 || echo "Unknown")
  
  # Load average
  local load=$(cat /proc/loadavg | awk '{print $1 " " $2 " " $3}')
  
  cat <<EOF
🏠 <b>Daily Homelab Health</b> — $date_str

<b>📗 autobot (Pi 4B)</b>
• RAM: $mem_info
• NAS: $disk_nas
• Temp: ${cpu_temp}°C | Load: $load
• Containers: $pi_total$( [[ $pi_unhealthy -gt 0 ]] && echo " ⚠️${pi_unhealthy} unhealthy" || echo "")

<b>📘 mr-stranger (Windows)</b>
• Prometheus targets: $win_targets_up/8 up
• Firing alerts: $alerts_firing

<b>💾 Backup</b>
• Last snapshot: $last_backup

🤖 <i>homelab-ops-mesh v1.5</i>
EOF
}

send_telegram() {
  local message="$1"
  curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
    -d chat_id="${TELEGRAM_CHAT_ID}" \
    -d text="$message" \
    -d parse_mode="HTML" \
    -d disable_web_page_preview="true" >/dev/null
}

main() {
  local summary=$(generate_summary)
  send_telegram "$summary"
  echo "Daily health summary sent at $(date)"
}

main "$@"