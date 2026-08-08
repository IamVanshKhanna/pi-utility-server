# Restore & Disaster Recovery Runbook (autobot-1)

Validated 2026-08-08 by a restore drill (beszel volume + secrets env restored
to throwaway targets, contents verified).

## 1. Inventory

| Item | Location |
|---|---|
| Repo (GitHub) | `https://github.com/IamVanshKhanna/pi-utility-server.git` |
| Repo (gitea) | `http://100.84.60.109:8087/vansh/pi-utility-server.git` |
| Repo (live copy) | `/mnt/nas/02. shared/01. PI Files/01. pi-utility-server` |
| Secrets env | `/home/vansh/.secrets/pi-utility-server.env` (mode 600) |
| Restic repo | `/mnt/nas/backup/restic-repo` (`RESTIC_REPOSITORY`) |
| Restic cache | `/mnt/nas/02. shared/02. Pi_ServiceData/restic-cache` |
| Restic binary | `/home/vansh/bin/restic` (0.17.x, not on PATH) |
| Offsite (B2) — **not set up** | skipped 2026-08-08 (cost); no cloud copy exists |
| Containers / stacks | 12 healthy containers / 9 stacks in `pi/stacks/*` |

**Critical:** `RESTIC_PASSWORD` lives inside the encrypted env file. The backup
is useless without it — **keep a copy in your password manager**. This is the
one value no restore can recover for you.

## 2. What the backups contain

- One **main snapshot** every day 03:00 (tag `auto-<date>`, `hostname-AutoBot`):
  repo config/stacks/scripts/docs, NAS user dirs (`/mnt/nas/01. sync`,
  `02. shared`, `04. media`), and the live secrets env.
- One **snapshot per docker volume** (tag `volume-<name>`, path
  `volumes/<name>.tar`): a tar stream of that volume.
- Retention: 7 daily / 4 weekly / 6 monthly. The restic repo + cache + logs
  are excluded from themselves.

## 3. Quick reference commands

All commands assume the env is loaded (`PI_ENV_FILE=/home/vansh/.secrets/pi-utility-server.env`).

List snapshots:
```bash
export RESTIC_REPOSITORY RESTIC_PASSWORD RESTIC_CACHE_DIR   # from env
~/bin/restic snapshots
~/bin/restic snapshots --tag volume-beszel_data --latest 1  # one volume
~/bin/restic snapshots --path /home/vansh/.secrets/pi-utility-server.env --latest 1
```

### Restore a NAS path
```bash
~/bin/restic restore <snap> --target /mnt/nas --include "/mnt/nas/01. sync"
```
(Quote paths containing spaces — `--include` takes the exact path string.)

### Restore a docker volume (named volume `<name>`, e.g. `apps_vaultwarden_data`)
```bash
VOL_SNAP=$(~/bin/restic snapshots --json --tag volume-<name> --latest 1 \
  | python3 -c 'import sys,json;print(json.load(sys.stdin)[-1]["short_id"])')
# stop the owning stack first so nothing writes while restoring
cd "pi/stacks/<stack>"
docker compose --env-file /home/vansh/.secrets/pi-utility-server.env stop
# unpack the tar stream into the volume
~/bin/restic dump "$VOL_SNAP" volumes/<name>.tar \
  | docker run --rm -i -v <name>:/data alpine:3.24 tar -C /data -xf -
docker compose --env-file /home/vansh/.secrets/pi-utility-server.env up -d
```
If the volume does not exist yet, `docker volume create <name>` first.

### Restore the secrets env
```bash
ENV_SNAP=$(~/bin/restic snapshots --json --path /home/vansh/.secrets/pi-utility-server.env --latest 1 \
  | python3 -c 'import sys,json;print(json.load(sys.stdin)[-1]["short_id"])')
~/bin/restic dump "$ENV_SNAP" /home/vansh/.secrets/pi-utility-server.env \
  > /home/vansh/.secrets/pi-utility-server.env
chmod 600 /home/vansh/.secrets/pi-utility-server.env
# restart services that need it: vaultwarden, and redeploy stacks via pi/scripts/update.sh
```

