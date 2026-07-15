# ADR-004: Secrets Management — Infisical over .env Files

## Status
Accepted

> **Superseded by ADR-009** (2026-07-15) — Windows-hosted Infisical retired. .env remains the real secrets store; this ADR documents the original (unrealized) intent only.

## Context
v1.1 used a single `.env` file with all secrets in plaintext. This approach has several problems:
- Secrets in plaintext on disk (readable by any process with file access)
- No audit trail of who accessed what secret
- No rotation mechanism — changing a secret requires editing `.env` and restarting all containers
- No differentiation between environments (dev/staging/prod)
- Secrets committed to git if `.gitignore` fails
- No programmatic access for CI/CD pipelines

Options evaluated:
| Option | Pros | Cons |
|--------|------|------|
| **Infisical** (self-hosted) | Open source, audit log, rotation, CLI, GitOps, free tier | Additional infrastructure (PostgreSQL + Redis) |
| **HashiCorp Vault** | Enterprise features, dynamic secrets | Heavy (Java), complex setup, overkill for homelab |
| **sops + age** | Git-native, encrypts `.env` at rest | No runtime injection, no audit log, manual rotation |
| **Docker secrets** | Native to Swarm | Not available in Compose standalone |
| **External secrets operator** | K8s-native | Requires K8s (K3s) |

## Decision
Use **Infisical** (self-hosted) for v1.2+.

## Rationale
- **Self-hosted** — runs on our Pi, no external dependency
- **Audit log** — tracks every secret access
- **Rotation** — change once in UI, all deployments pick up new value
- **CLI** — `infisical run -- docker compose up -d` injects at runtime
- **Projects/environments** — separate dev/staging/prod namespaces
- **Free tier** — unlimited secrets for personal use
- **Lightweight** — Go binary, ~50MB RAM + PostgreSQL + Redis

## Implementation (v1.2 — completed; v1.4 — migrated to Windows)
1. Infisical stack deployed (PostgreSQL + Redis + Infisical) — now on Windows Desktop
2. **Not using runtime injection** — staying with `.env` files for simplicity (no `infisical run` wrapper)
3. Infisical serves as secret audit log and rotation reference, not runtime injection
4. `.env` remains the source of truth for Docker Compose deployment
5. `.template` files committed to git with placeholder values; real files gitignored

## Consequences
- **Added complexity**: 3 new containers (Infisical, PostgreSQL, Redis) — ~1GB RAM on Windows
- **Windows dependency**: Infisical runs on Windows Desktop; must be up for secrets access
- **Boot order**: Infisical healthy before other stacks can reference secrets (not enforced — `.env` is current source of truth)

## References
- [Infisical docs](https://infisical.com/docs)
- [Infisical Docker deploy](https://infisical.com/docs/self-hosting/docker)
- [Infisical CLI](https://infisical.com/docs/cli/overview)