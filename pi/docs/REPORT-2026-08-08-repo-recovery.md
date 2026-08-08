# Homelab Pi Repo — Recovery Report (2026-08-08)

Scope: the `pi-utility-server` repository on `autobot-1` (Raspberry Pi).
This report compares the state before this effort started, what was fixed,
what a "perfect repo" looks like, and what remains to get there.

---

## 1. Where we started (baseline, before this effort)

A review scored the repo **5.5 / 10**. The repo and live reality had drifted
badly. Concrete problems found:

### Backups
- Docker named volumes (the real service data, under root-owned
  `/var/lib/docker/volumes`) were **not backed up at all** — only NAS paths
  were, and most of those were stale.
- `backup.sh` did `command -v restic`; restic lives at `~/bin/restic` (not on
  PATH), so it would have failed at 03:00.
- `backup-os.sh` had a quoted `--exclude={...}` brace-expansion bug (no
  exclusions applied) and no `--one-file-system`.
- The restic cache lived **inside** the backed-up data.
- No restore drill had ever been run.

### systemd units
- `homelab-daily-summary`, `tinybot`, `act-runner`, `secrets-rotation` all
  pointed at the **deleted** `/home/vansh/homelab-ops-mesh` path.
- `daily-summary` failed every morning; `tinybot` was dead (venv gone);
  `act-runner` pointed at `127.0.0.1` while gitea binds the mesh IP only;
  `secrets-rotation` was disabled (script missing).

### Secrets env (`/home/vansh/.secrets/pi-utility-server.env`)
- Stale tailnet `DOMAIN` (`autobot.taila24d04.ts.net:8081`).
- `TRAEFIK_BASICAUTH=admin:$apr1$...` — the `$apr1` collided with compose
  interpolation and broke deploys.
- ~23 legacy keys for retired services (Grafana, MySQL, Nextcloud, Redis,
  Traefik, WireGuard, Windows stack) still present.

### Stacks / compose
- `headscale`: no `3478/udp` DERP/STUN publish; `TZ` was a literal empty
  string.
- `monitoring`: beszel images unpinned.
- `vansh-portfolio`: built from an absolute path **outside** the repo.
- CI (`.gitea/workflows/deploy.yml`): referenced the deleted repo path, the
  wrong runner label, and a missing `render-dynamic-yml.sh` — every run
  failed.

### Health checks
- Wrong assumptions: pihole probed on `:5353` (it is host-network `:53`);
  vansh-portfolio probed on `127.0.0.1:8091` (it binds the mesh IP only).

### Housekeeping
- Stray dirs `/mnt/nas/bench`, `bench2`, and `02.`; stale `.env.example`;
  ADR-007 referenced but missing; no ADR-010.

---

## 2. What changed (P0 + P1, commits `78d3c111` → `c028b85d`)

### P0 — hardening (33 files, commit `78d3c111`)
- **Real backups**: `backup.sh` streams every Docker named volume through an
  alpine tar pipe into restic (`volumes/<name>.tar`, `--compression max`),
  backs up NAS dirs + live secrets env, excludes restic repo/cache/media
  archive; env resolved via `PI_ENV_FILE`. Verified: 23 volumes covered.
- `backup-os.sh` fixed (explicit excludes, `--one-file-system`).
- `health-check.sh`, `update.sh`, `daily-health-summary.sh` rewritten to
  match the live 12-container stack.
- systemd units repointed; `tinybot` restored (venv + launcher);
  `act-runner` address fixed; `daily-summary` fixed (temp file out of
  read-only `/tmp`).
- Secrets env: `DOMAIN` fixed, `TRAEFIK_BASICAUTH` removed.
- `headscale` compose: `3478/udp` + interpolated `TZ`.
- `monitoring` pinned to `0.18.7`.
- `vansh-portfolio` source vendored into `./app`.
- Docs: ADR-007 + ADR-010 added; `.env.example` refreshed.

### P1 — follow-ups (commits `54414f1a`, `72920030`, `c028b85d`)
- **Secret rotation live**: `secrets-rotation.sh` rotates only
  `VAULTWARDEN_ADMIN_TOKEN`, recreates vaultwarden, Telegram-notifies the
  new token; Sunday 03:00 timer armed.
- **B2 offsite wired**: `backup.sh` mirrors the local repo to
  `b2:homelab-prod-backup:pi-utility-server/restic` after each run with the
  same retention — gated by `B2_ENABLED=true` (see pending).
- **CI fixed & simplified**: validate-only gitea workflow (shell syntax +
  compose config + health check) on the `pi` runner — now green. Auto-deploy
  and a pre-push gate were deliberately dropped to keep it simple.

