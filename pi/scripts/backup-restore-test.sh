#!/usr/bin/env bash
# backup-restore-test.sh - Prove that restic backups are actually restorable.
#
# Restores one small file from the latest snapshot to a temp dir, compares it
# byte-for-byte with the copy read straight from the repository, and reports
# PASS/FAIL. Safe to run any time; touches nothing outside a temp dir.
#
# Usage:
#   PI_ENV_FILE=/path/to/pi-utility-server.env pi/scripts/backup-restore-test.sh [report.md]
# If report.md is given, a result section is appended to that evidence report.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
REPORT="${1:-}"

# Load env (same discovery as health-check.sh)
if [[ -n "${PI_ENV_FILE:-}" ]]; then
  ENV_FILE="$PI_ENV_FILE"
elif [[ -f "${ROOT_DIR}/.env" ]]; then
  ENV_FILE="${ROOT_DIR}/.env"
elif [[ -f /home/vansh/.secrets/pi-utility-server.env ]]; then
  ENV_FILE=/home/vansh/.secrets/pi-utility-server.env
elif [[ -f "${ROOT_DIR}/pi/.env" ]]; then
  ENV_FILE="${ROOT_DIR}/pi/.env"
else
  ENV_FILE=""
fi
if [[ -n "$ENV_FILE" ]]; then
  while IFS='=' read -r key val; do
    [[ -z "$key" || "$key" == \#* ]] && continue
    val="${val#\"}" val="${val%\"}"
    val="${val#\'}" val="${val%\'}"
    export "$key=$val"
  done < "$ENV_FILE"
fi

fail() { echo "FAIL: $1" >&2; exit 1; }

command -v restic >/dev/null 2>&1 || fail "restic not installed"
[[ -n "${RESTIC_REPOSITORY:-}" ]] || fail "RESTIC_REPOSITORY not set"

SNAP=$(restic snapshots --json | python3 -c "import json,sys; s=json.load(sys.stdin); print(s[-1]['id'] if s else '')")
[[ -n "$SNAP" ]] || fail "no snapshots found"

# Pick a small text config file from the snapshot
FILE=$(restic ls "$SNAP" | grep -E '\.(ya?ml|json|conf|toml|md|sh)$' | head -1 || true)
[[ -n "$FILE" ]] || fail "no suitable file found in snapshot $SNAP"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

restic dump "$SNAP" "$FILE" > "$TMP/direct" 2>/dev/null || fail "restic dump failed"
restic restore "$SNAP" --target "$TMP/restore" --include "$FILE" >/dev/null 2>&1 || fail "restic restore failed"
RESTORED=$(find "$TMP/restore" -type f | head -1)
[[ -n "$RESTORED" ]] || fail "restored file not found"

if cmp -s "$TMP/direct" "$RESTORED"; then
  RESULT="PASS"
  DETAIL="restored file matches repository copy byte-for-byte"
else
  RESULT="FAIL"
  DETAIL="restored file differs from repository copy"
fi

echo "Backup restore test: $RESULT ($DETAIL; snapshot ${SNAP:0:8}, file: $FILE)"

if [[ -n "$REPORT" ]]; then
  {
    echo
    echo "## Backup restore test"
    echo
    echo "- Result: **$RESULT** ($DETAIL)"
    echo "- Snapshot: ${SNAP:0:8} ($(restic snapshots --json | python3 -c "import json,sys; s=json.load(sys.stdin); print(s[-1]['time'])"))"
    echo "- Verified file: \`$FILE\`"
  } >> "$REPORT"
  echo "Appended to $REPORT"
fi

[[ "$RESULT" == "PASS" ]]
