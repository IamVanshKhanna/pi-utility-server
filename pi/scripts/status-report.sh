#!/usr/bin/env bash
# status-report.sh - Produce a shareable, non-sensitive evidence report that
# the Pi utility server is running and healthy.
#
# The report contains container status, health-check results, disk usage and
# backup recency. It never prints secrets, env values or full IP addresses,
# so the Markdown file is safe to share (e.g. with a recruiter).
#
# Usage:
#   pi/scripts/status-report.sh [output.md]
# Default output: evidence/verification-<date>.md

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
OUT="${1:-${ROOT_DIR}/evidence/verification-$(date +%F).md}"
mkdir -p "$(dirname "$OUT")"

redact_ip() { sed -E 's/([0-9]{1,3}\.){3}[0-9]{1,3}/<ip>/g'; }

{
  echo "# Pi Utility Server - Verification Report"
  echo
  echo "- Date: $(date -u '+%Y-%m-%d %H:%M UTC')"
  echo "- Kernel: $(uname -srmo)"
  echo "- Uptime: $(uptime -p 2>/dev/null || uptime)"
  echo "- Docker: $(docker --version 2>/dev/null || echo 'not found')"
  echo
  echo "## Containers"
  echo
  echo '| Name | Status |'
  echo '|---|---|'
  docker ps --format '| {{.Names}} | {{.Status}} |' 2>/dev/null | sort || echo 'docker ps failed'
  echo
  echo "## Health check"
  echo
  if "${SCRIPT_DIR}/health-check.sh" > /tmp/status-report-health.log 2>&1; then
    echo "health-check.sh: PASS"
  else
    echo "health-check.sh: FAIL"
  fi
  echo
  echo '```'
  redact_ip < /tmp/status-report-health.log
  echo '```'
  echo
  echo "## Disk usage"
  echo
  echo '```'
  df -h / "${DATA_DIR:-/}" "${BACKUP_DIR:-/}" 2>/dev/null | awk 'NR==1 || !seen[$1]++'
  echo '```'
  echo
  echo "## Backups (restic)"
  echo
  if command -v restic >/dev/null 2>&1 && [[ -n "${RESTIC_REPOSITORY:-}" ]]; then
    SNAPS=$(restic snapshots --json 2>/dev/null || echo '[]')
    echo "$SNAPS" | python3 -c "
import json,sys
try:
    snaps=json.load(sys.stdin)
except Exception:
    snaps=[]
print(f'- Snapshots: {len(snaps)}')
if snaps:
    print(f'- Latest: {snaps[-1][\"time\"]}')"
  else
    echo "restic not configured in this environment - skipped"
  fi
} > "$OUT"

echo "Report written to $OUT"
cat "$OUT"
