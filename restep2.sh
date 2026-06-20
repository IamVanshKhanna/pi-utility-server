#!/bin/bash
set -e
cd ~/pi4homelab
echo "=== Old docs -> pi/docs ==="
for f in docs/*; do
  [ -f "$f" ] && mv "$f" pi/docs/ 2>/dev/null || true
done
rmdir docs 2>/dev/null || true
echo "=== Systemd files ==="
for f in tinybot.service homelab-daily-summary.service homelab-daily-summary.timer homelab-secrets-rotation.service homelab-secrets-rotation.timer; do
  [ -f "pi/scripts/$f" ] && mv "pi/scripts/$f" pi/systemd/ || true
done
echo "=== Skeleton ==="
touch windows/.gitkeep portfolio/.gitkeep
echo "=== Stage ==="
git add -A
echo "=== Status ==="
git status --short
echo "=== Commit ==="
git commit -m "restructure: organise into pi/ + windows/ for multi-node architecture" || echo "Nothing to commit"
echo "=== DONE ==="
