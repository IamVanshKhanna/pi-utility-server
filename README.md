# homelab-ops-mesh

Multi-node homelab: Raspberry Pi 4B (always-on) + Windows (on-demand).
Connected via Tailscale mesh VPN. Orchestrated with Docker Compose.

## Nodes

| Node | Role | RAM | Services |
|------|------|-----|----------|
| autobot (Pi 4B) | Always-on core | 4GB | traefik, pihole, wireguard, vaultwarden, syncthing, homeassistant, samba, portainer |
| mr-stranger (Windows) | Heavy compute | 16GB | grafana, prometheus, loki, crowdsec, authelia, infisical (Phase 2) |

## Repo layout

```
homelab-ops-mesh/
├── README.md           # This file
├── .gitignore          # Root-level ignores
├── pi/                 # Pi 4B always-on core
│   ├── stacks/         # Docker Compose stacks (14 stacks)
│   ├── tinybot/        # Telegram bot for remote management
│   ├── scripts/        # Backup, health checks, updates
│   ├── systemd/        # User systemd unit files
│   ├── config/         # Per-service config (traefik, grafana, etc)
│   └── docs/           # ADRs, changelog, setup guides
├── windows/            # Windows Docker Desktop (Phase 2)
├── portfolio/          # Astro static portfolio site
├── docs/               # Architecture, setup, troubleshooting
└── .github/            # Issue/PR templates
```

## Quick Links

- **Live:** https://autobot.taila24d04.ts.net (Tailscale MagicDNS)
- **Architecture:** [docs/architecture.md](docs/architecture.md)
- **Pi setup:** [pi/docs/SETUP_GUIDE.md](pi/docs/SETUP_GUIDE.md)
- **Endpoints:** [pi/docs/ENDPOINTS.md](pi/docs/ENDPOINTS.md)

## Key decisions

- No Kubernetes -- K3s removed, saves ~575MB RAM and 50% idle CPU
- No disk swap -- zram only (compressed RAM, no SSD wear)
- No repartitioning -- `/mnt/nas/` folders for all storage
- No AI/LLM locally -- free Groq API as fallback if TinyBot needs ML
- Tailscale MagicDNS -- HTTPS without paid domain
- Telegram bot for remote management (`/health`, `/fan`, `/docker`, `/search`)

## Phase plan

| Phase | Status | What |
|-------|--------|------|
| 1 | Done | Pi core with 27 containers, NAS, TinyBot, Tailscale |
| 2 | Next | Move monitoring/auth/secrets to Windows Docker Desktop |
| 3 | Todo | Portfolio site, Windows docs, Astro deployment |

## Git history

This repo continues the commit history of the archived `pi4homelab` repo.
Original v1.0 commit `7915a20` preserved under the `pi/` prefix.