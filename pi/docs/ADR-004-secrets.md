# ADR-004: Secrets Management — Infisical over .env Files

## Status
Accepted

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

## Implementation Plan (v1.2)
1. Deploy Infisical stack (PostgreSQL + Redis + Infisical) in new `secrets` phase
2. Generate `AUTH_SECRET`, `ENCRYPTION_KEY`, `REDIS_PASSWORD` in `.env`
3. On first login, create project "homelab-prod", add all `.env` secrets
4. Update deploy: `infisical run --projectId=... --env=production -- docker compose up -d`
5. Remove plaintext secrets from `.env` (keep only Infisical config)
6. Document rotation procedure

## Consequences
- **Added complexity**: 3 new containers (Infisical, PostgreSQL, Redis) ~400MB RAM
- **Boot dependency**: Infisical must be healthy before other stacks deploy
- **Migration effort**: One-time `.env` → Infisical migration
- **Operational**: Must monitor Infisical health (added to health checks)

## Alternative for v2.0
If Infisical proves too heavy, evaluate **sops + age** for GitOps-native approach with Flux/ArgoCD.

## References
- [Infisical docs](https://infisical.com/docs)
- [Infisical Docker deploy](https://infisical.com/docs/self-hosting/docker)
- [Infisical CLI](https://infisical.com/docs/cli/overview)