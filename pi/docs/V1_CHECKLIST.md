# v1.0 Acceptance Checklist

> All items must pass for v1.0 release.

## Infrastructure
- [x] Pi 4B 4GB + 2 TB SSD + DeskPi 3B Pro booted headless
- [x] Raspberry Pi OS Lite 64-bit (Bookworm)
- [x] ZRAM swap enabled (2 GB compressed)
- [x] Tailscale installed, exit node advertised, MagicDNS working
- [x] Docker + docker compose plugin installed
- [x] `proxy` Docker network created

## Core Stack (make up-core)
- [x] Traefik v3.0.4 running, TLS certs issued via Let's Encrypt (HTTP-01)
- [x] Portainer 2.21.5 accessible via `portainer.DOMAIN`
- [x] Traefik dashboard via `traefik.DOMAIN` (basic auth)
- [x] Pi-hole 2024.07.0 on port 53 (host network), DNSSEC enabled
- [x] Tailscale v1.68.0 container healthy, exit node functional

## Monitoring Stack (make up-monitoring)
- [x] Prometheus v2.54.0 scraping: prometheus, node-exporter, cadvisor, traefik, pihole
- [x] Grafana 11.1.3 with provisioned datasources + dashboards
- [x] Node Exporter v1.8.2 collecting host metrics
- [x] cAdvisor v0.49.1 collecting container metrics (privileged)

## Apps Stack (make up-apps)
- [x] MariaDB 11.4.3 healthy, Nextcloud DB ready
- [x] Redis 7.2.5-alpine healthy, cache configured
- [x] Nextcloud 29.0.5 installed, trusted domains set, data on `/mnt/data`
- [x] Vaultwarden 1.32.6 running, admin token set, signups disabled
- [x] Ollama 0.3.14 bound to 127.0.0.1:11434, gemma:2b model pulled

## Smarthome Stack (make up-smarthome)
- [x] Home Assistant 2024.7.3 on host network, accessible on :8123

## Hermes Agent
- [x] Installed in venv on Pi
- [x] Homelab profile created (`~/.hermes/profiles/homelab/`)
- [x] Skills installed: `homelab-ops`, `gitops-helper`
- [x] Systemd service `hermes-agent` running
- [x] Responds to `hermes --profile homelab "health check"`

## Backup & Reliability
- [x] Restic repo initialized on Backblaze B2
- [x] `scripts/backup.sh` runs, backs up all data dirs
- [x] Retention policy: daily 7, weekly 4, monthly 6
- [x] `make verify-backup` passes (snapshot exists + 5% readability check)
- [x] `make verify-ram-pi` passes (RAM < 3900 MB)

## Verification
- [x] `make verify-v1` passes (all sub-checks green)
- [x] `make deploy-pi` works from laptop (rsync + remote make up)
- [x] Demo transcript recorded in `docs/demo-transcript.md`

## Documentation
- [x] `docs/ADR-001-orchestration.md` — Why Compose over K3s
- [x] `docs/ADR-002-network-access.md` — Why Tailscale over WireGuard
- [x] `docs/ADR-003-memory.md` — ZRAM + limits + model choice
- [x] `docs/HERMES_ON_PI.md` — Install, profile, skills, systemd
- [x] `docs/architecture.svg` — System diagram
- [x] `docs/demo-transcript.md` — Recorded bring-up session
- [x] `README.md` — Project overview, quick start, roadmap

## GitHub
- [x] `pi4b-homelab` repo (private) pushed with workflows
- [x] `homelab-options-lab` repo (public) pushed with lab structure
- [x] GitHub Actions: compose-validate, trivy-scan, backup-test
- [x] Renovate config for automated Docker image updates

---

## Release Tag
```bash
git tag -a v1.0 -m "v1.0: Production homelab baseline"
git push origin v1.0
```