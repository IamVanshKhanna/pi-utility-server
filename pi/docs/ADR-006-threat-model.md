# ADR-006: Threat Model and Security Architecture (STRIDE)

## Status
Accepted

## Context
The homelab-ops-mesh v1.4 introduces authentication (Authelia), Tailscale HTTPS, intrusion detection (CrowdSec), and container hardening (pinned tags, CPU/mem limits, `:ro` mounts). We need a documented threat model.

## Decision
Use **STRIDE** methodology to model threats to the homelab-ops-mesh system.

## STRIDE Analysis

| Threat | Description | Mitigation |
|--------|-------------|------------|
| **Spoofing** | Attacker impersonates user/service | Authelia 2FA for all external access; Traefik ForwardAuth on all routes; Tailscale for admin access |
| **Tampering** | Unauthorized modification of data/config | Git-tracked config; Infisical secrets; Config mounts `:ro`; Pinned image tags |
| **Repudiation** | Actions cannot be traced | Centralized logging (Loki); Audit logs (Authelia, CrowdSec); Git commit signatures |
| **Information Disclosure** | Sensitive data exposure | TLS everywhere (Tailscale Serve + MagicDNS); Infisical secrets; Tailscale network isolation |
| **Denial of Service** | Service unavailable | Rate limiting (Traefik); CrowdSec IPS; Resource limits (Docker); ZRAM swap |
| **Elevation of Privilege** | Unauthorized access escalation | Least privilege containers; Authelia RBAC; Tailscale ACLs; No root in containers; `NoNewPrivileges` systemd |

## Attack Surface

| Component | Exposure | Protection |
|-----------|----------|------------|
| Traefik (80/8443) | Tailscale network | Tailscale Serve TLS, Authelia ForwardAuth, Rate limiting |
| Tailscale mesh | Internet | WireGuard crypto, ACLs, MagicDNS |
| SSH (22) | Tailscale only | Key-only auth, password disabled |
| Authelia (9091) | Internal only | Traefik only, 2FA |
| Prometheus (9090) | Internal only | Localhost bind, Traefik proxy |
| CrowdSec | Local/Internal | Log parsing only, no external exposure |

## Trust Boundaries

```
Internet → [Tailscale mesh] → [Traefik:8443] → [Authelia ForwardAuth] → Services
                 ↓
            [CrowdSec] ← Logs from Traefik, Auth, System
                 ↓
            [Infisical] ← Secret audit + rotation (Windows)
```

## Data Classification

| Data | Classification | Protection |
|------|----------------|------------|
| User credentials (Authelia) | Secret | Argon2id (memory: 65536), `.env` file |
| TLS private keys | Secret | Tailscale manages, auto-rotation |
| Restic repo password | Secret | `.env` file, gitignored |
| Database passwords | Secret | `.env` file, gitignored |
| Application configs | Confidential | Git (templates only; real configs gitignored) |
| Logs (Loki) | Confidential | Internal network only |
| Metrics (Prometheus) | Internal | Localhost + Traefik proxy |

## Incident Response

### Detection
- CrowdSec alerts → Telegram relay
- Prometheus alerts → Alertmanager → Telegram
- Health checks → Logs + Telegram

### Containment
- `docker compose down <service>` via Makefile
- Traefik: disable router via label
- Authelia: ban IP via regulation rules
- CrowdSec: add to ban list

### Eradication
- Restore from Restic backup (tested weekly)
- Rotate secrets via Infisical
- Rebuild container from clean image

### Recovery
- Verify restore with `make restore-test`
- Validate health with `make verify-v1`
- Monitor alerts for 24h

## References
- [STRIDE methodology](https://docs.microsoft.com/en-us/azure/security/develop/threat-modeling-tool-threats)
- [Authelia security](https://www.authelia.com/docs/security/)
- [CrowdSec architecture](https://docs.crowdsec.net/docs/architecture/)
- [Traefik security](https://doc.traefik.io/traefik/middlewares/http/forwardauth/)