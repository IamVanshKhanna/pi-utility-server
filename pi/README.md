# Pi 4B -- always-on homelab core

This directory contains everything specific to the Raspberry Pi 4B node:

- **stacks/**: Docker Compose files for all 27 containers
- **tinybot/**: Telegram bot for remote management
- **scripts/**: Backup, health check, update scripts
- **systemd/**: User systemd unit files (tinybot.service, backup-os.timer)
- **config/**: Per-service configuration (Traefik, Prometheus, Grafana, etc.)
- **docs/**: ADRs, changelog, setup guides, endpoints

See [docs/SETUP_GUIDE.md](docs/SETUP_GUIDE.md) for deployment instructions.
