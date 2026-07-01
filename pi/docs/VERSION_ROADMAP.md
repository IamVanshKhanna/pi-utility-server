# Version Roadmap — homelab-ops-mesh

> Living document. Updated each release.

---

## Versioning Scheme
- **Major** (v1, v2): Architectural shifts, breaking changes
- **Minor** (v1.1, v1.2): New services, features, non-breaking improvements
- **Patch** (v1.0.1): Bug fixes, dependency updates, doc corrections

---

## Current: v1.6 — Self-Hosted Control Plane ✅ Released

| Version | Focus | Status |
|---------|-------|--------|
| **v1.0** | Single Pi baseline: Traefik, Portainer, Pi-hole, Tailscale, Nextcloud, Vaultwarden, Home Assistant | ✅ Released |
| **v1.1** | Observability: Loki+Promtail, Alertmanager+Telegram, Uptime Kuma, ZRAM | ✅ Released |
| **v1.2** | Secrets + backup: Infisical, Restic, backup automation | ✅ Released |
| **v1.3** | Security: Authelia SSO, CrowdSec IDS, ForwardAuth | ✅ Released |
| **v1.4** | Multi-node mesh: Pi + Windows, 28 containers, Docker Compose only | ✅ Released |
| **v1.5** | Security audit: STRIDE review, Redis auth, TinyBot hardening, dashboard cleanup, network hardening | ✅ Released |
| **v1.6** | Headscale self-hosted Tailscale control plane, HTTP-over-mesh architecture | ✅ Released |

---

## Future

| Version | Focus | Status |
|---------|-------|--------|
| **v1.6** | Headscale self-hosted Tailscale control plane | ✅ Released |
| **v1.7** | Gitops: Gitea + CI/CD on Pi | 📋 Planned |
| **v2.0** | Edge/IoT: Matter/Thread/Zigbee bridge, HA integration | 📋 Planned |

---

## Key Architectural Decisions

| Version | Decision | ADR |
|---------|----------|-----|
| v1.0 | Docker Compose over K3s | ADR-001 |
| v1.0 | Tailscale over raw WireGuard | ADR-002 |
| v1.0 | ZRAM + memory limits on 4GB Pi | ADR-003 |
| v1.2 | Infisical for secrets management | ADR-004 |
| v1.3 | TinyBot agent (replaces Hermes) | ADR-005 |
| v1.3 | STRIDE threat model | ADR-006 |
| v1.6 | Headscale over Tailscale SaaS; HTTP-over-mesh | ADR-007 |
