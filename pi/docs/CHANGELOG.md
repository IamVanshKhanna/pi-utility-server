# Changelog — homelab-ops-mesh

> All notable changes. Follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

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