### Verified outcome (current live state)
- **12 / 12 containers healthy** (incl. vaultwarden recreated by rotation).
- **40 restic snapshots**; last cron backup (03:00) clean: *no errors found*.
- **9 compose stacks validate** against the secrets env.
- **CI green** on the latest push; all three remotes at `c028b85d`.
- Secrets rotation timer armed for Sun 03:08.

---

## 3. What a "perfect repo" looks like (target)

1. **Single source of truth** — every service, script, unit, and doc in the
   repo matches what is actually running; zero drift.
2. **Backups you can prove** — real data (volumes, NAS, secrets) captured,
   an **offsite copy live**, and a **restore drill** that has been run and
   is documented (recovery runbook).
3. **Reproducible from the repo alone** — `docker compose up -d` per stack
   from committed config; secrets injected from an env file whose shape is
   fully documented by `.env.example`.
4. **Tested on every change** — CI validates syntax + config + health on
   push; nothing merges or mirrors while red.
5. **Hardened & clean** — images pinned to **digests**, systemd units
   verified, least-privilege, **no secrets in git**, `.env.example` current,
   and the live secrets file contains **only** keys still in use.
6. **Decisions documented** — one ADR per meaningful change; recovery
   runbook; clear dual-remote (gitea CI → GitHub mirror) workflow.

---

## 4. Remaining gaps → perfect repo

| # | Gap | Effort | Priority |
|---|-----|--------|----------|
| 1 | **B2 offsite live** — blocked: the env holds the `.env.example` placeholders (`your_b2_account_id` / `your_b2_application_key`), so B2 was never actually configured. Paste a real Backblaze app key (bucket `homelab-prod-backup`), set `B2_ENABLED=true`, then seed the offsite copy and verify `restic copy` + offsite retention | low (once creds exist) | **high** |
| ~~2~~ | ~~**Restore drill + recovery runbook**~~ — **DONE 2026-08-08**: beszel volume + secrets env restored from a snapshot to throwaway targets and verified; procedure documented in `pi/docs/restore-runbook.md` (incl. full DR scenarios A/B) | done | done |
| ~~3~~ | ~~**Prune legacy secrets**~~ — **DONE 2026-08-08**: removed 23 retired Grafana/MySQL/Nextcloud/Redis/WG/Traefik/CrowdSec/Windows keys from the live env (`/home/vansh/.secrets/pi-utility-server.env`, atomic rewrite + `.bak-20260808-134332` backup); added `B2_ENABLED=false`; verified all 9 stacks `compose config`, restic auth, and health-check (21 PASS / 0 FAIL). `.env.example` was already the clean 29-key SSOT | done | done |
| ~~4~~ | ~~**Pin images to digests**~~ — **DONE 2026-08-08**: all 8 registry images pinned to local-store digests (behaviour-preserving) with a `# pinned-from: image:tag` comment above each; `pin-images-to-digest.sh` now supports re-pinning after updates and skips `local/*` builds (still tags); `update.sh` pulls each pinned-from tag, re-pins, and auto-commits. Verified: 9 stacks `compose config` OK, pin idempotent, health-check 21 PASS / 0 FAIL | done | done |
| ~~5~~ | ~~**GitHub-side CI**~~ — **DECLINED 2026-08-08**: GitHub Actions runners cannot reach the Tailscale mesh (no public route to `100.84.60.109`), the Pi's act_runner is registered to gitea only, and a second GitHub-hosted runner would duplicate validation + add load. gitea CI validates every push; GitHub remains a mirror (manual push after CI green) | declined | low |
| ~~6~~ | ~~**Legacy volume tars**~~ — **DONE 2026-08-08**: removed 5 retired named volumes (`core_portainer_data`, `crowdsec_crowdsec_config`, `crowdsec_crowdsec_data`, `smarthome_homeassistant_config`, orphan `samba_config`) + 5 orphan anonymous volumes. Historical snapshots (archived through 08-08 11:06) retain the data under normal retention, so nothing is lost. Backup now leaner (14 volume snapshots vs ~23); new backup verified clean + repo check passed | done | done |
| 7 | **TLS for public headscale** — deferred by choice (mesh-only access) | medium | low |
| 8 | **Wider secret rotation** (pihole/samba) — intentionally not done (would lock out devices) | low | low |

---

## 5. Recommended order

1. Fix B2 credentials → seed offsite copy → verify offsite snapshots. (#1)
2. ~~Restore drill + runbook~~ — **done**.
   ~~Prune legacy keys from the live env~~ — **done 2026-08-08** (23 keys removed, verified). (#3)
3. ~~Enable digest pinning~~ — **done 2026-08-08** (8 registry images pinned; update flow keeps working). (#4)
4. ~~Lower-priority items~~ — **#5 declined** (Actions can't reach the mesh; gitea CI validates), **#6 done** (retired volumes removed, archive kept), **#7/#8 deferred by choice** (documented above).
