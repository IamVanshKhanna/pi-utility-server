# ADR-003: Memory Strategy — Container Limits + ZRAM on 4GB Pi

## Status
Accepted

## Context
Pi 4B has 4 GB RAM. Must run: OS, Docker, 18 containers on Pi + offload 10 heavier containers to Windows.
Goal: Stay under 3.5 GB used on Pi (leave ~500 MB buffer for ZRAM + kernel).

## Decision
1. **Container memory limits** (hard `mem_limit` in compose for every service)
2. **ZRAM swap:** 2 GB compressed in RAM (no disk swap — protects SSD)
3. **Heavy compute offloaded to Windows** (Grafana, Prometheus, Authelia, Infisical, Loki, Tempo, Alertmanager)
4. **Operational rule:** Monitor via Prometheus `HighMemoryUsage` alert (>85% limit)

## Pi Memory Budget (v1.4 measured)

| Component | Limit | Typical |
|-----------|-------|---------|
| OS + Docker daemon | — | 600 MB |
| Traefik + Portainer | 384 MB | 180 MB |
| Nextcloud + MariaDB | 1.5 GB | 1.1 GB |
| Vaultwarden | 128 MB | 40 MB |
| Pi-hole + exporter | 320 MB | 90 MB |
| Home Assistant (host net) | 512 MB | 300 MB |
| CrowdSec + relay | 384 MB | 200 MB |
| Promtail + cAdvisor + Node Exporter | 384 MB | 150 MB |
| Uptime Kuma | 128 MB | 60 MB |
| Samba + Syncthing | 256 MB | 80 MB |
| Portfolio (Astro) | 128 MB | 40 MB |
| **Total (Pi only)** | **~4.1 GB limits** | **~2.3 GB typical** |

**Why it fits:** Typical usage is well under limits; ZRAM absorbs spikes; `mem_limit` prevents any single container from causing OOM.

## ZRAM Configuration
```ini
# /etc/systemd/zram-generator.conf
[zram0]
zram-size = ram / 2
compression-algorithm = zstd
```

## Consequences
- No OOM kills under normal operation
- Restic full check may need `docker compose stop apps` first if RAM is tight
- Windows handles all heavy services (Prometheus, Grafana, Loki, Tempo, Infisical) — 16 GB RAM available
- If Pi RAM is consistently tight, consider reducing Nextcloud memory or moving MariaDB to Windows

## References
- [ZRAM generator docs](https://manpages.ubuntu.com/manpages/noble/man5/zram-generator.conf.5.html)
- [Docker memory constraints](https://docs.docker.com/config/containers/resource_constraints/)
