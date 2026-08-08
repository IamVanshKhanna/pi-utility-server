#!/usr/bin/env bash
# secrets-rotation.sh - Rotate low-impact homelab secrets on a schedule.
# Currently rotates only VAULTWARDEN_ADMIN_TOKEN (the vaultwarden admin panel
# token). SAMBA_PASSWORD and PIHOLE_WEBPASSWORD are intentionally NOT rotated
# automatically: doing so would lock out SMB clients and the pihole UI
# weekly. See ADR-010.
# Scheduled: Sun 03:00 via homelab-secrets-rotation.timer
set -euo pipefail

ENV_FILE="${PI_ENV_FILE:-/home/vansh/.secrets/pi-utility-server.env}"
VAULTWARDEN_CONTAINER="${VAULTWARDEN_CONTAINER:-vaultwarden}"
COMPOSE_DIR="/mnt/nas/02. shared/01. PI Files/01. pi-utility-server/pi/stacks/apps"

[[ -f "$ENV_FILE" ]] || { echo "ERROR: env file not found: $ENV_FILE" >&2; exit 1; }

send_telegram() {
  local message="$1" token="" chat=""
  token="$(grep '^TELEGRAM_BOT_TOKEN=' "$ENV_FILE" | cut -d= -f2)"
  chat="$(grep '^TELEGRAM_CHAT_ID=' "$ENV_FILE" | cut -d= -f2)"
  if [[ -n "$token" && -n "$chat" ]]; then
    curl -s -X POST "https://api.telegram.org/bot${token}/sendMessage" \
      -d chat_id="${chat}" -d text="${message}" \
      -d parse_mode="HTML" >/dev/null 2>&1 || true
  fi
}

if command -v openssl >/dev/null 2>&1; then
  NEW_TOKEN="$(openssl rand -hex 24)"
else
  NEW_TOKEN="$(head -c 32 /dev/urandom | base64 | tr -d '=+/' )"
fi
[[ -n "$NEW_TOKEN" ]] || { echo "ERROR: could not generate a new token" >&2; exit 1; }

# Atomically rewrite the env file, replacing only VAULTWARDEN_ADMIN_TOKEN.
# mktemp lives next to the env file because ProtectSystem=strict makes /tmp
# read-only for this unit (ReadWritePaths covers /home/vansh/.secrets).
TMP="$(mktemp "${ENV_FILE}.XXXXXX")" || { echo "ERROR: mktemp failed" >&2; exit 1; }
found=0
while IFS='=' read -r key val; do
  if [[ -z "$key" ]]; then
    printf '\n' >> "$TMP"
  elif [[ "$key" == \#* ]]; then
    printf '%s=%s\n' "$key" "$val" >> "$TMP"
  elif [[ "$key" == "VAULTWARDEN_ADMIN_TOKEN" ]]; then
    printf '%s=%s\n' "$key" "$NEW_TOKEN" >> "$TMP"
    found=1
  else
    printf '%s=%s\n' "$key" "$val" >> "$TMP"
  fi
done < "$ENV_FILE"
if [[ $found -eq 0 ]]; then
  printf 'VAULTWARDEN_ADMIN_TOKEN=%s\n' "$NEW_TOKEN" >> "$TMP"
fi
chmod 600 "$TMP"
mv "$TMP" "$ENV_FILE"
echo "VAULTWARDEN_ADMIN_TOKEN rotated on $(hostname) at $(date -Is)"

# Restart vaultwarden so it picks up the new token.
if command -v docker >/dev/null 2>&1 && \
   docker ps --format '{{.Names}}' | grep -qx "$VAULTWARDEN_CONTAINER"; then
  if (cd "$COMPOSE_DIR" && docker compose --env-file "$ENV_FILE" up -d --force-recreate "$VAULTWARDEN_CONTAINER"); then
    send_telegram "🔑 <b>Secrets rotated</b> on $(hostname) at $(date '+%Y-%m-%d %H:%M:%S'). New VAULTWARDEN_ADMIN_TOKEN: <code>${NEW_TOKEN}</code>"
  else
    echo "WARNING: vaultwarden restart failed - token rotated but not yet active" >&2
    send_telegram "⚠️ <b>Secrets rotated</b> on $(hostname) but vaultwarden restart FAILED. New VAULTWARDEN_ADMIN_TOKEN: <code>${NEW_TOKEN}</code>"
    exit 0
  fi
else
  echo "WARNING: vaultwarden container not running - token rotated for next start" >&2
  send_telegram "🔑 <b>Secrets rotated</b> on $(hostname) at $(date '+%Y-%m-%d %H:%M:%S'). New VAULTWARDEN_ADMIN_TOKEN: <code>${NEW_TOKEN}</code>"
fi
