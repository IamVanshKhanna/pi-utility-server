# Architecture Overview

This document describes the technical architecture of the Pi4B Homelab stack.

## Hardware

| Component | Spec |
|-----------|------|
| Board | Raspberry Pi 4B (4GB RAM) |
| Storage | 2TB USB 3.0 SSD (boot + data) |
| Network | Gigabit Ethernet |
| Power | Official Pi USB-C PSU (3A) |
| OS | Raspberry Pi OS Lite 64-bit |

## Network Architecture

```
Internet
    |
    v
[Router/ISP] :80/:443 forwarded
    |
    v
[Traefik Reverse Proxy] (:80 -> :443 redirect)
    |          |          |          |
    v          v          v          v
[Nextcloud] [Grafana] [Vaultwarden] [Home Assistant]
    |
[WireGuard VPN] <-- Remote access tunnel
    |
[Pi-hole] <-- DNS for LAN + ad blocking
```

## Docker Network Topology

```
Docker Networks:
  proxy       - Traefik-accessible services (external)
  monitoring  - Prometheus + Grafana + exporters
  apps        - Application services
  smarthome   - IoT / Home Assistant
  pihole_net  - Pi-hole isolated network
  wireguard   - VPN network
```

## Stack Dependencies & Boot Order

```
1. core (Traefik + proxy network)
       |
2. monitoring (Prometheus + Grafana + cAdvisor + Node Exporter)
       |
3. network (Pi-hole + WireGuard)
       |
4. apps (Nextcloud + Vaultwarden + Ollama)
       |
5. smarthome (Home Assistant)
```

## Service Map

| Service | Port | Network | Notes |
|---------|------|---------|-------|
| Traefik | 80, 443, 8082 | proxy | Reverse proxy + SSL |
| Prometheus | 9090 | monitoring | Metrics collection |
| Grafana | 3000 | monitoring, proxy | Dashboards |
| Node Exporter | 9100 | monitoring | Host metrics |
| cAdvisor | 8080 | monitoring | Container metrics |
| Pi-hole | 53, 8053 | pihole_net | DNS + ad blocking |
| WireGuard | 51820/udp | wireguard | VPN |
| Nextcloud | 9000 (fpm) | apps, proxy | File storage |
| Vaultwarden | 80 | apps, proxy | Password manager |
| Home Assistant | 8123 | smarthome, proxy | Home automation |
| Ollama | 11434 | apps, proxy | Local LLM |

## Data Persistence

All persistent data is stored under `${DATA_DIR}` (default: `/mnt/data/`):

```
/mnt/data/
  traefik/
    certs/     # Let's Encrypt certificates
    auth/      # .htpasswd for basic auth
  prometheus/  # TSDB metrics storage
  grafana/     # Dashboards, users, plugins
  nextcloud/   # Files, database
  vaultwarden/ # Vault database + attachments
  homeassistant/ # HA config, automations
  pihole/      # DNS lists, config
  wireguard/   # WireGuard keys + config
  ollama/      # Downloaded models
/mnt/backup/   # Automated backup archives
```

## Security Model

- **TLS everywhere**: All external traffic via Traefik + Let's Encrypt
- **Reverse proxy isolation**: No direct container port exposure
- **Traefik auth middleware**: Dashboard + sensitive services behind basic auth
- **IP whitelisting**: Admin endpoints restricted to LAN
- **VPN access**: WireGuard for secure remote access
- **Secrets management**: `.env` file, never committed to git
- **Container user isolation**: Non-root users where possible

## Resource Usage (Estimated)

| Service | RAM | CPU (idle) |
|---------|-----|------------|
| Traefik | ~50MB | <1% |
| Prometheus | ~200MB | 2-5% |
| Grafana | ~150MB | 1-2% |
| Pi-hole | ~100MB | <1% |
| Nextcloud | ~300MB | 2-5% |
| Vaultwarden | ~20MB | <1% |
| Home Assistant | ~300MB | 3-8% |
| Ollama | ~500MB+ | on-demand |
| **Total** | **~1.6GB** | **~10-20%** |

> The Pi 4B with 4GB RAM can comfortably run this stack with headroom for spikes.
