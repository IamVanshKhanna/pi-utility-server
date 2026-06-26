# Architecture Overview

This document describes the technical architecture of the homelab-ops-mesh multi-node stack.

## Hardware

| Component | Spec |
|-----------|------|
| Pi 4B | 4GB RAM, 1.9TB USB 3.0 SSD, Debian Trixie (aarch64) |
| Windows Desktop | 16GB RAM, Docker Desktop |
| Network | Tailscale mesh VPN (100.x.x.x), Gigabit Ethernet |

## Network Architecture

```
Internet
    |
    | HTTPS (Tailscale MagicDNS)
    v
[ Tailscale Serve :443 ]  (TLS termination)
    |
    v
[ Traefik v3 Reverse Proxy ]  <--- path-based routing (PathPrefix)
    |
    +--- /vault/, /hass/, /sync/, /nextcloud/  (Pi services)
    +--- /grafana/, /auth/, /secrets/, /tempo/  (Windows services via Tailscale IP)
    |
    v
[ Pi 4B : 100.127.191.2 ]  <--- Tailscale mesh --->  [ Windows : 100.74.111.26 ]
```

## Docker Network Topology

### Pi (18 containers)
| Network | Services |
|---------|----------|
| proxy (external) | Traefik-accessible services |
| default (per-stack) | Each stack has its own network |

### Windows (10 containers)
| Network | Services |
|---------|----------|
| homelab_win (bridge) | All Windows stacks share one network |

## Stack Layout

### Pi Stacks (always-on)

| Stack | Services | Purpose |
|-------|----------|---------|
| core | traefik, portainer | Reverse proxy, Docker UI |
| network | pihole, pihole-exporter | DNS ad-blocking + metrics |
| monitoring | promtail, cadvisor, node-exporter | Log shipping, container/host metrics |
| apps | nextcloud, mariadb, vaultwarden | Cloud, passwords |
| smarthome | homeassistant | Home automation |
| uptime-kuma | uptime-kuma | Uptime monitoring |
| crowdsec | crowdsec, relay | Intrusion detection + alert relay |
| nas | samba, syncthing | File sharing, sync |
| portfolio | astro site | Project showcase |

### Windows Stacks (heavy compute)

| Stack | Services | Purpose |
|-------|----------|---------|
| monitoring | grafana, prometheus, alertmanager, loki | Dashboards, metrics, alerts, logs |
| auth | authelia, redis | SSO with 2FA |
| secrets | infisical, postgres, redis | Secrets management |
| tracing | tempo | Distributed tracing |

## Service Map

### Pi Host Ports

| Service | Port | Binding | Notes |
|---------|------|---------|-------|
| Traefik | 80, 8443, 8084 | 0.0.0.0 | HTTP, Tailscale entrypoint, API |
| Portainer | 9000 | 127.0.0.1 | Docker UI |
| Pi-hole | 53 | 0.0.0.0 | DNS |
| Pi-hole admin | 8053 | 127.0.0.1 | Web UI |
| pihole-exporter | 9617 | 0.0.0.0 | Prometheus metrics |
| Node Exporter | 9100 | 0.0.0.0 | Host metrics |
| cAdvisor | 8083 | 0.0.0.0 | Container metrics |
| Nextcloud | 8080 | 0.0.0.0 | File cloud |
| Vaultwarden | 8081 | 0.0.0.0 | Password manager |
| Home Assistant | 8123 | host mode | Home automation |
| Uptime Kuma | 8082 | 127.0.0.1 | Uptime monitoring |
| Syncthing | 8384, 22000, 21027/udp | 0.0.0.0 | File sync |
| Samba | 139, 445 | 0.0.0.0 | File sharing |

### Windows Host Ports

| Service | Port | Binding | Notes |
|---------|------|---------|-------|
| Grafana | 3000 | 127.0.0.1 | Dashboards |
| Prometheus | 9090 | 127.0.0.1 | Metrics |
| Alertmanager | 9093 | 127.0.0.1 | Alert routing |
| Loki | 3100 | 127.0.0.1 | Log storage |
| Tempo | 3200, 4317 | 127.0.0.1 | Traces + OTLP gRPC |
| Authelia | 9091 | 127.0.0.1 | SSO |
| Infisical | 8083 | 127.0.0.1 | Secrets UI |

## Data Persistence

All Pi persistent data is stored under `/mnt/nas/`:

```
/mnt/nas/
  shared/       # Samba shared files, Nextcloud userdata
  media/        # Media files (guest read-only)
  sync/         # Syncthing synchronized files
  backup/       # Restic repos, OS images, logs
    restic-repo/  # Restic backup repository
    os/           # Weekly dd images
    logs/         # Health summary logs
```

## Security Model

- **TLS everywhere**: Tailscale Serve terminates TLS on 443
- **Path-based routing**: Traefik PathPrefix rules, no subdomain certs needed
- **Authelia SSO**: 2FA on sensitive endpoints
- **CrowdSec IPS**: Community blocklists + alert relay to Telegram
- **Pi SSH**: Public key only, password auth disabled
- **`.env` secrets**: Never committed, templates tracked instead
- **`:ro` mounts**: Config bind mounts read-only where possible
- **Memory limits**: All 20+ services have CPU + memory limits

## Resource Usage

| Node | Containers | RAM (typical) | CPU (idle) |
|------|------------|---------------|------------|
| Pi 4B | 18 | ~1.8GB | ~10-15% |
| Windows | 10 | ~2GB | ~5-10% |

> 4GB Pi runs comfortably with zram (compressed RAM swap, no disk swap).
