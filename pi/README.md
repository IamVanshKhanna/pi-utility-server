# Pi 4B — always-on homelab core

This directory contains everything specific to the Raspberry Pi 4B node:

- **stacks/**: 9 Docker Compose stacks (apps, core, crowdsec, monitoring, nas, network, portfolio, smarthome, uptime-kuma)
- **scripts/**: Backup, health check, update scripts
- **systemd/**: User systemd unit files (daily-summary timer/service)
- **config/**: Per-service configuration (Traefik, CrowdSec, Promtail, Pi-hole)
- **.env.example**: Template for all required environment variables

Deploy in dependency order: core → network → monitoring → nas → apps → crowdsec → smarthome → uptime-kuma → portfolio.

## Headscale public IP

Set `HEADSCALE_PUBLIC_IP` in the Pi's private env file (for example,
`/home/vansh/.secrets/pi-utility-server.env`). Run
`PI_ENV_FILE=/home/vansh/.secrets/pi-utility-server.env pi/scripts/render-headscale-config.sh`
before the Headscale Compose stack. It writes ignored
`pi/config/headscale/config.yaml` with permission 600 from the tracked
`config.yaml.template`. `pi/scripts/update.sh` renders it automatically before
recreating Headscale. Keep the actual IP out of commits and logs; old local
clones may still have it in pre-rewrite history and should be re-cloned.
