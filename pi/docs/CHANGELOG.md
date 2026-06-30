# Changelog — homelab-ops-mesh

> All notable changes. Follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

---

## [v1.5.1] — 2026-07-01

### Fixed
- **Restic lock contention** — `backup.sh` auto-unlocks stale locks before init check and `forget --prune` (daily cron overlap, interrupted runs)
- **Syncthing UI on `0.0.0.0:8384`** — Container not recreated after compose port bind change; NAS stack redeployed to enforce `127.0.0.1:8384`
- **`daily-health-summary.sh` enhanced** — Windows Prometheus API queries (targets up, firing alerts), Pi unhealthy container count, load average, version tag `v1.5`

### Removed
- **13 stale Docker images** on Pi (MariaDB 11.4, CrowdSec v1.6.0, OTel collector, WireGuard, old Authelia/Loki/Tempo/Alertmanager/Postgres/curl/alpine/busybox — ~1.5GB)
- **6 stale Docker images** on Windows (Authelia 4.38.19, Infisical latest, Postgres 16-alpine, Alertmanager latest+v0.27.0, Alpine latest)
- **10 dangling Docker volumes** on Pi (Ollama data 2.1GB, old Authelia/Redis/Traefik/CrowdSec/Infisical/Uptime-Kuma/Vaultwarden — ~2.4GB)
- **2 dangling Docker volumes** on Windows (old Infisical DB, anonymous hash)

