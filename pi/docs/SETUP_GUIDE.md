# Step-by-Step Setup Guide — homelab-ops-mesh

> Full setup from blank SSD to fully running multi-node homelab on Raspberry Pi 4B 4GB + Windows Docker Desktop.

---

## Phase 1 — Flash OS to SSD

1. Download **Raspberry Pi Imager** on your computer
2. Select: `Raspberry Pi OS Lite (64-bit)` — Bookworm/Trixie
3. Select your 2TB SSD as target (via USB adapter)
4. Click gear icon and set:
   - Hostname: `autobot`
   - Enable SSH with publickey only
   - Username: `vansh`, strong password
   - Timezone: `Australia/Melbourne`
5. Flash and insert SSD into DeskPi3 Pro

---

## Phase 2 — Boot from SSD

```bash
sudo raspi-config
# Advanced Options > Boot Order > USB Boot (B2)
# Reboot and remove SD card
```

---

## Phase 3 — Set Static IP

SSH in: `ssh vansh@<your-pi-ip>`

Set static IP via router DHCP reservation (preferred) OR:

```bash
sudo nano /etc/dhcpcd.conf
# Add:
interface eth0
static ip_address=192.168.68.59/24
static routers=192.168.68.1
static domain_name_servers=1.1.1.1 8.8.8.8
```

```bash
sudo reboot
```

---

## Phase 4 — Clone Repo and Install Docker

```bash
sudo apt-get install -y git
git clone https://github.com/IamVanshKhanna/homelab-ops-mesh.git
cd homelab-ops-mesh/pi
chmod +x scripts/*.sh
```

Install Docker and add user to group:
```bash
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
```

Log out and back in after completion (Docker group permissions):
```bash
exit
ssh vansh@192.168.68.59
```

---

## Phase 5 — Configure Environment

```bash
cp .env.example .env
nano .env
```

Fill in every value. Generate strong passwords:
```bash
openssl rand -base64 32           # general passwords
openssl rand -base64 48           # Vaultwarden admin token
openssl rand -base64 32           # Restic encryption password
```

> Never commit your `.env` — it is in `.gitignore`

**Required variables:**
- `TELEGRAM_BOT_TOKEN`, `TELEGRAM_CHAT_ID` — for Alertmanager alerts + TinyBot
- `ADMIN_CHAT_IDS` — TinyBot admin authorization
- `RELAY_TOKEN` — CrowdSec relay bearer token
- `RESTIC_PASSWORD` — Restic repo encryption
- `BACKUP_DIR` — Backup destination (default: `/mnt/nas/backup`)
- `WINDOWS_IP` — Windows Tailscale IP for cross-node routing
- `DOMAIN` — Tailscale MagicDNS domain (e.g. `autobot.taila24d04.ts.net`)
- `MYSQL_ROOT_PASSWORD`, `MYSQL_DATABASE`, `MYSQL_USER`, `MYSQL_PASSWORD` — Nextcloud/MariaDB
- `NEXTCLOUD_ADMIN_USER`, `NEXTCLOUD_ADMIN_PASSWORD`, `NEXTCLOUD_TRUSTED_DOMAINS`
- `CROWDSEC_API_KEY` — CrowdSec API key
- `WINDOWS_IP` — Windows Tailscale IP for cross-node routing + Prometheus scrape targets

> Also copy `.template` files to real files and fill in real values:
> - `pi/config/traefik/dynamic.yml.template` → `dynamic.yml`
> - `windows/config/alertmanager/alertmanager.yml.template` → `alertmanager.yml`
> - `windows/config/authelia/users_database.yml.template` → `users_database.yml`

---

## Phase 6 — Tailscale Setup + HTTPS

```bash
# On Pi (after Docker install)
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up --ssh --advertise-exit-node --hostname=autobot
# Visit the auth URL, login to Tailscale

# Enable Tailscale Serve for HTTPS
sudo tailscale serve https+insecure://localhost:8443

# On your laptop/phone:
# Install Tailscale app, login to same tailnet
# ssh vansh@autobot  # Works via MagicDNS!
```

No domain purchase needed — Tailscale MagicDNS provides zero-cost HTTPS.

---

## Phase 7 — Deploy Pi Stacks In Order

