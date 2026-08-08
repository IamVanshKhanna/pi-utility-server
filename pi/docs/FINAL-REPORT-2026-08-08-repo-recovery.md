# FINAL REPORT — Homelab Pi `pi-utility-server` Repo Recovery

**Date:** 2026-08-08 | **Status:** COMPLETE | **Host:** AutoBot (Raspberry Pi) | **Repo branch:** `main`

---

## 1. Executive summary

The `pi-utility-server` homelab repo — the source of truth for all 9 Docker
Compose stacks, backup/health/rotation scripts, systemd units, and CI — was
recovered end-to-end. All services are running, backups are real and
verified, CI is green on every push, secrets rotate automatically, and a
disaster-recovery runbook (with a passing restore drill) is committed to the
repo. The repo is in sync across three remotes (local → gitea → GitHub) at
`03671ba0`, with a clean git tree and zero failing checks.

The only item **not** completed is an offsite (B2 cloud) backup copy, which
was deliberately **skipped by user decision for cost**. Its implication is
documented: the recovery runbook's "Scenario B (Pi + NAS both lost)" is not
recoverable.

---

## 2. What was done

### 2.1 Baseline hardening (P0) — commit `78d3c111`
- **Real volume backups**: all Docker named volumes are now streamed into
  restic via `alpine` tar pipes (direct access to `/var/lib/docker/volumes`
  is root-only), replacing the previous ineffective approach.
- **Fixed scripts**: `backup.sh`, `backup-os.sh`, `health-check.sh`,
  `update.sh`, `daily-health-summary.sh` corrected and re-pointed in their
  systemd/cron units.
- **Restored services**: tinybot (Telegram bot) and the act-runner (gitea CI
  runner) brought back.
- **Env fixes**: `DOMAIN` corrected; `TRAEFIK_BASICAUTH` removed (Traefik is
  retired); headscale `3478/udp` exposed; beszel pinned to `0.18.7`;
  `vansh-portfolio` vendored into the repo.
- **Docs**: ADR-007 and ADR-010 added.

### 2.2 Recovery follow-ups (P1) — commit `54414f1a`
- **Secrets rotation live**: `secrets-rotation.sh` rotates
  `VAULTWARDEN_ADMIN_TOKEN` weekly (systemd timer, Sun 03:08), rewrites the
  env atomically, recreates vaultwarden, and notifies Telegram. Verified
  end-to-end.
- **B2 offsite wired** into `backup.sh`, gated by `B2_ENABLED=true` + valid
  credentials (later skipped — see §5).
- **CI workflow** rewritten (validate-only) and fixed through `72920030` +
  `c028b85d`: runner label is `pi` (the `.runner` label `pi:host` never
  matches), and the unquoted `cd` into a path with spaces was the CI failure.

### 2.3 Documentation & DR (commits `cd676f6f`, `619770f3`)
- **Recovery report** (`REPORT-2026-08-08-repo-recovery.md`) — baseline vs
  current vs "perfect repo", with a tracked gap list.
- **Restore drill PASSED**: the beszel volume was restored from snapshot
  `ae12092f` into a throwaway volume (file structure identical) and the
  secrets env was restored from `0d8bc867` (49/49 keys).
- **DR runbook** (`restore-runbook.md`) — inventory, snapshot map,
  quick-restore commands, full scenarios A (Pi dead / NAS intact) and B
  (Pi + NAS both lost), verification checklist, gotchas.

### 2.4 Secrets hygiene (commit `dea8e9e1`)
- Analyzed every `${VAR}` reference in compose files + scripts; **removed 23
  legacy keys** for retired services (Grafana, MySQL, Nextcloud, Redis,
  WireGuard, Traefik, CrowdSec, Windows stack) from the live env.
- `.env.example` is the clean 29-key source of truth; no secrets are tracked
  in git (all `.env*` gitignored).
- Verified: all 9 stacks `compose config`, restic auth, health-check
  (21 PASS / 0 FAIL).

### 2.5 Image digest pinning (commit `dc97d5cc`)
- All **8 registry images** pinned to their local-store digests, each with a
  `# pinned-from: image:tag` comment.
- `pin-images-to-digest.sh` rewritten: idempotent re-pin after pulls,
  skips `local/*` builds and floating tags.
- `update.sh` updated: pulls the latest tag for each pinned-from ref,
  re-pins the compose files, auto-commits, then recreates stacks.
- `local/samba` and `local/unbound` stay tags (built from version-controlled
  Dockerfiles).

### 2.6 Backup bloat cleanup (commit `9fd7bac2`)
- Removed 5 retired named volumes (`core_portainer_data`,
  `crowdsec_crowdsec_config`, `crowdsec_crowdsec_data`,
  `smarthome_homeassistant_config`, orphan `samba_config`) + 5 orphan
  anonymous volumes. Historical snapshots keep the data under normal
  retention.
- Backup is now leaner (14 volume snapshots vs ~23); verified clean.

---

## 3. Final state

