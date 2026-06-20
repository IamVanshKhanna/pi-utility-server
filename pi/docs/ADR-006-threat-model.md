# ADR-006: Threat Model and Security Architecture (STRIDE)

## Status
Accepted

## Context
The homelab-prod v1.4 introduces authentication (Authelia), DNS-01 TLS, intrusion detection (CrowdSec), and supply chain security (Syft+Cosign). We need a documented threat model.

## Decision
Use **STRIDE** methodology to model threats to the homelab-prod system.

## STRIDE Analysis

| Threat | Description | Mitigation |
|--------|-------------|------------|
| **Spoofing** | Attacker impersonates user/service | Authelia 2FA for all external access; Traefik ForwardAuth on all routes; Tailscale for admin access |
| **Tampering** | Unauthorized modification of data/config | Git-signed commits (Cosign); SBOM verification; Infisical secrets; Config in Git |
| **Repudiation** | Actions cannot be traced | Centralized logging (Loki); Audit logs (Authelia, CrowdSec); Git commit signatures |
| **Information Disclosure** | Sensitive data exposure | TLS everywhere (Traefik + Let's Encrypt DNS-01); Infisical secrets; Network segmentation |
| **Denial of Service** | Service unavailable | Rate limiting (Traefik); CrowdSec IPS; Resource limits (Docker); ZRAM swap |
| **Elevation of Privilege** | Unauthorized access escalation | Least privilege containers; Authelia RBAC; Tailscale ACLs; Read-only root FS |

## Attack Surface

| Component | Exposure | Protection |
|-----------|----------|------------|
| Traefik (80/443) | Internet | TLS, Authelia ForwardAuth, Rate limiting |
| Tailscale (UDP 51820) | Internet | WireGuard crypto, ACLs, Exit node |
| SSH (Tailscale) | Tailscale only | Key-only auth, Fail2ban |
| Authelia (9091) | Internal only | Traefik only, 2FA |
| Prometheus (9090) | Internal only | Localhost bind, Traefik proxy |
| CrowdSec | Local/Internal | Log parsing only, no external exposure |

## Trust Boundaries

```
Internet → [Tailscale/WG] → [Traefik:443] → [Authelia ForwardAuth] → Services
                ↓
           [CrowdSec] ← Logs from Traefik, Auth, System
                ↓
           [Infisical] ← Secrets for all services
```

## Data Classification

| Data | Classification | Protection |
|------|----------------|------------|
| User credentials (Authelia) | Secret | Argon2id, Infisical |
| TLS private keys | Secret | Traefik ACME, file perms 600 |
| Restic repo password | Secret | Infisical, env var |
| Database passwords | Secret | Infisical, env var |
| Application configs | Confidential | Git (encrypted via Infisical) |
| Logs (Loki) | Confidential | Internal network only |
| Metrics (Prometheus) | Internal | Localhost + Traefik proxy |

## Incident Response

### Detection
- CrowdSec alerts → Telegram
- Prometheus alerts → Telegram (Authelia, Prometheus, Loki)
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