### Changed
- **`backup.sh`** — removes `_win_mem` Windows RAM line (Prometheus can't scrape Windows RAM without node-exporter)

---

## [v1.5.0] — 2026-06-30

### Added
- **Senior security audit** — Full STRIDE review with 3 CRITICAL, 7 HIGH, 13 MEDIUM, 8 LOW findings
- **Redis auth on apps stack** — `--requirepass` + `REDISCLI_AUTH` env var for password-protected Nextcloud Redis
- **Nextcloud `REDIS_HOST_PASSWORD`** — Connects to password-protected Redis
- **Portfolio healthcheck** — `wget` against `127.0.0.1:8080` (Alpine nginx)
- **`secrets-rotation.sh`** — Checks `.env` file age, sends Telegram notification if older than threshold
- **`windows/README.md`** — Stacks table, network docs, deployment order, commands

### Changed
- **All 4 Windows stacks declare `homelab_win` as `external: true`** — Must `docker network create homelab_win` before deploy
- **CrowdSec relay image** `python:3.14-alpine` → `python:3.12-alpine` (3.14 not stable)
- **Infisical `TRUSTED_PROXIES`** `"*"` → `"172.16.0.0/12"` (Docker bridge subnet only)
- **Pi repo path** `~/pi4homelab/` → `~/homelab-ops-mesh/` — systemd, cron, symlinks all updated
- **Portfolio healthcheck** `localhost` → `127.0.0.1` — Alpine resolves localhost to IPv6 `::1`

### Fixed
- **[C1] `secrets-rotation.service`** referenced non-existent script — created `secrets-rotation.sh`
- **[C2] Promtail trailing `"`** on `source: message"` line in `promtail.yml`
- **[C3] `capacity-planning.json`** broken JSON — missing `}` on last panel; restored Network I/O Rate panel (was overwritten with Capacity Alerts content)
- **[H1] TinyBot `/search` and `/chatid`** missing `@admin_only` decorator
- **[H2] TinyBot container commands** no name validation — added `re.match(r'^[a-zA-Z0-9_-]+$', name)`
- **[H5] TinyBot `requirements.txt`** missing `requests>=2.31`
- **[H6] Grafana dashboards** — removed Ollama/K8s panels from 4 dashboards (services removed in v1.3)
- **[H7] Portfolio** — updated container counts (27→28, 14→13 stacks)
- **[M1] Nextcloud/Vaultwarden/Syncthing ports** bound to `127.0.0.1` instead of `0.0.0.0`
- **[M2] Samba compose** — `SAMBA_PASSWORD` now required (no `changeme` default)
- **[M4] Pi apps Redis** — `--requirepass` + `REDISCLI_AUTH` healthcheck
- **[M6] ADR-005** — "removed in v1.7" → "removed in v1.3"
- **[M7] ADR-006** — removed Git signing claim; fixed recovery commands
- **[M9] SETUP_GUIDE** — `backup-wrapper.sh` → `backup.sh`
- **[M10] `backup.sh` and `backup-os.sh`** — `set -uo pipefail` → `set -euo pipefail`
- **[M11] Pi apps Redis** — `7.2-alpine` → `7.4-alpine`
- **[M12] Windows `homelab_win` network** — all stacks now use `external: true`
- **[M13] Portfolio** — removed WireGuard reference, updated tech list
- **[L2] Redis healthchecks** — `redis-cli -a $PASSWORD` → `REDISCLI_AUTH` env var (password not in process list)
- **[L4] CrowdSec** — removed `SYS_RESOURCE` capability (only `NET_ADMIN` needed)
- **[L6] Portfolio Dockerfile** — `nginx:alpine` → `nginx:1.27-alpine`
- **[L7] TinyBot governor** — `HERMES_ROOT` → `TINYBOT_ROOT`
- **[L8] ADR-006** — acknowledged unsigned commits as documented risk gap
- **Nextcloud healthcheck** — timeout 10s→35s; `curl -m 30`; interval 60s→120s (status.php slow on Pi)
- **Redis healthcheck in all 3 stacks** — `$$VAR` in CMD-SHELL doesn't work (env var not set in container); moved to `REDISCLI_AUTH` in `environment:` section

### Removed
- **11 stale Pi config files** — `pi/config/grafana/` (8 dashboards + prometheus datasource), `pi/config/tempo/`, `pi/config/otel-collector-config.yaml`
- ** CrowdSec `SYS_RESOURCE` capability** — unjustified, overrides container limits
- **`TAILSCALE_WIN_IP`** from `windows/.env.example` — unused (dead var)

---

## [v1.4.0] — 2026-06-28

### Added
- **Multi-node architecture** — Windows Desktop (16GB RAM) joins Pi as second node via Tailscale mesh
- **Phase 2 migration to Windows** — Grafana, Authelia+Redis, Infisical+PG+Redis, Prometheus, Loki, Tempo, Alertmanager
- **Path-based routing** — All services via `https://autobot.taila24d04.ts.net/<path>/` (replaced subdomain routing)
- **Tailscale Serve HTTPS** — Terminates TLS on 443, proxies to Traefik on 8443
- **Repo restructured** — `pi/` + `windows/` + `portfolio/` + `docs/`
- **Restic local backup** — Static binary, `/mnt/nas/backup/restic-repo`, daily cron at 03:00
- **Systemd user timers** — `daily-summary.timer` (08:00), `secrets-rotation.timer`
- **`.gitattributes`** — Enforces `eol=lf` for scripts, configs, Python
- **Docker image tags pinned** — All 28 containers on specific versions, no `:latest`
- **CPU limits** — Added to all 20 services across both nodes
- **Healthchecks** — Added to 17/20 services (3 distroless/external have no shell)
- **`:ro` bind mounts** — Config files mounted read-only where possible
- **Exporter ports on `0.0.0.0`** — Prometheus on Windows scrapes Pi via Tailscale IP
- **`homelab_win` Docker network** — Auth stack creates it; monitoring/secrets/tracing use `external: true`
- **Log rotation** — All 13 compose files: `max-size: 10m, max-file: 3`

### Changed
- **Repo migrated**: `pi4homelab` → `homelab-ops-mesh` (private)
- **Docker Compose replaces K3s** — All K3s, ArgoCD, Helmfile, multi-cluster removed
- **Ollama removed** — 2GB RAM savings; no LLM inference on Pi
- **Hermes Agent removed** — Replaced by TinyBot Telegram agent
- **Docker WireGuard removed** — Host Tailscale sufficient; Docker WG caused port 51820 conflict
- **Cloudflare DNS-01 removed** — Tailscale MagicDNS replaces (no domain needed)
- **Let's Encrypt removed** — Tailscale provides zero-cost HTTPS
- **5 stale stacks removed** — `auth/`, `monitoring-pi/`, `secrets/`, `services/`, `tracing/` (14→9 Pi stacks)
- **CrowdSec upgraded** v1.6.0 → v1.7.8 (SQLite only, PostgreSQL removed)
- **Samba crash-loop fixed** — `addgroup`/`adduser` idempotent with `|| 2>/dev/null || true`
- **Memory limits tuned** — Infisical 768m, Infisical-DB 256m, Infisical-Redis 64m
- **Git history purged** — `filter-branch` rewrote all 40 commits; force-pushed to GitHub
- **All scripts use `load_env()`** — Replaces unsafe `source .env`
- **Authelia password re-hashed** — `memory: 65536` (Pi); Windows fixed from 64→65536
- **Systemd hardening** — `NoNewPrivileges=true` + `ProtectSystem=strict` for user services
- **Env interpolation in compose** — Hardcoded IPs/domains replaced with `${VAR:-default}`
- **Stale configs deleted** — `pi/config/prometheus/`, `pi/config/loki/`, Pi Authelia config (Windows only)
- **Stale docs deleted** — `V1_CHECKLIST.md`, `demo-transcript.md`, `PERFORMANCE_BENCHMARK_TEMPLATE.md`, `ARCHITECTURE-OVERVIEW.md`
- **Docs rewritten** — `ARCHITECTURE.md`, `SETUP_GUIDE.md`, `TROUBLESHOOTING.md`, `SECRET_ROTATION.md`, `ENDPOINTS.md`, `PROJECT_SUMMARY.md`
- **ADRs updated** — ADR-001 (multi-node), ADR-002 (host Tailscale), ADR-003 (memory budget), ADR-005 (TinyBot replaces Hermes)

### Fixed
- **Windows Authelia `memory: 64`** SECURITY BUG → `65536` (trivially bypassable argon2id)
- **Pi-hole `custom.list`** — `192.168.1.50` → `192.168.68.59`
- **Prometheus DiskSpace alerts** — `/mnt/data` → `/` (correct Pi mountpoint)
- **Smarthome compose comment** — wrong IP fixed
- **Windows network conflict** — monitoring+secrets stacks use `external: true` for `homelab_win`
- **Nextcloud data permissions** — `/mnt/nas/shared/nextcloud/userdata` chowned to 33:33
- **Promtail Loki URL** — Via `-client.url` CLI flag (env var substitution works)
- **Alertmanager env expansion** — Custom `entrypoint.sh` with `sed` + `|` delimiter to `/tmp/`

### Security
- TinyBot `@admin_only` decorator on all commands
- All `subprocess.getoutput` → `subprocess.run([...])` list form (no shell injection)
- `.gitignore` for sensitive files; `git filter-branch` purged secrets from history
- Authelia `memory: 65536` hardened hashing on both nodes
- Samba auth tightened (guest read-only for media, auth for shared/backup)
- CrowdSec relay bounded + bearer token auth
- Systemd hardening for user-level services

---

## [v1.3.0] — 2026-06-19

### Added
- **Authelia SSO** — Redis + Authelia ForwardAuth on sensitive routes
- **CrowdSec IDS** — Intrusion detection with Telegram relay
- **TinyBot Telegram agent** — Health, search, docker, fan commands
- **Local-first architecture** — Removed K3s, ArgoCD, multi-cluster, cloud components

### Changed
- Removed Ollama (2GB RAM savings)
- K3s and all K8s manifests removed
- Cloudflare, Let's Encrypt, external DNS removed

---

## [v1.2.0] — 2026-06-15

### Added
- **Infisical Secret Manager** — PostgreSQL + Redis + Infisical
- **Restic local backup** — Daily backup with Telegram notifications
- **Backup automation** — `backup.sh`, `daily-health-summary.sh`

---

## [v1.1.0] — 2026-06-12

### Added
- **Loki + Promtail** — Centralized logging
- **Alertmanager + Telegram** — Alerting pipeline
- **Uptime Kuma** — External uptime monitoring
- **ZRAM 2GB** — Compressed RAM swap

---

## [v1.0.0] — 2026-06-09

### Added
- Core: Traefik, Portainer, Pi-hole, Tailscale
- Monitoring: Prometheus, Grafana, Node Exporter, cAdvisor
- Apps: Nextcloud, Vaultwarden
- Smarthome: Home Assistant
- NAS: Samba, Syncthing
- 3 ADRs (orchestration, network, memory)
- Docker Compose deployment pipeline
