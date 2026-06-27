# homelab-ops-mesh — Complete Project Summary

## Project Vision
A production-grade, multi-node homelab on **Raspberry Pi 4B (4GB RAM, 1.9TB SSD)** + **Windows Desktop (16GB RAM)** demonstrating:
- **Constraint-driven engineering** (4GB RAM, 7W power, ARM64, headless)
- **Multi-node architecture** (Pi always-on core + Windows heavy compute, Tailscale mesh)
- **Security-first** architecture (STRIDE model, SSO, IDS, secrets management)
- **Full observability** (metrics, logs, traces, alerts)
- **Automation** (TinyBot Telegram agent, cron, systemd timers)
- **Zero-cost HTTPS** (Tailscale MagicDNS, no domain purchase needed)
- **Local NAS** (Nextcloud + Samba + Syncthing for file storage/sync)

---

## Architecture (v1.4 — Multi-Node Docker Compose)

### Hardware
| Node | Spec | Role |
|------|------|------|
| Pi 4B | 4GB RAM, 1.9TB SSD, Debian Trixie | Always-on core (18 containers) |
| Windows Desktop | 16GB RAM, Docker Desktop | Heavy compute (10 containers) |
| Network | Tailscale mesh VPN, Gigabit Ethernet | Zero-trust inter-node |

### Pi Services (18 containers, 9 stacks)

| Stack | Services | Memory Limit |
|-------|----------|--------------|
| Core | Traefik, Portainer | 384 MB |
| Network | Pi-hole, pihole-exporter | 320 MB |
| Monitoring | Promtail, cAdvisor, Node Exporter | 384 MB |
| Apps | Nextcloud, MariaDB, Vaultwarden | ~2 GB |
| Smarthome | Home Assistant (host net) | 512 MB |
| Uptime Kuma | Uptime Kuma | 128 MB |
| CrowdSec | CrowdSec, relay | 384 MB |
| NAS | Samba, Syncthing | 256 MB |
| Portfolio | Astro site | 128 MB |

### Windows Services (10 containers, 4 stacks)

| Stack | Services | Memory Limit |
|-------|----------|--------------|
| Auth | Authelia, Redis | 320 MB |
| Monitoring | Grafana, Prometheus, Alertmanager, Loki | 1.5 GB |
| Secrets | Infisical, PostgreSQL, Redis | 1088 MB |
| Tracing | Tempo | 768 MB |

**Total across both nodes**: 28 containers, ~6.5 GB RAM budget

---

## TinyBot (Telegram Agent on Pi — No LLM)

| Command | Category | Description |
|---------|----------|-------------|
| /health | system | Pi CPU, RAM, temp, disk |
| /fan [speed] | system | Fan control (0-100) |
| /docker | system | Container management (list/close/restart) |
| /search | web | DuckDuckGo web search |
| /chatid | bot | Get chat ID for admin config |

Runs as systemd user service — no external AI dependencies.

---

## Security Features

| Feature | Implementation |
|---------|----------------|
| Zero-cost HTTPS | Tailscale Serve + MagicDNS |
| SSO + 2FA | Authelia ForwardAuth on sensitive routes |
| Secrets management | Infisical (PostgreSQL + Redis backend) |
| Intrusion detection | CrowdSec + Telegram alert relay |
| SSH hardening | Public key only, password auth disabled |
| Container hardening | Pinned image tags, CPU/mem limits, `:ro` mounts, healthchecks |
| Threat model | STRIDE documented in ADR-006 |

---

## Observability Stack

| Component | Purpose | Node |
|-----------|---------|------|
| Prometheus | Metrics collection, alerting rules | Windows |
| Grafana | Dashboards: System Overview, Containers | Windows |
| Loki + Promtail | Centralized log aggregation | Windows (Loki) + Pi (Promtail) |
| Alertmanager | Telegram alerts (critical/warning) | Windows |
| Tempo | Distributed tracing | Windows |
| Node Exporter | Host metrics | Pi |
| cAdvisor | Container metrics | Pi |
| Pi-hole Exporter | DNS metrics | Pi |
| Uptime Kuma | External uptime monitoring | Pi |

---

## Deployment

```bash
# On Pi
cd ~/homelab-ops-mesh/pi
docker compose -f stacks/<stack>/docker-compose.yml --env-file ../../.env up -d

# On Windows
cd homelab-ops-mesh/windows
docker compose -f stacks/<stack>/docker-compose.yml --env-file ../.env up -d
```

---

## Version History

| Version | Focus |
|---------|-------|
| v1.0 | Single Pi baseline, Docker Compose |
| v2.0 | K3s experiment (abandoned — too heavy for 4GB) |
| v3.0 | K3s removed, Docker Compose only, TinyBot, Tailscale |
| **v4.0** | **Multi-node mesh (current): Pi + Windows, restructured repo** |

---

## Portfolio Highlights

| Category | Evidence |
|----------|----------|
| Constraint Engineering | 4GB RAM, pinned images, memory limits, zram |
| Multi-node Orchestration | Tailscale mesh, path-based routing, 28 containers |
| Security | SSO + 2FA, IDS, secrets platform, threat model |
| Observability | Metrics + Logs + Traces + Alerts |
| Automation | TinyBot, cron, systemd timers |
| Infrastructure as Code | Docker Compose, `.template` + `.env` pattern |

---

## Repositories

| Repo | URL | Visibility |
|------|-----|------------|
| **homelab-ops-mesh** | https://github.com/IamVanshKhanna/homelab-ops-mesh | Private |
