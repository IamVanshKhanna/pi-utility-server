# ADR-007: Headscale over Tailscale SaaS; HTTP-over-mesh

## Status
Accepted (supersedes the Tailscale SaaS tailnet previously used).

## Context
The homelab previously joined a Tailscale SaaS tailnet
(`autobot.taila24d04.ts.net`). That required third-party infrastructure and
made the mesh unusable when the internet link was down. Services were
addressed via `*.ts.net` MagicDNS names.

Migrated to a self-hosted Headscale control server (`headscale` container on
the Pi, mesh IP `100.64.0.1`) and dropped the SaaS tailnet. All peers
(TUF, mr-stranger, MacBook, phone) are mesh members with
`100.x.x.x` addresses.

## Decision
- Run Headscale v0.29.1 on the Pi as the control plane.
- Access services **over the mesh using HTTP** (`http://100.84.60.109:<port>`)
  — no TLS at the edge; encryption-in-transit is provided by the WireGuard
  mesh itself (like Tailscale, which is also HTTP-over-mesh internally).
- The public endpoint `http://203.123.106.92:8086` is reachable from the
  internet via a router port-forward to the headscale container. This is used
  to bootstrap new nodes that cannot reach the Pi over the mesh.
- Headscale's embedded DERP + STUN listen on `0.0.0.0:3478/udp` (published in
  the headscale compose file) so direct-connect negotiation works for
  public-network peers.

## Consequences
- Mesh is functional without internet (control server is local).
- Public headscale endpoint is currently plain HTTP. Anyone probing
  `203.123.106.92:8086` sees control-plane traffic in the clear. If the
  endpoint stays internet-exposed, TLS should be added (reverse proxy with
  Let's Encrypt) — tracked as a hardening follow-up, not a blocker.
- `*.ts.net` MagicDNS names are gone; service URLs are mesh IPs:
  `http://100.84.60.109:8081` (vaultwarden), `:8082` (uptime-kuma),
  `:8087` (gitea), `:8091` (vansh-portfolio), `:8092` (beszel).

## Superseded ADRs
- Any earlier decision referencing the Tailscale SaaS tailnet.
