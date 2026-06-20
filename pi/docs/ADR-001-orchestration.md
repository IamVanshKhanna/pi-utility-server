# ADR-001: Container Orchestration — Docker Compose over K3s

## Status
Accepted

## Context
We need to run ~15 containers on a single Raspberry Pi 4B (4 GB RAM, ARM64).
Options evaluated:
- **Docker Compose v2** (standalone plugin)
- **K3s** (lightweight Kubernetes)
- **Nomad** (HashiCorp scheduler)

## Decision
Use **Docker Compose** for v1.

## Rationale

| Factor | Docker Compose | K3s | Nomad |
|--------|----------------|-----|-------|
| RAM overhead | ~50 MB | ~800 MB (control plane + agent) | ~200 MB |
| Binary size | 1 (docker + compose plugin) | 1 (k3s) | 2 (nomad server + client) |
| Learning curve | Low (existing knowledge) | Medium (K8s concepts) | Medium (HCL, scheduling) |
| Upgrades | `docker compose pull && up -d` | `k3s upgrade` + workload rolling | Nomad job updates |
| ARM64 support | Native | Native | Native |
| Multi-node | No (not needed) | Yes | Yes |
| Service mesh | No | Traefik/Linkerd | Consul Connect |

**Key constraint:** 4 GB RAM total. K3s control plane alone consumes ~600–800 MB idle, leaving < 3 GB for workloads. Compose leaves ~3.5 GB.

## Consequences
- No rolling updates (recreate only)
- No self-healing beyond `restart: unless-stopped`
- No horizontal scaling (single node)
- Acceptable for v1; revisit if multi-node needed

## References
- [K3s resource requirements](https://docs.k3s.io/installation/requirements)
- [Docker Compose v2 release](https://github.com/docker/compose/releases)