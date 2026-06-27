# ADR-001: Container Orchestration — Docker Compose over K3s

## Status
Accepted

## Context
We need to run ~28 containers across a Raspberry Pi 4B (4 GB RAM, ARM64) and a Windows Desktop (16 GB RAM).
Options evaluated:
- **Docker Compose v2** (standalone plugin)
- **K3s** (lightweight Kubernetes)
- **Nomad** (HashiCorp scheduler)

## Decision
Use **Docker Compose** across both nodes, linked via Tailscale mesh network.

## Rationale

| Factor | Docker Compose | K3s | Nomad |
|--------|----------------|-----|-------|
| RAM overhead | ~50 MB per node | ~800 MB (control plane + agent) | ~200 MB |
| Binary size | 1 (docker + compose plugin) | 1 (k3s) | 2 (nomad server + client) |
| Learning curve | Low (existing knowledge) | Medium (K8s concepts) | Medium (HCL, scheduling) |
| Upgrades | `docker compose pull && up -d` | `k3s upgrade` + workload rolling | Nomad job updates |
| ARM64 support | Native | Native | Native |
| Multi-node | Manual (2 compose files + Tailscale) | Yes (single cluster) | Yes |
| Service mesh | No | Traefik/Linkerd | Consul Connect |

**Key constraint:** 4 GB RAM on Pi. K3s control plane alone consumes ~600–800 MB idle, leaving < 3 GB for workloads. Compose leaves ~3.5 GB. Multi-node achieved via Tailscale mesh (Pi + Windows) instead of K8s federation.

## Consequences
- No rolling updates (recreate only)
- No self-healing beyond `restart: unless-stopped`
- No horizontal scaling (per node)
- Multi-node achieved at network level (Tailscale) rather than orchestration level
- Acceptable for homelab scale; revisit if >2 nodes needed

## References
- [K3s resource requirements](https://docs.k3s.io/installation/requirements)
- [Docker Compose v2 release](https://github.com/docker/compose/releases)