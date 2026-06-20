# Architecture

## Overview

```mermaid
graph TB
    subgraph Internet["Internet"]
        TL[User Browser]
        TBOT[Telegram Bot API]
    end

    subgraph TS["Tailscale Mesh (100.x.x.x)"]
        direction LR
        PI[autobot<br/>Pi 4B - 4GB]
        WIN[mr-stranger<br/>Windows - 16GB]
    end

    subgraph PiStacks["Pi 4B (always-on)"]
        TRAEFIK[Traefik - Reverse Proxy]
        DNS[Pi-hole - DNS Filter]
        WG[WireGuard - VPN]
        VW[Vaultwarden - Passwords]
        HA[Home Assistant - Automation]
        ST[Syncthing - File Sync]
        SM[Samba - File Sharing]
        NE[node-exporter - Hardware Metrics]
        TB[TinyBot - Telegram Bot]
    end

    subgraph NAS["/mnt/nas/ storage"]
        SHARED[/mnt/nas/shared]
        MEDIA[/mnt/nas/media]
        SYNC[/mnt/nas/sync]
        BACKUP[/mnt/nas/backup]
    end

    subgraph Future["Windows Docker (Phase 2)"]
        GRAFANA[Grafana - Dashboards]
        PROM[Prometheus - Metrics]
        LOKI[Loki - Logs]
        CS[CrowdSec - IPS]
        AUTH[Authelia - SSO]
        INF[Infisical - Secrets]
    end

    TL -->|HTTPS:443| TRAEFIK
    TRAEFIK -->|port 80/443| TS
    TRAEFIK -->|pi stacks| VW
    TRAEFIK -->|pi stacks| HA
    TRAEFIK -->|future| GRAFANA
    TRAEFIK -->|future| AUTH
    TRAEFIK -->|future| INF

    TB -->|polling| TBOT
    TB -->|systemd| PI

    PI -->|samba/syncthing| NAS

    DNS -->|DNS:53| TL
    WG -->|VPN:51820| TL
```

## Traffic flow

1. User hits `https://autobot.taila24d04.ts.net` or `https://app.taila24d04.ts.net`
2. Tailscale Serve handles TLS termination, proxies to Traefik (localhost:443)
3. Traefik routes per Host rule:
   - `vaultwarden.autobot.taila24d04.ts.net` -> Vaultwarden
   - `homeassistant.autobot.taila24d04.ts.net` -> Home Assistant
   - `sync.autobot.taila24d04.ts.net` -> Syncthing
   - `grafana.autobot.taila24d04.ts.net` -> Grafana (currently Pi, future Windows)
4. Internal traffic between containers uses the `proxy` Docker network

## Remote management

TinyBot runs as a systemd user service with `loginctl enable-linger vansh`.
It polls Telegram for commands (`/health`, `/fan`, `/docker`, `/search`, `/chatid`).
Scheduled health reports sent every 6 hours via cron -> `send_health.py`.

## Backup strategy

- **OS level:** Weekly dd image to `/mnt/nas/backup/os` via systemd timer (Sun 3am, 4 week retention)
- **Config/data:** Restic to Backblaze B2 via `pi/scripts/backup.sh` (daily, 7/4/6 retention)
- **.env files:** Not backed up (restore manually from secure store)

## Future state (Phase 2)

Heavy stacks move to Windows Docker Desktop:
- Grafana + Prometheus + Loki + Tempo (monitoring)
- CrowdSec (intrusion detection)
- Authelia (SSO portal)
- Infisical (secrets management)

Pi keeps: Traefik, Pi-hole, WireGuard, Vaultwarden, Syncthing, Samba, Home Assistant, TinyBot.