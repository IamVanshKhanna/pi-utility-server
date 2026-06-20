# ADR-002: Remote Access — Tailscale over Raw WireGuard

## Status
Accepted

## Context
Need secure remote access to Pi homelab from phone/laptop without port forwarding.
Options:
- **Tailscale** (managed WireGuard mesh)
- **Raw WireGuard** (manual peers, port forward)
- **Headscale** (self-hosted Tailscale control plane)
- **Cloudflare Tunnel** (no UDP, higher latency)

## Decision
Use **Tailscale** for v1.

## Rationale

| Factor | Tailscale | Raw WireGuard | Headscale | Cloudflare Tunnel |
|--------|-----------|---------------|-----------|-------------------|
| NAT traversal | Automatic (DERP) | Manual port forward | Automatic (DERP) | Automatic |
| Key rotation | Automatic (daily) | Manual | Automatic | N/A |
| ACLs | Built-in (tags) | None | Configurable | Limited |
| Mobile app | Excellent | Manual config | Use Tailscale app | Cloudflare One |
| MagicDNS | Yes | No | Yes | No |
| Exit node | Yes | Manual | Yes | No |
| Self-hosted control | No | Yes | Yes | N/A |
| Cost (personal) | Free (100 devices) | Free | VPS cost | Free tier |

**Key for Pi:** Tailscale container runs on host network, zero config, works over CGNAT, mobile app stays connected.

## Consequences
- Dependency on Tailscale coordination servers (not fully air-gapped)
- Free tier limits: 100 devices, 3 users (fine for personal)
- Headscale kept as v2 option for full self-hosting

## References
- [Tailscale architecture](https://tailscale.com/how-it-works/)
- [Headscale project](https://github.com/juanfont/headscale)