| Area | State |
|---|---|
| Git remotes | local, gitea (`100.84.60.109:8087/vansh`), GitHub (`IamVanshKhanna/pi-utility-server`) — all at `03671ba0` |
| CI | gitea Actions, validate-only (shell syntax → compose config → health-check), `runs-on: pi`; runs 56–64 all **success** |
| Containers | 12 running (gitea, pihole, samba, syncthing, unbound, uptime-kuma, portfolio, vaultwarden, beszel(+agent), headscale, vansh-portfolio) |
| Health-check | 21 PASS / 0 FAIL / 1 WARN |
| Backups | restic @ `/mnt/nas/backup/restic-repo`; nightly cron 03:00; retention 7 daily / 4 weekly / 6 monthly; repo check clean |
| Volume snapshots | 14 per backup (all current stacks + anonymous mounts of running containers) |
| Secrets rotation | weekly Sun 03:08 (vaultwarden admin token); atomic env rewrite + Telegram |
| Digest pinning | 8/8 registry images pinned |
| DR | runbook + passing restore drill committed |
| Stacks | 9: headscale, network (pihole/unbound), gitops (gitea/act-runner), apps (vaultwarden), nas (samba/syncthing), monitoring (beszel), uptime-kuma, portfolio, vansh-portfolio |

### Versions (pinned)
gitea `1.26.4-rootless` · headscale `v0.29.1` · beszel(+agent) `0.18.7` ·
uptime-kuma `1.23.9` · pihole `2026.07.2` · syncthing `2.1.1` ·
vaultwarden `1.32.0` · samba/unbound = local builds.

### Key commits (newest first)
```
03671ba0  docs: B2 offsite skipped (cost decision) — report, runbook, ADR-010
303dedfa  docs: clarify B2 blocker is placeholder creds, not a 401
9fd7bac2  docs: legacy volumes cleanup done; GitHub CI declined
dc97d5cc  chore: pin images to digests; update.sh re-pins + auto-commits
dea8e9e1  docs: legacy secrets pruning done (23 keys removed)
619770f3  docs: restore drill + DR runbook
cd676f6f  docs: repo recovery report
c028b85d  ops: simplify CI — validate-only workflow
54414f1a  ops: P1 — B2 offsite (gated), secrets rotation live, CI workflow
78d3c111  ops: P0 hardening — real volume backups, fixed scripts/units
```

---

## 4. Verification results

| Check | Result |
|---|---|
| `docker compose config` × 9 stacks | OK (after prune + pinning) |
| `health-check.sh` | 21 PASS / 0 FAIL |
| Restore drill (volume + env) | PASSED |
| restic `check` | no errors |
| CI runs 56–64 | all success |
| Legacy secrets removal | 23 keys; 9/9 stacks still valid |
| Backup after volume cleanup | clean, 14 volume snapshots |

---

## 5. Decisions made (and skipped items)

| Item | Decision |
|---|---|
| **B2 offsite backup** | **Skipped** (cost, user decision). No cloud copy exists; runbook Scenario B is not recoverable. Can be enabled later: bucket + app key + `B2_ENABLED=true`. |
| GitHub Actions parity | Declined — GitHub runners can't reach the Tailscale mesh; gitea CI validates every push; GitHub is a manual mirror. |
| TLS for public headscale | Deferred by choice (mesh-only access). |
| Wider secret rotation (pihole/samba) | Intentionally not done — would lock out devices. |
| Headscale TLS | Skipped — mesh-only accepted. |

---

## 6. Outstanding risks & notes

1. **`RESTIC_PASSWORD` is irrecoverable if lost** — it lives only inside the
   encrypted env file. **Keep a copy in your password manager.** This is the
   one value no restore can recover.
2. **No offsite copy** — the only restic repo is on the NAS, same box as the
   data. If Pi + NAS are lost together, backups are gone with them.
3. Health-check reports **1 WARN** (expected — non-critical item).
4. Legacy volume data is archived in snapshots through 2026-08-08 11:06, then
   drops out under normal retention.
5. vansh-portfolio auto-redeploys on update (cron, every 15 min).

---

## 7. How to operate

```bash
# backup (nightly cron 03:00; manual)
PI_ENV_FILE=/home/vansh/.secrets/pi-utility-server.env \
  /mnt/nas/02. shared/01. PI Files/01. pi-utility-server/pi/scripts/backup.sh

# update all stacks (weekly; pulls pinned-from tags, re-pins, recreates)
PI_ENV_FILE=/home/vansh/.secrets/pi-utility-server.env \
  .../pi/scripts/update.sh

# health check
bash .../pi/scripts/health-check.sh

# rotate vaultwarden admin token (weekly Sun 03:08, manual)
bash .../pi/scripts/secrets-rotation.sh

# re-pin images after any manual pull
bash .../pi/scripts/pin-images-to-digest.sh

# restore: follow pi/docs/restore-runbook.md
```

---

## 8. Deliverables

- `pi/docs/REPORT-2026-08-08-repo-recovery.md` — baseline vs current vs perfect-repo, gap tracking
- `pi/docs/FINAL-REPORT-2026-08-08-repo-recovery.md` — this document
- `pi/docs/restore-runbook.md` — DR runbook (scenarios A/B, gotchas)
- ADRs: `ADR-004` (secrets), `ADR-007`, `ADR-010` (consolidation/hardening)
- Scripts: `backup.sh`, `backup-os.sh`, `health-check.sh`, `update.sh`,
  `daily-health-summary.sh`, `secrets-rotation.sh`, `pin-images-to-digest.sh`
- CI: `.gitea/workflows/deploy.yml` (validate-only)
