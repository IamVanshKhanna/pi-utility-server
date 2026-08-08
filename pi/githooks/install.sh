#!/usr/bin/env bash
# Install gitea CI gate hooks into the live repo.
set -uo pipefail
REPO='/mnt/nas/02. shared/01. PI Files/01. pi-utility-server'
install -m 755 "$REPO/pi/githooks/pre-push" "$REPO/.git/hooks/pre-push"
echo "installed pre-push hook"
