#!/bin/bash
# Pulls the portfolio build-context clone; rebuilds+redeploys the container
# only when the pull actually moved HEAD. Idempotent - safe to run hourly.
# ponytail: no lock file - a single low-frequency cron entry is its own
# concurrency guard; add flock if this ever moves to a sub-minute interval.
set -euo pipefail

REPO_CLONE="/mnt/nas/02. shared/01. PI Files/vansh-portfolio"
COMPOSE_DIR="/mnt/nas/02. shared/01. PI Files/01. pi-utility-server/pi/stacks/vansh-portfolio"
LOG="$COMPOSE_DIR/redeploy.log"

log() { echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) $1" >> "$LOG"; }

# Never hang a cron job waiting on an interactive credential prompt - fail
# fast and loud instead so the log shows exactly why nothing redeployed.
export GIT_TERMINAL_PROMPT=0

cd "$REPO_CLONE"
BEFORE=$(git -c safe.directory="$REPO_CLONE" rev-parse HEAD)

if ! git -c safe.directory="$REPO_CLONE" pull origin main >> "$LOG" 2>&1; then
    log "git pull FAILED (see above) - likely missing cached credentials on this host. Skipping rebuild."
    exit 1
fi

AFTER=$(git -c safe.directory="$REPO_CLONE" rev-parse HEAD)

if [ "$BEFORE" = "$AFTER" ]; then
    log "no change ($AFTER) - skip rebuild"
    exit 0
fi

log "updated $BEFORE -> $AFTER - rebuilding"
cd "$COMPOSE_DIR"
docker compose up -d --build >> "$LOG" 2>&1
log "rebuild done"
