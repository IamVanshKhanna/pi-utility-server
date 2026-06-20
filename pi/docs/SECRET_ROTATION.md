# Secret Rotation Procedure

> This document describes how to rotate secrets in the homelab-prod infrastructure using Infisical.

## Overview

All secrets are managed in **Infisical** (https://infisical.yourdomain.com). Rotation involves:
1. Generating new secret values
2. Updating in Infisical
3. Restarting affected services
3. Verifying health

## Rotation Schedule

| Secret Type | Frequency | Method |
|-------------|-----------|--------|
| Database passwords | 90 days | Infisical UI + service restart |
| API tokens (Telegram, B2, Cloudflare) | 90 days | Provider UI → Infisical → restart |
| TLS certificates (Let's Encrypt) | Auto (60 days) | Traefik ACME (DNS-01) |
| Authelia JWT/Session secrets | 180 days | Infisical → Authelia restart |
| CrowdSec API key | 365 days | CrowdSec console → Infisical |
| Infisical internal secrets | 365 days | Infisical UI → restart Infisical stack |

## Rotation Procedures

### 1. Database Passwords (MariaDB, PostgreSQL)

**When:** Every 90 days or after suspected compromise

**Steps:**
```bash
# 1. Generate new password
NEW_PASS=$(openssl rand -base64 32)

# 2. Update in Infisical UI
# Navigate to: Project → homelab-prod → Secrets
# Update: MYSQL_PASSWORD, MYSQL_ROOT_PASSWORD, POSTGRES_PASSWORD

# 3. Update database users
docker exec mariadb mysql -u root -p"$OLD_ROOT_PASS" -e "
  ALTER USER 'nextcloud'@'%' IDENTIFIED BY '$NEW_PASS';
  FLUSH PRIVILEGES;
"

# 4. Restart affected services
make down-phase4 && make up-phase4  # apps phase includes mariadb

# 5. Verify
make verify-health
```

### 2. API Tokens (Telegram, Backblaze B2, Cloudflare)

**When:** Every 90 days or after suspected compromise

**Steps:**
1. Generate new token in provider's console
2. Update in Infisical: `TELEGRAM_BOT_TOKEN`, `B2_ACCOUNT_KEY`, `CF_DNS_API_TOKEN`
3. Restart affected services:
   ```bash
   # For Telegram (alertmanager, backup-alert, daily-summary)
   docker compose -f stacks/monitoring/docker-compose.yml restart alertmanager
   systemctl restart homelab-daily-summary.timer
   
   # For B2 (backup)
   ./scripts/backup-wrapper.sh  # test
   
   # For Cloudflare (Traefik DNS-01)
   docker compose -f stacks/core/docker-compose.yml restart traefik
   ```
4. Verify: `make verify-v1`

### 3. Authelia Secrets (JWT, Session, Storage)

**When:** Every 180 days

**Steps:**
```bash
# 1. Generate new secrets
JWT_SECRET=$(openssl rand -base64 32)
SESSION_SECRET=$(openssl rand -base64 32)
STORAGE_ENCRYPTION_KEY=$(openssl rand -base64 32)

# 2. Update in Infisical
# AUTHELIA_JWT_SECRET, AUTHELIA_SESSION_SECRET, AUTHELIA_STORAGE_ENCRYPTION_KEY

# 2. Update users_database.yml passwords if needed
# Generate new argon2id hashes:
# docker run --rm authelia/authelia:4.38.0 authelia crypto hash generate argon2id --password 'new-password'

# 3. Restart Authelia
docker compose -f stacks/auth/docker-compose.yml restart authelia

# 3. Verify
curl -sf http://localhost:9091/api/healthz
```

### 4. CrowdSec API Key

**When:** Annual or after compromise

**Steps:**
1. Generate new key at https://app.crowdsec.net
2. Update `CROWDSEC_API_KEY` in Infisical
3. Restart CrowdSec:
   ```bash
   docker compose -f stacks/crowdsec/docker-compose.yml restart crowdsec
   ```
4. Verify: `cscli decisions list`

### 5. Infisical Internal Secrets

**When:** Annual

**Secrets to rotate:**
- `INFISICAL_AUTH_SECRET`
- `INFISICAL_ENCRYPTION_KEY`
- `INFISICAL_REDIS_PASSWORD`
- `INFISICAL_POSTGRES_PASSWORD`

**Steps:**
```bash
# 1. Generate new values
AUTH_SECRET=$(openssl rand -base64 32)
ENCRYPTION_KEY=$(openssl rand -base64 32)
REDIS_PASS=$(openssl rand -base64 32)
PG_PASS=$(openssl rand -base64 32)

# 2. Update in Infisical
# Update: INFISICAL_AUTH_SECRET, INFISICAL_ENCRYPTION_KEY, INFISICAL_REDIS_PASSWORD, INFISICAL_POSTGRES_PASSWORD

# 3. Full stack restart (order matters!)
make down-phase2 && make up-phase2
make down-phase3 && make up-phase3  # monitoring depends on Infisical

# 4. Verify
make verify-secrets
make verify-v1
```

## Emergency Rotation (Compromise Response)

**If secret compromise is suspected:**

1. **Immediate:** Rotate the compromised secret in Infisical
2. **Contain:** Restart affected service immediately
3. **Audit:** Check access logs for suspicious activity
4. **Rotate related:** Rotate any secrets that might have been exposed
5. **Document:** Record incident in GitHub issue with timeline
6. **Review:** Update this procedure if gaps found

## Verification Checklist

After any rotation:
- [ ] `make verify-v1` passes
- [ ] No active alerts in Alertmanager
- [ ] All services show "running" in `docker ps`
- [ ] Health endpoint checks pass for rotated service
- [ ] Telegram test notification received
- [ ] Backup completes successfully

## Automation

Future enhancement: Automate rotation via Infisical CLI in CI/CD
```bash
# Example: Rotate and deploy
infisical run --projectId=... --env=production -- \
  bash -c 'make down-phase4 && make up-phase4'
```

## Audit Trail

All rotations logged in:
- Infisical audit log (UI → Audit Log)
- GitHub commit history (if .env.example updated)
- GitHub Actions workflow runs
- Telegram notification history