```bash
cd ~/homelab-ops-mesh/pi

# 1. Core (Traefik + Portainer) - ALWAYS FIRST
docker compose -f stacks/core/docker-compose.yml --env-file ../../.env up -d
docker logs traefik --tail 20

# Wait for Traefik to be healthy

# 2. Network (Pi-hole + exporter)
docker compose -f stacks/network/docker-compose.yml --env-file ../../.env up -d

# 3. Monitoring (Promtail + cAdvisor + Node Exporter)
docker compose -f stacks/monitoring/docker-compose.yml --env-file ../../.env up -d

# 4. NAS (Samba + Syncthing)
docker compose -f stacks/nas/docker-compose.yml --env-file ../../.env up -d

# 5. Apps (Nextcloud + MariaDB + Vaultwarden)
docker compose -f stacks/apps/docker-compose.yml --env-file ../../.env up -d
# Wait 2-3 mins for Nextcloud DB init
docker logs nextcloud --tail 20

# 6. Smart Home (Home Assistant)
docker compose -f stacks/smarthome/docker-compose.yml --env-file ../../.env up -d

# 7. Uptime Kuma
docker compose -f stacks/uptime-kuma/docker-compose.yml --env-file ../../.env up -d

# 8. CrowdSec + Relay
docker compose -f stacks/crowdsec/docker-compose.yml --env-file ../../.env up -d

# 9. Portfolio
docker compose -f stacks/portfolio/docker-compose.yml --env-file ../../.env up -d
```

---

## Phase 8 — Deploy Windows Stacks

On your Windows machine with Docker Desktop:

```bash
cd homelab-ops-mesh/windows

# 1. Auth (Authelia + Redis) - creates homelab_win network
docker compose -f stacks/auth/docker-compose.yml --env-file ../.env up -d

# 2. Monitoring (Grafana, Prometheus, Alertmanager, Loki)
docker compose -f stacks/monitoring/docker-compose.yml --env-file ../.env up -d

# 3. Secrets (Infisical + PostgreSQL + Redis)
docker compose -f stacks/secrets/docker-compose.yml --env-file ../.env up -d

# 4. Tracing (Tempo)
docker compose -f stacks/tracing/docker-compose.yml --env-file ../.env up -d
```

---

## Phase 9 — Schedule Maintenance

```bash
crontab -e
```

Add:
```bash
# Daily backup at 3am (with alerting on failure)
0 3 * * * /home/vansh/homelab-ops-mesh/pi/scripts/backup.sh >> /var/log/homelab-backup.log 2>&1

# Weekly update Sunday 4am
0 4 * * 0 /home/vansh/homelab-ops-mesh/pi/scripts/update.sh >> /var/log/homelab-update.log 2>&1
```

---

## Phase 10 — Verify

```bash
# Quick health check
docker ps
vcgencmd measure_temp   # Should be 45-55°C at idle
df -h                   # Check disk usage
free -h                 # Check RAM + ZRAM
```

---

## Service Access URLs

All services accessible via Tailscale MagicDNS at `https://autobot.taila24d04.ts.net/<path>`:

| Service | Path | Notes |
|---------|------|-------|
| Traefik dashboard | `/dashboard/` | Basic auth |
| Portainer | 127.0.0.1:9000 | Local only |
| Pi-hole admin | 127.0.0.1:8053 | Local only |
| Nextcloud | `/nextcloud/` | File cloud |
| Vaultwarden | `/vault/` | Password manager |
| Home Assistant | `/hass/` | Home automation |
| Grafana | `/grafana/` | Dashboards (Windows) |
| Authelia | `/auth/` | SSO login (Windows) |
| Infisical | `/secrets/` | Secrets management (Windows) |
| Uptime Kuma | 127.0.0.1:8082 | Local only |

---

## Backup & Restore

```bash
# Manual backup (with Telegram alerting on failure)
bash ~/homelab-ops-mesh/pi/scripts/backup.sh

# Verify backup
restic -r /mnt/nas/backup/restic-repo check

# Test restore
restic -r /mnt/nas/backup/restic-repo restore latest --target /mnt/restore-test
```

---

## Updates

```bash
# Use update script
bash ~/homelab-ops-mesh/pi/scripts/update.sh

# Or manually per stack
docker compose -f stacks/<stack>/docker-compose.yml --env-file ../../.env pull
docker compose -f stacks/<stack>/docker-compose.yml --env-file ../../.env up -d
```
