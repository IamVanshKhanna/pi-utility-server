# Service Endpoints Reference

> Last updated: 2026-07-01 | Pi: autobot (100.84.60.109) | Windows: mr-stranger (100.84.60.109)
> All web services use path-based routing: `http://100.84.60.109/<path>/`
> HTTP over Tailscale/Headscale mesh (WireGuard encrypts all traffic)

---

## Quick Health Check

```bash
ssh vansh@100.84.60.109
cd ~/homelab-ops-mesh/pi && bash scripts/health-check.sh
```

Green = OK, Red = problem.

---

## Service List

### Pi Services (20 containers + 1 systemd service)

| # | Service | Path / URL | Credentials | How to check |
|---|---------|------------|-------------|--------------|
| 1 | Traefik | `/dashboard/` | Basic auth (`.env`) | Dashboard shows routers + services |
| 2 | Portainer | `127.0.0.1:9000` | Set on first visit | All containers show "running" |
| 3 | Pi-hole | `127.0.0.1:8053/admin` | `PIHOLE_WEBPASSWORD` in `.env` | Dashboard shows query stats |
| 4 | Nextcloud | `/cloud/` | `NEXTCLOUD_ADMIN_USER` in `.env` | Login page appears |
| 5 | Vaultwarden | `/vault/` | Create account on first visit | Login page appears |
| 6 | Home Assistant | `/hass/` (host net :8123) | Set during first setup | Setup/login page appears |
| 7 | Uptime Kuma | `127.0.0.1:8082` | Set on first visit | All monitors show green "UP" |
| 8 | Syncthing | `127.0.0.1:8384` | API key in UI | Devices connected |
| 9 | Promtail | No UI | None | Logs flow to Loki on Windows |
| 10 | Node Exporter | `100.84.60.109:9100/metrics` | None | Metrics endpoint returns data |
| 11 | cAdvisor | `100.84.60.109:8083/containers` | None | Container metrics visible |
| 12 | Pi-hole Exporter | `100.84.60.109:9617/metrics` | None | Metrics endpoint returns data |
| 13 | CrowdSec | No UI | CLI: `cscli decisions list` | Shows active decisions |
| 14 | CrowdSec Relay | No UI | Bearer token auth | 200 on valid POST, 401 on bad |
| 15 | Headscale | `0.0.0.0:8086` | API key in `.env` | `curl http://100.84.60.109:8086/health` |
| 16 | Gitea | `/git/` | Set on first visit | Login page appears |
| 17 | act_runner | No UI | Token in `.config/act-runner/` | `systemctl --user status act-runner` |

### Windows Services (10 containers)

| # | Service | Path / URL | Credentials | How to check |
|---|---------|------------|-------------|--------------|
| 1 | Grafana | `/grafana/` | `GF_SECURITY_ADMIN_USER` in `.env` | Dashboards show live metrics |
| 2 | Prometheus | `127.0.0.1:9090/targets` | None | All 8 targets show "UP" |
| 3 | Alertmanager | `127.0.0.1:9093` | None | Status page shows silences/receivers |
| 4 | Loki | `127.0.0.1:3100/ready` | None | Returns "ready" |
| 5 | Tempo | `100.84.60.109:3200/ready` | None | Returns "ready" |
| 6 | Authelia | `/auth/` | See `users_database.yml` | Login page appears |
| 7 | Infisical | `/secrets/` | Set on first visit | Project secrets visible |

---

## Port Summary

### Pi Host Ports

| Port | Service | Binding | Purpose |
|------|---------|---------|---------|
| 22 | SSH | 0.0.0.0 | Remote terminal |
| 53 | Pi-hole DNS | 0.0.0.0 (UDP) | DNS server |
| 80 | Traefik HTTP | 0.0.0.0 | Reverse proxy (HTTP over Tailscale mesh) |
| 8080 | Nextcloud | 127.0.0.1 | File cloud |
| 8081 | Vaultwarden | 127.0.0.1 | Password manager |
| 8082 | Uptime Kuma | 127.0.0.1 | Uptime monitoring |
| 8083 | cAdvisor | 0.0.0.0 | Container metrics |
| 8084 | Traefik API | 0.0.0.0 | Prometheus metrics |
| 8086 | Headscale | 0.0.0.0 | Control server (HTTP) |
| 8087 | Gitea web | 127.0.0.1 | Self-hosted Git UI |
| 8088 | Gitea SSH | 127.0.0.1 | Git SSH access |
| 9000 | Portainer | 127.0.0.1 | Docker UI |
| 9092 | Headscale metrics | 127.0.0.1 | Prometheus metrics |
| 9100 | Node Exporter | 0.0.0.0 | Host metrics |
| 9617 | Pi-hole Exporter | 0.0.0.0 | DNS metrics |
| 8123 | Home Assistant | host mode | Home automation |
| 8384 | Syncthing | 127.0.0.1 | File sync UI |
| 139/445 | Samba | 0.0.0.0 | File sharing |

### Windows Host Ports

| Port | Service | Binding | Purpose |
|------|---------|---------|---------|
| 3000 | Grafana | 100.84.60.109 | Dashboards (Tailscale-only) |
| 3200 | Tempo | 100.84.60.109 | Traces (Tailscale-only) |
| 3100 | Loki | 127.0.0.1 | Log storage |
| 4317 | Tempo OTLP | 127.0.0.1 | gRPC trace ingest |
| 8083 | Infisical | 100.84.60.109 | Secrets UI (Tailscale-only) |
| 9090 | Prometheus | 127.0.0.1 | Metrics |
| 9091 | Authelia | 100.84.60.109 | SSO (Tailscale-only) |
| 9093 | Alertmanager | 127.0.0.1 | Alerts |

---

## Troubleshooting Quick Reference

| Problem | What to try |
|---------|------------|
| Website 404 | Check Traefik dashboard — is the router listed? |
| Website 502 | Backend container may be down. Run `docker ps` |
| Can't reach any service | Pi powered on? Try `ping 100.84.60.109` via Tailscale |
| Pi-hole not blocking ads | `nslookup doubleclick.net 192.168.68.59` should return `0.0.0.0` |
| Low disk space | `df -h /` — clear old backups in `/mnt/nas/backup/` |
| Service keeps restarting | `docker logs containername --tail 50` |
| RAM > 90% | `docker stats --no-stream` — find heavy container, check limits |
