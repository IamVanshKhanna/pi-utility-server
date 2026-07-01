# Changelog — homelab-ops-mesh

> All notable changes. Follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

---

## [v1.6.0] — 2026-07-01

### Added
- **Headscale v0.29.1** — Self-hosted Tailscale control server; replaces Tailscale SaaS
- **Headscale stack** — `pi/stacks/headscale/docker-compose.yml`; read_only, tmpfs, mem_limit 128m, cpus 0.5
- **Headscale config** — SQLite WAL, MagicDNS `homelab.local`, DERP default, `logtail: false`
- **Headscale policy** — `policy.hujson` allows all within tailnet
- **Headscale API key** — Added `HEADSCALE_API_KEY` to `.env.example`
- **Headscale Prometheus target** — Metrics on `100.64.0.1:9092` (9 Prometheus targets total)

### Changed
- **HTTP-over-mesh architecture** — Removed Tailscale Serve HTTPS; WireGuard encrypts all mesh traffic (TLS redundant inside mesh)
- **Traefik entrypoint** — Removed `tailscale:8443`; all routers use `web:80` entrypoint
- **Removed port 8443** from Traefik compose (no longer needed for Tailscale Serve)
- **Node IPs** — Pi `100.127.191.2` → `100.64.0.1`, Windows `100.74.111.26` → `100.64.0.2`
- **Windows port bindings** — `100.74.111.26` → `100.64.0.2` for Grafana, Authelia, Infisical, Tempo
- **Prometheus scrape targets** — Updated Pi endpoints from `100.127.191.2` → `100.64.0.1`
- **`dynamic.yml.template`** — All `tailscale` entrypoints → `web`; fallback IP `100.74.111.26` → `100.64.0.2`
- **`render-dynamic-yml.sh`** — Fallback default `WINDOWS_IP: 100.64.0.2`
- **`GF_SERVER_ROOT_URL`** — `https://autobot.taila24d04.ts.net/grafana/` → `http://100.64.0.1/grafana/`
- **Docs** — `ENDPOINTS.md`, `ARCHITECTURE.md`, `architecture.md`, `architecture.astro`, `windows/README.md` all updated for Headscale + new IPs
- **Headscale `server_url`** — `http://192.168.68.59:8086` (LAN accessible during bootstrap)
- **Headscale port binding** — `0.0.0.0:8086` (reachable from both Tailscale and LAN during node registration)

### Fixed
- **Headscale container `listen_addr`** — Changed from `127.0.0.1:8080` to `0.0.0.0:8080` inside container (Docker port mapping couldn't reach loopback-only bind)
- **Chicken-and-egg DNS** — `autobot.taila24d04.ts.net` MagicDNS unresolvable when Tailscale offline; added `/etc/hosts` entry (to be removed with `sudo`)
- **Headscale not reachable from Windows** — Tailscale SaaS and Headscale on different tailnets; temporarily bound to LAN IP `192.168.68.59:8086` for Windows registration

### Security
- **Self-hosted control plane** — No third-party dependency (Tailscale SaaS) for mesh coordination
- **Headscale bound to `0.0.0.0` temporarily** — Should be tightened to Tailscale IP only once stable

### Known Issues
- **`/etc/hosts` workaround** — `autobot.taila24d04.ts.net` → `127.0.0.1` added on Pi; needs `sudo sed -i '/autobot.taila24d04.ts.net/d' /etc/hosts` to remove
- **Headscale port `0.0.0.0:8086`** — Exposed on LAN; should bind to `100.64.0.1:8086` only (requires Pi Tailscale to be running during container start)

## [v1.5.2] — 2026-07-01

### Changed
- **`render-dynamic-yml.sh` rewritten** — Uses Python for safe env substitution; avoids shell `$` expansion corrupting htpasswd hashes in `TRAEFIK_BASICAUTH`
- **`dynamic.yml.template`** — htpasswd placeholder changed from `${TRAEFIK_BASICAUTH}` to `REPLACE_WITH_htpasswd_hash` (double-quoted in YAML; Python replaces it safely)
- **`pi/.env.example`** — Added `TRAEFIK_BASICAUTH` with generation instructions

### Removed
- **Ollama systemd service disabled** — `systemctl stop ollama && disable ollama`; frees ~24MB RAM on Pi; binary remains at `/usr/local/bin/ollama` for future use

### Fixed
- **Traefik dashboard basic auth broken** — Template had `"${TRAEFIK_BASICAUTH}"` but shell sed + `load_env()` mangled `$apr1$` hash characters; now rendered correctly via Python
- **Render script env var passing** — `export RENDER_TEMPLATE/OUTPUT/ENV` instead of inline `export` outside heredoc scope

---

## [v1.5.1] — 2026-07-01

### Fixed
- **[CRITICAL] Traefik PathPrefix rules broken** — `dynamic.yml` on Pi had unquoted `PathPrefix(/path)` syntax; backticks stripped during template rendering. All rules now double-quoted in YAML: `"PathPrefix(\`/path\`)"` — restores routing to Grafana, Authelia, Infisical, Tempo, and Dashboard
- **Windows services unreachable from Pi Traefik** — Grafana, Authelia, Infisical, Tempo ports bound to `127.0.0.1` on Windows; changed to Tailscale IP `100.74.111.26` — only Tailscale peers can connect
- **Restic lock contention** — `backup.sh` auto-unlocks stale locks before init check and `forget --prune`
- **Syncthing UI on `0.0.0.0:8384`** — Container not recreated after compose port bind change; NAS stack redeployed to enforce `127.0.0.1:8384`
- **`daily-health-summary.sh`** — Windows Prometheus API queries for target/alert counts, Pi unhealthy container count, load average, version tag
- **`ipWhiteList` deprecated** — changed to `ipAllowList` in `dynamic.yml.template` (Traefik v3)
- **`maxResponseBodySize` missing** on ForwardAuth middlewares — added 1MB limit to prevent DoS via large Authelia responses

### Changed
- **Windows port bindings**: Grafana `127.0.0.1:3000` → `100.74.111.26:3000`, Authelia `127.0.0.1:9091` → `100.74.111.26:9091`, Infisical `127.0.0.1:8083` → `100.74.111.26:8083`, Tempo `127.0.0.1:3200` → `100.74.111.26:3200`
- **Prometheus, Alertmanager, Loki, Tempo OTLP** ports remain `127.0.0.1` (no external access needed)

### Removed
- **13 stale Docker images** on Pi (MariaDB 11.4, CrowdSec v1.6.0, OTel collector, WireGuard, old Authelia/Loki/Tempo/Alertmanager/Postgres/curl/alpine/busybox — ~1.5GB)
- **6 stale Docker images** on Windows (Authelia 4.38.19, Infisical latest, Postgres 16-alpine, Alertmanager latest+v0.27.0, Alpine latest)
- **10 dangling Docker volumes** on Pi (Ollama data 2.1GB, old Authelia/Redis/Traefik/CrowdSec/Infisical/Uptime-Kuma/Vaultwarden — ~2.4GB)
- **2 dangling Docker volumes** on Windows (old Infisical DB, anonymous hash)

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
