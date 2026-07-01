# Windows Node (mr-stranger)

Heavy compute services for the homelab, running on Docker Desktop for Windows.

## Stacks

| Stack | Services | Port(s) | Access |
|-------|----------|---------|--------|
| **auth** | Authelia SSO + Redis | 9091 | `/auth/` via Pi Traefik |
| **monitoring** | Grafana + Prometheus + Alertmanager + Loki | 3000, 9090, 9093, 3100 | `/grafana/` via Pi Traefik |
| **secrets** | Infisical + PostgreSQL + Redis | 8083 | `/secrets/` via Pi Traefik |
| **tracing** | Tempo | 3200, 4317 | `/tempo/` via Pi Traefik |

## Network

All stacks share the `homelab_win` Docker bridge network. The **auth** stack creates it; others declare it as `external: true`. Deploy auth first:

```powershell
docker compose -f windows/stacks/auth/docker-compose.yml --env-file windows/.env up -d
```

## Prerequisites

- Docker Desktop for Windows (with WSL2 backend)
- Tailscale connected via Headscale (IP `100.64.0.2`)
- `windows/.env` configured (copy from `windows/.env.example`)

## Deployment Order

1. **auth** (creates `homelab_win` network)
2. **monitoring**, **secrets**, **tracing** (in any order)

## Deployment

All compose commands run from the repo root with absolute paths:

```powershell
docker compose -f windows/stacks/<stack>/docker-compose.yml --env-file windows/.env up -d
```

## Teardown

```powershell
docker compose -f windows/stacks/<stack>/docker-compose.yml --env-file windows/.env down
```

## Backup

Export all Windows Docker named volumes to tar archives:

```powershell
powershell -ExecutionPolicy Bypass -File windows/scripts/backup-volumes.ps1
```

Volumes backed up: Grafana, Prometheus, Loki, Alertmanager, Tempo, Authelia, Infisical DB.
Archives stored in `windows/backups/` with 7-day retention.
