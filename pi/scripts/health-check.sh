#!/usr/bin/env bash
# health-check.sh - Verify the Pi server is healthy
# Checks: required containers running, pihole DNS resolves, ports reachable,
#         beszel/uptime-kuma responding. Exits non-zero on any failure.
# Usage: ./health-check.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"

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

# Required containers for a healthy server
EXPECTED_CONTAINERS=(
  unbound
  pihole
  headscale
  gitea
  vaultwarden
  samba
  syncthing
  beszel
  beszel-agent
  uptime-kuma
  portfolio
  vansh-portfolio
)

# Optional components (their absence is a warning, not a failure)
OPTIONAL_CONTAINERS=(
  act-runner
)

PASS=0
FAIL=0
WARN=0

check() {
  local status="$1" msg="$2"
  case "$status" in
    PASS)
      PASS=$((PASS + 1))
      echo "  [PASS] $msg"
      ;;
    WARN)
      WARN=$((WARN + 1))
      echo "  [WARN] $msg"
      ;;
    *)
      FAIL=$((FAIL + 1))
      echo "  [FAIL] $msg"
      ;;
  esac
}

echo "=== Health Check: $(date '+%Y-%m-%d %H:%M:%S') ==="
echo "=== Container checks ==="

RUNNING=$(docker ps --format '{{.Names}}' 2>/dev/null || true)

for container in "${EXPECTED_CONTAINERS[@]}"; do
  if echo "$RUNNING" | grep -qx "$container"; then
    check PASS "Container '$container' is running"
  else
    check FAIL "Container '$container' is NOT running"
  fi
done

for container in "${OPTIONAL_CONTAINERS[@]}"; do
  if echo "$RUNNING" | grep -qx "$container"; then
    check PASS "Optional container '$container' is running"
  else
    check WARN "Optional container '$container' is not running (acceptable if unused)"
  fi
done

echo ""
echo "=== DNS checks (via pihole @127.0.0.1, host-network port 53) ==="

if command -v dig >/dev/null 2>&1; then
  if dig +short @127.0.0.1 google.com A >/dev/null 2>&1; then
    check PASS "pihole DNS resolves google.com"
  else
    check FAIL "pihole DNS could not resolve google.com"
  fi
  if dig +short @127.0.0.1 example.com A >/dev/null 2>&1; then
    check PASS "pihole DNS resolves example.com"
  else
    check FAIL "pihole DNS could not resolve example.com"
  fi
else
  if getent hosts google.com >/dev/null 2>&1; then
    check PASS "system DNS resolves google.com"
  else
    check FAIL "system DNS could not resolve google.com"
  fi
fi

echo ""
echo "=== Web UI / service checks ==="

if curl -sf -o /dev/null --max-time 5 "http://100.84.60.109:8081/"; then
  check PASS "vaultwarden responding on :8081"
else
  check FAIL "vaultwarden not responding on :8081"
fi

if curl -sf -o /dev/null --max-time 5 "http://100.84.60.109:8082/"; then
  check PASS "uptime-kuma responding on :8082"
else
  check FAIL "uptime-kuma not responding on :8082"
fi

if curl -sf -o /dev/null --max-time 5 "http://127.0.0.1:8092/"; then
  check PASS "beszel responding on :8092"
else
  check FAIL "beszel not responding on :8092"
fi

if curl -sf -o /dev/null --max-time 5 "http://100.84.60.109:8091/"; then
  check PASS "vansh-portfolio responding on :8091"
else
  check FAIL "vansh-portfolio not responding on :8091"
fi

echo ""
echo "=== Port checks ==="

if command -v nc >/dev/null 2>&1; then
  for port in 445 8384; do
    if nc -z 127.0.0.1 "$port" >/dev/null 2>&1; then
      check PASS "port $port reachable"
    else
      check FAIL "port $port not reachable"
    fi
  done
else
  echo "  (nc not installed; skipping port checks)"
fi

echo ""
echo "=== Resource checks ==="

LOAD1=$(awk '{print $1}' /proc/loadavg)
echo "  1-minute load average: $LOAD1 (4 cores)"

DISK_PCT=$(df / | awk 'NR==2 {print $5}' | tr -d '%')
if [[ "$DISK_PCT" -gt 90 ]]; then
  check FAIL "root disk usage ${DISK_PCT}% (over 90%)"
elif [[ "$DISK_PCT" -gt 80 ]]; then
  check WARN "root disk usage ${DISK_PCT}% (over 80%)"
else
  check PASS "root disk usage ${DISK_PCT}%"
fi

echo ""
echo "=== Summary ==="
echo "  PASS: $PASS"
echo "  FAIL: $FAIL"
echo "  WARN: $WARN"

if [[ $FAIL -gt 0 ]]; then
  echo ""
  echo "Health check FAILED with $FAIL error(s)"
  exit 1
else
  echo ""
  echo "Health check PASSED"
  exit 0
fi
