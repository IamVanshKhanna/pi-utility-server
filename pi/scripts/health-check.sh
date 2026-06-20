#!/usr/bin/env bash
# health-check.sh - Verify all homelab containers are running
# Schedule: */15 * * * * /home/vansh/homelab-prod/scripts/health-check.sh >> /var/log/homelab-health.log 2>&1
# Usage: ./health-check.sh [--strict] [--quiet]

set -euo pipefail

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; NC='\033[0m'
STRICT=false
QUIET=false

for arg in "$@"; do
  case $arg in
    --strict) STRICT=true ;;
    --quiet) QUIET=true ;;
  esac
done

log() { $QUIET || echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"; }

EXPECTED_CONTAINERS=(
  traefik portainer
  prometheus grafana node-exporter cadvisor alertmanager loki promtail
  nextcloud mariadb redis vaultwarden
  pihole wireguard
  homeassistant
  uptime-kuma
  infisical infisical-db infisical-redis
  authelia authelia-redis
  crowdsec crowdsec-db
  tempo otel-collector
)

CHECK_LOKI=true
CHECK_ALERTMANAGER=true
CHECK_INFISICAL=true
CHECK_AUTHELIA=true
CHECK_CROWDSEC=true
CHECK_TEMPO=true
CHECK_OTEL=true

FAILED=0
WARNINGS=0

log "--- Homelab Health Check ---"
printf "%-22s %-12s\n" "CONTAINER" "STATUS"
printf "%-22s %-12s\n" "----------------------" "----------"

for NAME in "${EXPECTED_CONTAINERS[@]}"; do
  STATUS=$(docker inspect --format='{{.State.Status}}' "$NAME" 2>/dev/null || echo "missing")
  if [[ "$STATUS" == "running" ]]; then
    printf "${GREEN}%-22s %-12s${NC}\n" "$NAME" "$STATUS"
    # Check health status if available
    HEALTH=$(docker inspect --format='{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$NAME" 2>/dev/null || echo "unknown")
    if [[ "$HEALTH" == "unhealthy" ]]; then
      printf "${RED}  -> Health: unhealthy${NC}\n"
      FAILED=$((FAILED + 1))
    elif [[ "$HEALTH" == "starting" ]]; then
      printf "${YELLOW}  -> Health: starting${NC}\n"
      WARNINGS=$((WARNINGS + 1))
    fi
  else
    printf "${RED}%-22s %-12s${NC}\n" "$NAME" "$STATUS"
    FAILED=$((FAILED + 1))
  fi
done

TOTAL=${#EXPECTED_CONTAINERS[@]}
RUNNING=$((TOTAL - FAILED))

# Check Loki log pipeline
if $CHECK_LOKI; then
  log ""
  log "--- Loki Log Pipeline Check ---"
  if curl -sf http://localhost:3100/ready >/dev/null 2>&1; then
    LABELS=$(curl -sf "http://localhost:3100/loki/api/v1/label" | jq -r '.data | length' 2>/dev/null || echo "0")
    if [[ "$LABELS" -gt 0 ]]; then
      printf "${GREEN}Loki ready, labels: %s${NC}\n" "$LABELS"
    else
      printf "${YELLOW}Loki ready but no labels ingested yet${NC}\n"
      WARNINGS=$((WARNINGS + 1))
    fi
  else
    printf "${RED}Loki not ready${NC}\n"
    FAILED=$((FAILED + 1))
  fi
fi

# Check Alertmanager
if $CHECK_ALERTMANAGER; then
  log ""
  log "--- Alertmanager Check ---"
  if curl -sf http://localhost:9093/-/ready >/dev/null 2>&1; then
    printf "${GREEN}Alertmanager ready${NC}\n"
  else
    printf "${RED}Alertmanager not ready${NC}\n"
    FAILED=$((FAILED + 1))
  fi
fi

# Check Infisical
if $CHECK_INFISICAL; then
  log ""
  log "--- Infisical Secret Manager Check ---"
  if curl -sf http://localhost:8080/api/status >/dev/null 2>&1; then
    printf "${GREEN}Infisical reachable${NC}\n"
  else
    printf "${RED}Infisical not reachable${NC}\n"
    FAILED=$((FAILED + 1))
  fi
fi

# Check Authelia
if $CHECK_AUTHELIA; then
  log ""
  log "--- Authelia SSO Check ---"
  if curl -sf http://localhost:9091/api/healthz >/dev/null 2>&1; then
    printf "${GREEN}Authelia reachable${NC}\n"
  else
    printf "${RED}Authelia not reachable${NC}\n"
    FAILED=$((FAILED + 1))
  fi
fi

# Check CrowdSec (internal only - no host port)
if $CHECK_CROWDSEC; then
  log ""
  log "--- CrowdSec IDS Check ---"
  if docker exec crowdsec wget -qO- http://localhost:8080/health >/dev/null 2>&1; then
    printf "${GREEN}CrowdSec reachable${NC}\n"
  else
    printf "${RED}CrowdSec not reachable${NC}\n"
    FAILED=$((FAILED + 1))
  fi
fi

# Check Tempo
if $CHECK_TEMPO; then
  log ""
  log "--- Tempo Tracing Check ---"
  if curl -sf http://localhost:3200/ready >/dev/null 2>&1; then
    printf "${GREEN}Tempo reachable${NC}\n"
  else
    printf "${RED}Tempo not reachable${NC}\n"
    FAILED=$((FAILED + 1))
  fi
fi

# Check OTEL Collector
if $CHECK_OTEL; then
  log ""
  log "--- OTEL Collector Check ---"
  if curl -sf http://localhost:8888/metrics >/dev/null 2>&1; then
    printf "${GREEN}OTEL Collector reachable${NC}\n"
  else
    printf "${RED}OTEL Collector not reachable${NC}\n"
    FAILED=$((FAILED + 1))
  fi
fi

# Check Prometheus alerting
log ""
log "--- Prometheus Alerting Check ---"
ALERTING=$(curl -sf "http://localhost:9090/api/v1/query?query=ALERTING" | jq -r '.data.result | length' 2>/dev/null || echo "0")
if [[ "$ALERTING" -gt 0 ]]; then
  printf "${YELLOW}Active alerts: %s${NC}\n" "$ALERTING"
  WARNINGS=$((WARNINGS + 1))
else
  printf "${GREEN}No active alerts${NC}\n"
fi

# Check Uptime Kuma
log ""
log "--- Uptime Kuma Check ---"
if curl -sf "http://localhost:8082" >/dev/null 2>&1; then
  printf "${GREEN}Uptime Kuma responsive${NC}\n"
else
  printf "${RED}Uptime Kuma not responsive${NC}\n"
  FAILED=$((FAILED + 1))
fi

echo ""
log "Result: $RUNNING/$TOTAL containers running."
if [[ $WARNINGS -gt 0 ]]; then
  log "Warnings: $WARNINGS"
fi

if [[ $FAILED -gt 0 ]]; then
  log "ERROR: $FAILED container(s) are NOT running!"
  log "Check: docker ps -a"
  log "Logs:  docker logs <container_name>"
  exit 1
elif [[ $STRICT && $WARNINGS -gt 0 ]]; then
  log "STRICT mode: warnings treated as failures"
  exit 1
else
  log "All containers healthy."
  exit 0
fi