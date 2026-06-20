# Step-by-Step Setup Guide — homelab-prod v1.2

> Full setup from blank SSD to fully running homelab on Raspberry Pi 4B 4GB.

---

## Phase 1 — Flash OS to SSD

1. Download **Raspberry Pi Imager** on your computer
2. Select: `Raspberry Pi OS Lite (64-bit)` — Bookworm
3. Select your 2TB SSD as target (via USB adapter)
4. Click gear icon and set:
   - Hostname: `homelab`
   - Enable SSH with password
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
static ip_address=192.168.1.50/24
static routers=192.168.1.1
static domain_name_servers=1.1.1.1 8.8.8.8
```

```bash
sudo reboot
```

---

## Phase 4 — Clone Repo and Run Setup

```bash
sudo apt-get install -y git
git clone https://github.com/IamVanshKhanna/homelab-prod.git
cd homelab-prod
chmod +x scripts/setup.sh
sudo bash scripts/setup.sh
```

Log out and back in after completion (Docker group permissions):
```bash
exit
ssh vansh@192.168.1.50
```

---

## Phase 5 — Configure Environment (v1.2)

```bash
cp .env.example .env
nano .env
```

Fill in every value. Generate strong passwords:
```bash
openssl rand -base64 32           # general passwords
openssl rand -base64 48           # Vaultwarden admin token
openssl rand -base64 32           # Restore backup password
echo $(htpasswd -nB admin) | sed -e 's/$/$$/g'  # Traefik basic auth
```

> Never commit your `.env` — it is in `.gitignore`

**Required variables for v1.2:**
- `TELEGRAM_BOT_TOKEN`, `TELEGRAM_CHAT_ID` — for Alertmanager alerts
- `RESTIC_PASSWORD` — Restic repo encryption
- `B2_ACCOUNT_ID`, `B2_ACCOUNT_KEY`, `B2_BUCKET` — Backblaze B2
- `RESTIC_REPOSITORY=b2:${B2_BUCKET}:homelab-prod`

**Infisical variables (generated on first deploy):**
- `INFISICAL_AUTH_SECRET` — `openssl rand -base64 32`
- `INFISICAL_ENCRYPTION_KEY` — `openssl rand -base64 32`
- `INFISICAL_REDIS_PASSWORD` — `openssl rand -base64 32`
- `INFISICAL_DB_PASSWORD` — `openssl rand -base64 32`

> Never commit your `.env` — it is in `.gitignore`

---

## Phase 6 — Free Domain (DuckDNS) + TLS

1. Sign in at https://www.duckdns.org
2. Create subdomain e.g. `myhomelab.duckdns.org`
3. Point to your home public IP
4. Auto-update cron on Pi:
```bash
mkdir -p ~/duckdns
nano ~/duckdns/duck.sh
# Paste:
echo url="https://www.duckdns.org/update?domains=YOUR_SUBDOMAIN&token=YOUR_TOKEN&ip=" | curl -k -o ~/duckdns/duck.log -K -
chmod +x ~/duckdns/duck.sh
crontab -e
# Add: */5 * * * * ~/duckdns/duck.sh >/dev/null 2>&1
```
5. Forward on router: `80 TCP`, `443 TCP`, `51820 UDP` → `192.168.1.50`

---

## Phase 7 — Deploy Stacks In Order (v1.2)

```bash
cd ~/homelab-prod

# 1. Core (Traefik + Portainer) - ALWAYS FIRST
make up-phase1
docker logs traefik --tail 20

# Wait for Traefik certs (check logs for ACME success)

# 2. Secrets (Infisical) - NEW in v1.2
make up-phase2
docker logs infisical --tail 20
# Wait for Infisical to be healthy

# On first Infisical deploy:
# 1. Visit https://infisical.yourdomain.com
# 2. Create admin account
# 3. Create project "homelab-prod"
# 4. Add all .env secrets as Infisical secrets (see docs/ADR-004-secrets.md)
# 4. Generate AUTH_SECRET, ENCRYPTION_KEY, REDIS_PASSWORD in Infisical if not in .env

# 3. Monitoring (Prometheus, Grafana, Loki, Promtail, Alertmanager, Node Exporter, cAdvisor)
make up-phase3
docker logs grafana --tail 10

# 4. Apps (Nextcloud + MariaDB + Redis, Vaultwarden, Ollama)
make up-phase4
# Wait 2-3 mins for Nextcloud DB init
docker logs nextcloud --tail 20

# Pull Ollama model (use small models on 4GB RAM)
docker exec ollama ollama pull gemma:2b

# 5. Smart Home (Home Assistant)
make up-phase5

