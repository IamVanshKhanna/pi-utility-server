# ADR-008: Gitea + act_runner for Self-Hosted GitOps

## Status
Accepted

## Context
v1.6 completed the self-hosted control plane (Headscale). However, the deployment workflow remains manual: code changes are committed on Windows, synced to Pi via git bundle + SCP, then `update.sh` is run manually over SSH. This is error-prone, slow, and provides no validation or audit trail.

## Decision
Deploy **Gitea** (self-hosted Git) in Docker and **act_runner** binary as a systemd user service on the Pi to enable push-to-deploy GitOps.

| Component | Choice | Rationale |
|-----------|--------|-----------|
| Git server | Gitea 1.26.4-rootless (Docker) | Lightweight, SQLite, ARM64 native, community-supported, rootless for security |
| CI runner | act_runner (systemd host service) | Direct access to docker CLI, bash, and repo without container nesting issues |

### Alternatives Considered

| Option | Rejected Because |
|--------|-----------------|
| Forgejo + Forgejo Runner | Fork of Gitea; compatible but smaller community; no advantage for single-user homelab |
| Drone CI | Licensing uncertainty; Cloud version deprecated; less compatible with GitHub Actions YAML |
| Woodpecker CI | Smaller ecosystem; different YAML syntax; less documentation |
| Jenkins | JVM too heavy for Pi 4B 4GB; unnecessary complexity |
| GitHub Actions (SaaS) | Defeats self-hosted goal; requires internet for every pipeline run |
| gitea/runner in Docker | Thin image lacks docker CLI; dind variant adds ~150MB overhead and container nesting complexity; host runner is simpler and more reliable |

### Resource Budget

| Service | mem_limit | Typical |
|---------|-----------|---------|
| Gitea (SQLite, rootless) | 256 MB | ~100 MB |
| act_runner (host binary) | ~20 MB | ~10 MB |
| **Total new** | **~276 MB** | **~110 MB** |

Pi typical free RAM remains ~1 GB after these additions.

### Deployment Architecture

- Gitea web on `127.0.0.1:8087` (Traefik-routed at `/git/`)
- Gitea SSH on `127.0.0.1:8088` (for git push/pull)
- act_runner runs as `~/.config/systemd/user/act-runner.service` on the Pi host
- Runner label `pi:host` — CI steps execute directly on the host (docker, bash, git all available)
- Runner config at `~/.config/act-runner/config.yaml`
- Registration data at `~/.config/act-runner/.runner` (gitignored)
- CI workflow (`.gitea/workflows/deploy.yml`): pull → validate → render dynamic.yml → deploy → health-check → notify
- `DISABLE_REGISTRATION = true` — single-user instance
- Manual `update.sh` retained as fallback if Gitea is down

### Security Considerations

- act_runner on host has direct docker access — same trust model as manual SSH (single-user homelab)
- Gitea `read_only: true` + tmpfs — hardened container
- SSH port 8088 bound to localhost only — no external access
- Config secrets in `app.ini` (gitignored, auto-generated from template on first start)
- Runner registration token used once at setup, not at deploy time

## Consequences
- Push to self-hosted Gitea triggers automatic deployment
- Manual SSH-to-Pi workflow eliminated for routine changes
- GitHub remains as upstream mirror (optional, v1.8+)
- `update.sh` retained as emergency fallback
- Adds 1 container + 1 systemd service (20 Pi containers + 1 systemd service, 30 overall)
