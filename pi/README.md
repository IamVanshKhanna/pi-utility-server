# Pi 4B — always-on homelab core

This directory contains everything specific to the Raspberry Pi 4B node:

- **stacks/**: 9 Docker Compose stacks (apps, core, crowdsec, monitoring, nas, network, portfolio, smarthome, uptime-kuma)
- **scripts/**: Backup, health check, update scripts
- **systemd/**: User systemd unit files (daily-summary timer/service)
- **config/**: Per-service configuration (Traefik, CrowdSec, Promtail, Pi-hole)
- **.env.example**: Template for all required environment variables

Deploy in dependency order: core → network → monitoring → nas → apps → crowdsec → smarthome → uptime-kuma → portfolio.
