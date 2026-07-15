# pi-utility-server

> Always-on Raspberry Pi 4B utility platform: self-hosted mesh VPN, git, secrets, file sync, monitoring, and a personal portfolio site — all on one board.
>
> **Evolution:** built big (~30 containers, two nodes) during an early exploration phase, then deliberately retired everything not earning its place. What's left is nine services, one node, documented in [`docs/ADR-009-windows-stack-retirement.md`](pi/docs/ADR-009-windows-stack-retirement.md) and the other ADRs in [`pi/docs/`](pi/docs/).

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-Raspberry%20Pi%204B-red)](https://www.raspberrypi.com/)
[![Docker](https://img.shields.io/badge/docker-compose-blue)](https://docs.docker.com/compose/)

---

## Table of Contents

- [Hardware](#hardware)
- [Architecture](#architecture)
- [Services](#services)
- [Repository Structure](#repository-structure)
- [Quick Start](#quick-start)
- [Backups](#backups)
- [Skills This Project Shows](#skills-this-project-shows)
- [License](#license)

---

## Hardware

| Component | Spec |
|---|---|
| SBC | Raspberry Pi 4B, 4GB RAM |
| Storage | 2TB SATA SSD (USB 3.0) |
| OS | Debian aarch64 |
| Idle Power | ~5W |
| Network | Self-hosted WireGuard mesh (Headscale) — no third-party coordinator |

---

## Architecture

```
Internet
    |
[Headscale mesh — self-hosted, WireGuard-encrypted]
    |
[Raspberry Pi 4B — hub, always-on]
    |
[Docker Engine]
    |
    +-- [Headscale]        <- Self-hosted mesh control plane
    +-- [Gitea]             <- Self-hosted git + CI, canonical repo
    +-- [Vaultwarden]       <- Password manager (Bitwarden-compatible)
    +-- [Pi-hole]           <- Network-wide DNS ad-blocking
    +-- [Samba]             <- Centralized file storage
    +-- [Syncthing]         <- Multi-device file sync
    +-- [Uptime Kuma]       <- Service monitoring
    +-- [Netdata]           <- Real-time system metrics
    +-- [Portfolio]         <- This site's live deployment (Astro)
```

Every service is reachable only over the mesh, each at its own address — no reverse proxy, no single point of failure.

Retired (see ADRs for why): an 11-container Windows-hosted observability/secrets/auth stack, Nextcloud + MariaDB + Redis, a 6-container metrics stack (replaced by single-container Netdata), Kubernetes (K3s/ArgoCD/Helmfile).

---

## Services

| Service | Purpose | Port |
|---|---|---|
| Headscale | Self-hosted mesh control plane | `:8086` |
| Gitea | Self-hosted git + CI | `:8087` |
| Vaultwarden | Password vault | `:8081` |
| Pi-hole | DNS ad-blocking | `:8053` |
| Samba | Centralized file storage | `:445` |
| Syncthing | Multi-device sync | `:22000` |
| Uptime Kuma | Service monitoring | `:8082` |
| Netdata | Real-time metrics | `:19999` |
| Portfolio (Astro) | This site | `:8090` |

---

## Repository Structure

```
pi-utility-server/
+-- pi/
|   +-- stacks/                  # 8 service groups (docker-compose files)
|   +-- config/                  # Per-service settings
|   +-- scripts/                 # Backup, health-check, deploy scripts
|   +-- systemd/                 # Scheduled task configs
|   +-- docs/                    # ADRs, architecture, changelog, runbooks
|   +-- .env.example             # Template for secrets
+-- portfolio/                   # Personal portfolio website (Astro)
+-- docs/                        # Top-level architecture notes
```

---

## Quick Start

```bash
git clone https://github.com/IamVanshKhanna/pi-utility-server.git
cd pi-utility-server

cp pi/.env.example pi/.env
# edit pi/.env with real values — never commit this file

docker compose -f pi/stacks/headscale/docker-compose.yml up -d
docker compose -f pi/stacks/network/docker-compose.yml up -d
docker compose -f pi/stacks/gitops/docker-compose.yml up -d
docker compose -f pi/stacks/nas/docker-compose.yml up -d
docker compose -f pi/stacks/apps/docker-compose.yml up -d
docker compose -f pi/stacks/monitoring/docker-compose.yml up -d
docker compose -f pi/stacks/uptime-kuma/docker-compose.yml up -d
docker compose -f pi/stacks/portfolio/docker-compose.yml up -d
```

---

## Backups

Restic, encrypted, scheduled daily via cron (03:00):

```bash
0 3 * * * PI_ENV_FILE=/home/vansh/.secrets/pi-utility-server.env pi/scripts/backup.sh
```

Retention: 7 daily, 4 weekly, 6 monthly. See [`pi/scripts/backup.sh`](pi/scripts/backup.sh).

---

## Skills This Project Shows

| Area | Technologies |
|---|---|
| Containerisation | Docker, Docker Compose, multi-stack architecture |
| Self-hosted networking | Headscale (Tailscale-compatible), WireGuard mesh |
| Self-hosted GitOps | Gitea, act_runner CI |
| Monitoring | Netdata, Uptime Kuma |
| Security | Vaultwarden, secrets never committed, `.env`/`.env.example` pattern |
| Backup & recovery | Restic, encrypted snapshots, retention policy |
| Linux sysadmin | Debian, systemd, cron, SSH |
| Decision documentation | Architecture Decision Records for every major retirement/change |

---

## License

MIT License — see [LICENSE](LICENSE).

Copyright (c) 2026 Vansh Khanna