### Restore the repo
```bash
git clone https://github.com/IamVanshKhanna/pi-utility-server.git \
  "/mnt/nas/02. shared/01. PI Files/01. pi-utility-server"
```
(Or `restic restore <snap> --target / --include "/mnt/nas/02. shared/01. PI Files/01. pi-utility-server"`.)

## 4. Full disaster recovery

### Scenario A — Pi dead, NAS intact
1. Install Raspberry Pi OS Lite (64-bit), user `vansh`, SSH key, sudo.
2. Install: `docker` + compose plugin, `git`, `curl`, `openssl`; add `vansh` to
   the `docker` group.
3. Mount the NAS (`/mnt/nas`; add fstab entry) and verify the paths above exist.
4. Clone the repo (section 3). Add both remotes (`github`, `gitea`).
5. Install restic: download the arm64 release to `~/bin/restic`, `chmod +x`.
6. Recover `RESTIC_PASSWORD` from the password manager, then restore the
   secrets env (section 3). `RESTIC_REPOSITORY`/`RESTIC_CACHE_DIR` are known
   paths from this runbook.
7. Create the volumes and restore data:
   ```bash
   cd "pi/stacks/<stack>"; docker compose --env-file <env> up -d --no-start   # creates named volumes
   ```
   then unpack each `volume-<name>` snapshot into its volume (section 3).
8. Start everything: `PI_ENV_FILE=... bash pi/scripts/update.sh`.
9. Restore systemd units: copy `pi/systemd/*.service|*.timer` to
   `~/.config/systemd/user/`, `systemctl --user daemon-reload`, re-enable
   timers (daily-summary, secrets-rotation); re-add the 03:00 cron entry for
   `backup.sh`.
10. Verify: `bash pi/scripts/health-check.sh` and `docker ps` (12 healthy).

### Scenario B — Pi and NAS both lost
**Not currently covered.** The B2 offsite feature is deliberately not configured
(skipped 2026-08-08 — cost). The only restic copy lives on the NAS
(`/mnt/nas/backup/restic-repo`) — same box as the data — so if Pi **and** NAS
are lost together, there is no backup left to restore.

To make this scenario recoverable later: create a Backblaze bucket + app key,
set `B2_ENABLED=true` plus `B2_ACCOUNT_ID` / `B2_ACCOUNT_KEY` /
`B2_REPOSITORY` in the secrets env, and run `backup.sh` once to seed the
offsite copy. Recovery would then be:
```bash
export B2_ACCOUNT_ID B2_ACCOUNT_KEY RESTIC_PASSWORD
~/bin/restic -r b2:homelab-prod-backup:pi-utility-server/restic snapshots
~/bin/restic -r b2:homelab-prod-backup:pi-utility-server/restic restore latest --target /mnt/nas
```
then continue from Scenario A step 4.

## 5. Verification checklist (after any restore)
- [ ] `docker ps` shows 12 containers, healthy.
- [ ] `bash pi/scripts/health-check.sh` exits 0.
- [ ] Spot-check one volume and the env file content.
- [ ] `~/bin/restic snapshots` shows the expected count (~40).

## 6. Gotchas
- Paths with spaces must be quoted in **every** context (compose, cron,
  units, restic `--include`).
- `restic dump` streams a single file; docker volumes are stored as tar
  streams (`volumes/<name>.tar`).
- Restoring the env from an old snapshot can revert `VAULTWARDEN_ADMIN_TOKEN`
  to a rotated-out value (rotation is weekly, backups daily) — rotate again
  after a restore.
- The daily-summary unit uses `ProtectSystem=strict`; `/tmp` is read-only
  there. The rotation unit deliberately omits it (needs the docker socket).
- Keep `RESTIC_PASSWORD` in a password manager.
