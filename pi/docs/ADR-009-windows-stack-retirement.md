# ADR-009: Retire Windows Observability/Secrets/Auth Stack

## Status
Accepted

## Context
ADR-003 (memory strategy) and ADR-004 (secrets) planned to offload heavy
services to the Windows node: Grafana, Loki, Prometheus, Alertmanager, Tempo,
Authelia (+ Redis), Infisical (+ DB + Redis) — 11 containers total.

This was built and briefly ran, but in practice:
- Single-operator homelab — no multi-user access control need (Authelia's
  core value proposition)
- No secret rotation workflow was ever actually used — .env remained the
  real source of truth for Pi-side services throughout
- No tracing need materialized (Tempo never had real distributed-trace use
  cases to justify itself)
- Full Loki/Prometheus/Grafana stack overhead not justified against actual
  usage — Uptime Kuma already covers the up/down monitoring that's actually
  used day to day

## Decision
Retire the Windows secrets/auth/tracing/monitoring stack. Containers are
stopped (not yet removed — pending manual cleanup). No successor deployed
as part of this decision; see ADR-010 (if written) for any lightweight
monitoring replacement.

## Consequences
- Secrets remain in .env files (gitignored, see current pi-utility-server
  root .env / stacks/nas/.env pattern) — not the Infisical-managed rotation
  ADR-004 originally called for. ADR-004 is superseded by this decision.
- No auth/RBAC layer in front of any service. Access control is entirely
  Headscale mesh membership — anyone with a valid mesh node can reach any
  service directly.
- No tracing, no long-term metrics history beyond what Uptime Kuma retains.
- Windows node's role in the architecture is currently undefined beyond
  hosting mr-stranger as a mesh peer.

## Superseded ADRs
- ADR-004-secrets: Infisical decision no longer applies. .env remains
  authoritative.
- ADR-006-threat-model: Authelia-based mitigations (Spoofing, Elevation of
  Privilege rows) no longer apply. Mesh membership is now the sole access
  control boundary — worth a fresh STRIDE pass if threat model matters
  going forward.
