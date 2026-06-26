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

    subgraph WinStacks["Windows Docker (16GB RAM)"]
        GRAFANA[Grafana - Dashboards]
        PROM[Prometheus - Metrics]
        LOKI[Loki - Logs]
        TEMPO[Tempo - Traces]
        AM[Alertmanager - Alerts]
        AUTH[Authelia - SSO]
        INF[Infisical - Secrets]
    end

    TL -->|HTTPS:443| TRAEFIK
    TRAEFIK -->|port 80/443| TS
    TRAEFIK -->|pi stacks| VW
    TRAEFIK -->|pi stacks| HA
    TRAEFIK -->|path /grafana| GRAFANA
    TRAEFIK -->|path /auth| AUTH
    TRAEFIK -->|path /secrets| INF
    TRAEFIK -->|path /tempo| TEMPO

    TB -->|polling| TBOT
    TB -->|systemd| PI

    PI -->|samba/syncthing| NAS
    PI -->|Promtail| LOKI
    PI -->|OTLP| TEMPO

    DNS -->|DNS:53| TL
```

## Traffic flow

1. User hits `https://autobot.taila24d04.ts.net/<path>`
2. Tailscale Serve handles TLS termination on 443, proxies to Traefik on `localhost:8443`
3. Traefik routes by PathPrefix:
   - `/grafana` -> Grafana on Windows (`100.74.111.26:3000`)
   - `/auth` -> Authelia on Windows (`100.74.111.26:9091`)
   - `/secrets` -> Infisical on Windows (`100.74.111.26:8083`)
   - `/tempo` -> Tempo on Windows (`100.74.111.26:3200`)
   - `/dashboard`, `/api` -> Traefik dashboard (basic auth)
   - Other paths -> Pi services (Vaultwarden, Home Assistant, etc.)
4. Cross-node traffic uses Tailscale IPs (`100.x.x.x`) — no public exposure
5. Pi Promtail sends logs to Windows Loki at `100.74.111.26:3100`
6. Pi apps send traces to Windows Tempo at `100.74.111.26:4317` (OTLP gRPC)
7. Windows Prometheus scrapes Pi targets at `100.127.191.2:{9100,8083,9617}`

## Remote management

TinyBot runs as a systemd user service with `loginctl enable-linger vansh`.
It polls Telegram for commands (`/health`, `/fan`, `/docker`, `/search`, `/chatid`).
Scheduled health reports sent every 6 hours via cron -> `send_health.py`.

## Backup strategy

- **OS level:** Weekly dd image to `/mnt/nas/backup/os` via systemd timer (Sun 3am, 4 week retention)
- **Config/data:** Restic to Backblaze B2 via `pi/scripts/backup.sh` (daily, 7/4/6 retention)
- **.env files:** Not backed up (restore manually from secure store)

## Node responsibilities

### Pi 4B (always-on, 4GB RAM)
- Traefik (reverse proxy, TLS termination, Tailscale entrypoint)
- Pi-hole (DNS filtering)
- Vaultwarden (password manager)
- Home Assistant (home automation)
- Syncthing (file sync)
- Samba (file sharing)
- Node Exporter + cAdvisor (hardware/container metrics)
- Promtail (log shipping -> Windows Loki)
- Nextcloud (file sync + apps)
- Uptime Kuma (uptime monitoring)

### Windows Desktop (on-demand, 16GB RAM)
- Grafana (dashboards, queries Prometheus/Loki/Tempo via Docker DNS)
- Prometheus (scrapes Pi targets + Windows services)
- Alertmanager (routes alerts to Telegram)
- Loki (log storage, ingests from Pi Promtail)
- Tempo (trace storage, ingests from Pi OTLP)
- Authelia + Redis (SSO authentication)
- Infisical + Postgres + Redis (secrets management)