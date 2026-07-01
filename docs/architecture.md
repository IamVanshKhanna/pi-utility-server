# Architecture

## Overview

```mermaid
graph TB
    subgraph Internet["Internet"]
        TL[User Browser]
        TBOT[Telegram Bot API]
    end

    subgraph TS["Headscale/Tailscale Mesh (100.64.0.0/10)"]
        direction LR
        PI[autobot<br/>Pi 4B - 4GB<br/>100.64.0.1]
        WIN[mr-stranger<br/>Windows - 16GB<br/>100.64.0.2]
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
        HS[Headscale - Control Server]
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

    TL -->|HTTP:80| TRAEFIK
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

1. User hits `http://100.64.0.1/<path>` over Tailscale mesh (WireGuard encrypts all traffic)
2. Traefik routes by PathPrefix:
   - `/grafana` -> Grafana on Windows (`100.64.0.2:3000`)
   - `/auth` -> Authelia on Windows (`100.64.0.2:9091`)
   - `/secrets` -> Infisical on Windows (`100.64.0.2:8083`)
   - `/tempo` -> Tempo on Windows (`100.64.0.2:3200`)
   - `/dashboard`, `/api` -> Traefik dashboard (basic auth)
   - Other paths -> Pi services (Vaultwarden, Home Assistant, etc.)
3. Cross-node traffic uses Headscale-assigned IPs (`100.64.0.x`) — no public exposure
4. Pi Promtail sends logs to Windows Loki at `100.64.0.2:3100`
5. Pi apps send traces to Windows Tempo at `100.64.0.2:4317` (OTLP gRPC)
6. Windows Prometheus scrapes Pi targets at `100.64.0.1:{9100,8083,9617}`
7. Headscale control server on Pi (`100.64.0.1:8086`) replaces Tailscale SaaS

## Remote management

TinyBot runs as a systemd user service with `loginctl enable-linger vansh`.
It polls Telegram for commands (`/health`, `/fan`, `/docker`, `/search`, `/chatid`).
Daily health summary sent at 08:00 via systemd timer (`homelab-daily-summary.timer`).

## Backup strategy

- **Config/data:** Restic local backup to `/mnt/nas/backup/restic-repo` via `pi/scripts/backup.sh` (daily 03:00, 7/4/6 retention)
- **Legacy volumes:** One-time Docker volume backup at `/mnt/nas/backup/docker-volumes-2026-06-23`
- **.env files:** Not backed up (restore manually from secure store)

## Node responsibilities

### Pi 4B (always-on, 4GB RAM)
- Traefik (reverse proxy, HTTP entrypoint)
- Headscale (self-hosted Tailscale control server)
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
