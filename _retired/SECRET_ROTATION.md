# Secret Rotation Procedure

> This document describes how to rotate secrets in the homelab-ops-mesh infrastructure.

## Overview

Secrets are stored in **`.env` files** (gitignored) with **`.template` + `.env.example`** committed for reference. Infisical (on Windows) serves as a secondary audit/rotation reference.

Rotation involves:
1. Generating new secret values
2. Updating in `.env` on the relevant node (Pi or Windows)
3. Restarting affected services
4. Verifying health

## Rotation Schedule

| Secret Type | Frequency | Method |
|-------------|-----------|--------|
| Database passwords | 90 days | `.env` update + service restart |
| API tokens (Telegram) | 90 days | Provider UI → `.env` → restart |
| TLS certificates (Tailscale) | Auto (Tailscale manages) | No manual rotation |
| Authelia JWT/Session secrets | 180 days | `.env` update → Authelia restart (Windows) |
| CrowdSec API key | 365 days | CrowdSec console → `.env` → restart |
| Restic repo password | On compromise only | Requires new repo init |

## Rotation Procedures

### 1. Database Passwords (MariaDB on Pi)

**When:** Every 90 days or after suspected compromise

**Steps:**
```bash
# On Pi:
# 1. Generate new password
NEW_PASS=$(openssl rand -base64 32)

# 2. Update .env
# Edit ~/homelab-ops-mesh/.env: MYSQL_PASSWORD, MYSQL_ROOT_PASSWORD

# 3. Update database users
docker exec mariadb mysql -u root -p"$OLD_ROOT_PASS" -e "
  ALTER USER 'nextcloud'@'%' IDENTIFIED BY '$NEW_PASS';
  FLUSH PRIVILEGES;
"

# 4. Restart affected services
cd ~/homelab-ops-mesh/pi
docker compose -f stacks/apps/docker-compose.yml --env-file ../../.env restart

# 5. Verify health
docker ps --format "table {{.Names}}\t{{.Status}}"
```

### 2. API Tokens (Telegram Bot)

**When:** Every 90 days or after suspected compromise

**Steps:**
1. Generate new token via @BotFather on Telegram
2. Update `TELEGRAM_BOT_TOKEN` in `.env` on Pi
3. Restart affected services:
   ```bash
   # On Pi:
   systemctl --user restart tinybot.service
   
   # On Windows:
   docker compose -f stacks/monitoring/docker-compose.yml restart alertmanager
   
   # On Pi:
   systemctl --user restart homelab-daily-summary.timer
   ```
4. Verify: send `/health` to bot, check Telegram alert delivery

### 3. Authelia Secrets (JWT, Session, Storage)

**When:** Every 180 days

**Steps:**
```bash
# 1. Generate new secrets
JWT_SECRET=$(openssl rand -base64 32)
SESSION_SECRET=$(openssl rand -base64 32)
STORAGE_ENCRYPTION_KEY=$(openssl rand -base64 32)

# 2. Update in Windows .env
# AUTHELIA_JWT_SECRET, AUTHELIA_SESSION_SECRET, AUTHELIA_STORAGE_ENCRYPTION_KEY

# 3. Update users_database.yml passwords if needed
# Generate new argon2id hashes:
# docker run --rm authelia/authelia:4.38.0 authelia crypto hash generate argon2id --password 'new-password'

# 4. Restart Authelia (on Windows):
docker compose -f stacks/auth/docker-compose.yml restart authelia

# 5. Verify
curl -sf http://localhost:9091/api/healthz
```

### 4. CrowdSec API Key

**When:** Annual or after compromise

**Steps:**
1. Generate new key at https://app.crowdsec.net
2. Update `CROWDSEC_API_KEY` in Pi `.env`
3. Restart CrowdSec (on Pi):
   ```bash
   cd ~/homelab-ops-mesh/pi
   docker compose -f stacks/crowdsec/docker-compose.yml --env-file ../../.env restart crowdsec
   ```
4. Verify: `cscli decisions list`

### 5. Relay Token (CrowdSec webhook relay)

**When:** On compromise or when rotating CrowdSec secrets

**Steps:**
1. Generate new token: `openssl rand -hex 32`
2. Update `RELAY_TOKEN` in Pi `.env`
3. Update CrowdSec `http.yaml` (hardcoded — no env substitution):
   ```bash
   # Edit pi/config/crowdsec/http.yaml manually with new token
   ```
4. Restart:
   ```bash
   docker compose -f stacks/crowdsec/docker-compose.yml --env-file ../../.env restart
   ```
5. Verify relay auth: `curl -H "Authorization: Bearer <new_token>" http://127.0.0.1:8085/`

## Emergency Rotation (Compromise Response)

**If secret compromise is suspected:**

1. **Immediate:** Rotate the compromised secret in `.env`
2. **Contain:** Restart affected service immediately
3. **Audit:** Check CrowdSec decisions + Authelia logs for suspicious activity
4. **Rotate related:** Rotate any secrets that might have been exposed
5. **Document:** Record incident in GitHub issue with timeline
6. **Review:** Update this procedure if gaps found

## Verification Checklist

After any rotation:
- [ ] All services show "running" in `docker ps`
- [ ] Health endpoint checks pass for rotated service
- [ ] Telegram test notification received (if Telegram-related)
- [ ] Backup completes successfully (if backup-related)
- [ ] No new critical alerts in Alertmanager

## Audit Trail

All rotations logged in:
- Git commit history (if `.env.example` or `.template` files updated)
- Telegram notification history
- CrowdSec alert history
- Authelia authentication logs
