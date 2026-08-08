# ADR-010: Single-node consolidation, beszel monitoring, and P0 hardening

## Status
Accepted (2026-08-08). Implements the P0 items from the repository
improvement plan.

## Context
After ADR-009 retired the Windows observability/secrets/auth stack, the Pi
was the only compute node. A review scored the repository 5.5/10 and found
drift between the repo and live reality: backups did not cover the real data
(Docker named volumes in `/var/lib/docker/volumes`, not `/mnt/nas`),
systemd units pointed at a deleted path, scripts referenced retired
containers, and two remotes (GitHub + self-hosted gitea) needed a defined
sync workflow.

## Decisions

### 1. Real backups
- `backup.sh` now enumerates **Docker named volumes** and backs up their
  mountpoints, plus NAS user dirs (`01. sync`, `02. shared`, `04. media`)
  and the live secrets env file. The restic repo, restic cache
  (`RESTIC_CACHE_DIR`), and `/mnt/nas/03. backup` are excluded from itself.
- `backup-os.sh` fixed: explicit `--exclude` arguments (brace expansion does
  not occur inside quotes) and `--one-file-system`.
- Both scripts resolve env via `PI_ENV_FILE` override > repo `.env` > live
  secrets file, matching the existing cron entry.

### 2. Monitoring
- Adopted **beszel** (`henrygd/beszel:0.18.7`, pinned) as the lightweight
  monitoring replacement called for by ADR-009. Hub bound to loopback +
  mesh IP `100.84.60.109:8092`; agent uses host networking + a shared unix
  socket.

### 3. Ethernet-first connectivity
- The Pi now prefers the wired link (`eth0-preferred` NetworkManager profile,
  default route via eth0). Measured: 919 Mbps down (vs 55.9 Mbps Wi-Fi),
  iperf3 ~700-900 Mbit/s vs ~369-435, SMB 13.8/16.9 MB/s (vs 6.1/12.2).
- SMB is the remaining bottleneck: samba pins one core (~101% of its
  `cpus: 1.0` quota) under load — a Pi 4 single-stream SMB3 limitation.
  Accepted; further gains would require disabling signing/encryption.

### 4. Systemd unit migration
- Units repointed from the deleted `/home/vansh/homelab-ops-mesh` to
  `/mnt/nas/02. shared/01. PI Files/01. pi-utility-server`.
- `homelab-daily-summary` re-enabled (was failing daily since the path died).
- `act-runner` repointed and verified (registered runner id 4 on gitea).
- `tinybot` restored from repo source (code had migrated but was never
  redeployed); venv recreated, env loaded via launcher.
- `homelab-secrets-rotation` **enabled** (2026-08-08): `secrets-rotation.sh`
  authored and the Sunday 03:00 timer armed. It rotates only
  `VAULTWARDEN_ADMIN_TOKEN` and recreates the vaultwarden container so the
  token takes effect; the new token is Telegram-notified. `SAMBA_PASSWORD`
  and `PIHOLE_WEBPASSWORD` are intentionally untouched (weekly rotation
  would lock out SMB clients / the pihole UI).

### 5. Repo housekeeping
- Removed `.bak`/scratch files; refreshed `.env.example` to the current
  stack set (retired Traefik/Nextcloud/Grafana/WireGuard/CrowdSec keys gone).
- Vendored the vansh-portfolio source (previously an absolute build path
  outside the repo); the stack now builds from `./app`.
- Headscale compose publishes DERP/STUN `0.0.0.0:3478:3478/udp`; `TZ`
  interpolated (was a literal empty string).
- Documentation ADR-007 added (headscale over mesh; previously referenced
  but missing).

### 6. Dual-remote git workflow and CI gate
- Canonical remote is **GitHub** (`IamVanshKhanna/pi-utility-server`).
- Self-hosted **gitea** (`100.84.60.109:8087/vansh/pi-utility-server`) is a
  direct-push second remote, kept in sync by pushing to both after each
  commit. Push auth uses a scoped `pi-push` token read from the secrets env
  (never stored in the repo); existing gitea repos remain GitHub pull
  mirrors.
- **CI validation**: the gitea workflow `.gitea/workflows/deploy.yml` runs
  on `main` push (runner label `pi`): validates shell script syntax and
  compose config for every stack, then runs `health-check.sh`. The GitHub
  mirror is pushed manually after gitea CI goes green.

### 7. Offsite backup (Backblaze B2)
- `backup.sh` mirrors the local restic repo to a B2 repo
  (`b2:<bucket>:pi-utility-server/restic`) after every successful run,
  applying the same retention policy, gated by `B2_ENABLED=true` plus valid
  `B2_ACCOUNT_ID`/`B2_ACCOUNT_KEY`. The B2 repo is initialized on first
  use. **Decision (2026-08-08): skipped for cost.** B2 was never configured —
  the env holds `.env.example` placeholders and `B2_ENABLED=false` is kept so
  `backup.sh` never attempts the mirror. Can be enabled later by adding a
  valid bucket + application key and setting `B2_ENABLED=true`.

## Consequences
- Backups now restore the actual service data; a restore drill is still a
  follow-up (P1).
- Monitoring is lightweight (~200 MB savings vs the retired stack).
- Public headscale endpoint remains plain HTTP — TLS is a hardening follow-up
  (accepted: headscale is reachable over the mesh, which is the normal path).
- Secret rotation is live for the admin token; the new value is delivered
  over Telegram.
- GitHub pushes are manual and happen after gitea CI is green.

## Superseded ADRs
- None. Extends ADR-007 (headscale) and ADR-009 (Windows stack retirement).