# 6. Uptime Kuma (external monitoring)
make up-phase6
```

---

## Phase 8 — Tailscale Remote Access

```bash
# Run on Pi (after setup.sh, which installs Tailscale)
sudo tailscale up --ssh --advertise-exit-node --hostname=AutoBot
# Visit the auth URL, login to Tailscale

# On your laptop/phone:
# Install Tailscale app, login to same tailnet
# ssh vansh@AutoBot  # Works via MagicDNS!
```

---

## Phase 9 — Schedule Maintenance

```bash
crontab -e
```

Add:
```bash
# Daily backup at 3am (with alerting on failure)
0 3 * * * /home/vansh/homelab-prod/scripts/backup-wrapper.sh >> /var/log/homelab-backup.log 2>&1

# Health check every 15 minutes
*/15 * * * * /home/vansh/homelab-prod/scripts/health-check.sh >> /var/log/homelab-health.log 2>&1

# Weekly update Sunday 4am
0 4 * * 0 /home/vansh/homelab-prod/scripts/update.sh >> /var/log/homelab-update.log 2>&1

# DuckDNS update every 5 minutes
*/5 * * * * ~/duckdns/duck.sh >/dev/null 2>&1
```

---

## Phase 10 — Verify (v1.2)

```bash
# Full health check (includes Infisical, Loki, Alertmanager, Uptime Kuma)
make verify-v1

# Or individually:
bash scripts/health-check.sh --strict

# Check backup
make verify-backup
make restore-test

# Check key metrics
docker ps
vcgencmd measure_temp   # Should be 45-55°C at idle
df -h                   # Check disk usage
free -h                 # Check RAM + ZRAM
```

---

## Service Access URLs (v1.2)

| Service | URL |
|---------|-----|
| Traefik dashboard | https://traefik.yourdomain.com |
| Portainer | https://portainer.yourdomain.com |
| **Infisical** | https://infisical.yourdomain.com |
| Nextcloud | https://cloud.yourdomain.com |
| Vaultwarden | https://vault.yourdomain.com |
| Grafana | https://grafana.yourdomain.com |
| Home Assistant | http://192.168.1.50:8123 |
| Pi-hole | http://192.168.1.50:8053/admin |
| Ollama API | http://192.168.1.50:11434 |
| Prometheus | http://192.168.1.50:9090 |
| Alertmanager | http://192.168.1.50:9093 |
| Loki | http://192.168.1.50:3100 |
| Uptime Kuma | https://uptime.yourdomain.com |
| Promtail | http://192.168.1.50:9080 |

---

## Grafana Dashboards (pre-provisioned)

- **Homelab System Overview** — RAM, CPU, temp, disk
- **Homelab Containers** — per-container resources, network, disk I/O

Access via Grafana → Dashboards → Homelab folder.

---

## Logs & Alerts

- **Loki + Promtail**: Centralized container logs in Grafana (Explore → Loki)
- **Alertmanager**: Telegram alerts for critical/warning rules
- **Prometheus Rules**: See `config/prometheus/rules/homelab.yml`

Configure Telegram:
1. Message @BotFather on Telegram → `/newbot`
2. Copy `TELEGRAM_BOT_TOKEN` to `.env`
3. Message @userinfobot → copy `TELEGRAM_CHAT_ID` to `.env`
4. Restart Alertmanager: `docker compose -f stacks/monitoring/docker-compose.yml restart alertmanager`

---

## Backup & Restore (v1.2)

```bash
# Manual backup (with alerting on failure)
make backup
# Or use wrapper for cron:
# /home/vansh/homelab-prod/scripts/backup-wrapper.sh

# Verify backup
make verify-backup

# Test restore (to /mnt/restore-test)
make restore-test
# Or:
make restore SNAPSHOT=latest
# Or manual:
restic -r b2:bucket:pi4b restore latest --target /mnt/restore-test
```

---

## Updates

```bash
# Pull latest images and restart
make down-all
make up-all

# Or use update script
/home/vansh/homelab-prod/scripts/update.sh
```

---

## Infisical Setup (Post-Deploy)

After `make up-phase2`:

1. Visit https://infisical.yourdomain.com
2. Create admin account
3. Create project: **homelab-prod**
4. Add secrets from your `.env`:
   - Copy each secret from `.env` to Infisical project
   - Use same names (e.g., `MYSQL_PASSWORD`, `VAULTWARDEN_ADMIN_TOKEN`)
5. (Optional) Generate in Infisical:
   - `AUTH_SECRET`, `ENCRYPTION_KEY`, `REDIS_PASSWORD`, `DB_PASSWORD`
   - Update `.env` with Infisical-generated values if desired
6. For CI/CD deploy, use Infisical CLI:
   ```bash
   # Install: brew install infisical/get-cli/infisical
   infisical login
   infisical run --projectId=... --env=production -- docker compose up -d
   ```

See `docs/ADR-004-secrets.md` for architecture decisions.