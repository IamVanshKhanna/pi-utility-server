# Homelab Makefile
# Usage: make <target>

.PHONY: help up-core up-network up-secrets up-auth up-monitoring up-apps up-smarthome up-uptime up-crowdsec up-tracing up-nas up-all down-core down-network down-secrets down-auth down-monitoring down-apps down-smarthome down-uptime down-crowdsec down-tracing down-nas down-all ps logs verify-v1 verify-health verify-loki verify-alertmanager verify-uptime verify-secrets verify-auth verify-crowdsec verify-tracing verify-backup backup restore restore-test config

# Core stack dependencies
up-core:
	docker compose -f stacks/core/docker-compose.yml up -d

up-network:
	docker compose -f stacks/network/docker-compose.yml up -d

up-secrets:
	docker compose -f stacks/secrets/docker-compose.yml up -d

up-auth:
	docker compose -f stacks/auth/docker-compose.yml up -d

up-monitoring:
	docker compose -f stacks/monitoring/docker-compose.yml up -d

up-apps:
	docker compose -f stacks/apps/docker-compose.yml up -d

up-smarthome:
	docker compose -f stacks/smarthome/docker-compose.yml up -d

up-uptime:
	docker compose -f stacks/uptime-kuma/docker-compose.yml up -d

up-crowdsec:
	docker compose -f stacks/crowdsec/docker-compose.yml up -d

up-tracing:
	docker compose -f stacks/tracing/docker-compose.yml up -d

up-nas:
	docker compose -f stacks/nas/docker-compose.yml up -d

# Phased deploy per verification plan (v1.6)
up-phase1: up-core up-network
	@echo "Phase 1 done: core + network"

up-phase2: up-secrets
	@echo "Phase 2 done: secrets (Infisical)"

up-phase3: up-auth
	@echo "Phase 3 done: auth (Authelia)"

up-phase4: up-monitoring
	@echo "Phase 4 done: monitoring"

up-phase5: up-apps
	@echo "Phase 5 done: apps"

up-phase6: up-smarthome
	@echo "Phase 6 done: smarthome"

up-phase7: up-uptime
	@echo "Phase 7 done: uptime-kuma"

up-phase8: up-crowdsec
	@echo "Phase 8 done: crowdsec"

up-phase9: up-tracing
	@echo "Phase 9 done: tracing (Tempo + OTEL)"

up-phase10: up-nas
	@echo "Phase 10 done: NAS (Samba + NFS)"

up-all: up-phase1 up-phase2 up-phase3 up-phase4 up-phase5 up-phase6 up-phase7 up-phase8 up-phase9 up-phase10
	@echo "All stacks deployed"

# Down commands
down-core:
	docker compose -f stacks/core/docker-compose.yml down

down-network:
	docker compose -f stacks/network/docker-compose.yml down

down-secrets:
	docker compose -f stacks/secrets/docker-compose.yml down

down-auth:
	docker compose -f stacks/auth/docker-compose.yml down

down-monitoring:
	docker compose -f stacks/monitoring/docker-compose.yml down

down-apps:
	docker compose -f stacks/apps/docker-compose.yml down

down-smarthome:
	docker compose -f stacks/smarthome/docker-compose.yml down

down-uptime:
	docker compose -f stacks/uptime-kuma/docker-compose.yml down

down-crowdsec:
	docker compose -f stacks/crowdsec/docker-compose.yml down

down-tracing:
	docker compose -f stacks/tracing/docker-compose.yml down

down-nas:
	docker compose -f stacks/nas/docker-compose.yml down

down-all: down-nas down-tracing down-crowdsec down-uptime down-smarthome down-apps down-auth down-monitoring down-secrets down-network down-core

# Status & logs
ps:
	docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

logs:
	docker compose -f stacks/core/docker-compose.yml -f stacks/network/docker-compose.yml \
		-f stacks/secrets/docker-compose.yml -f stacks/auth/docker-compose.yml \
		-f stacks/monitoring/docker-compose.yml -f stacks/apps/docker-compose.yml \
		-f stacks/smarthome/docker-compose.yml -f stacks/uptime-kuma/docker-compose.yml \
		-f stacks/crowdsec/docker-compose.yml -f stacks/tracing/docker-compose.yml \
		-f stacks/nas/docker-compose.yml \
		logs -f --tail=100

# Verification (v1.6)
verify-v1: verify-health verify-loki verify-alertmanager verify-uptime verify-secrets verify-auth verify-crowdsec verify-tracing verify-backup
	@echo "All v1.6 verification checks passed"

verify-health:
	./scripts/health-check.sh --strict

verify-loki:
	@echo "Checking Loki log pipeline..."
	@curl -sf http://localhost:3100/ready >/dev/null || (echo "Loki not ready"; exit 1)
	@LABELS=$$(curl -sf "http://localhost:3100/loki/api/v1/label" | jq -r '.data | length' 2>/dev/null || echo "0"); \
	if [ "$$LABELS" -gt 0 ]; then echo "Loki labels: $$LABELS"; else echo "No labels ingested"; exit 1; fi

verify-alertmanager:
	@echo "Checking Alertmanager..."
	@curl -sf http://localhost:9093/-/ready >/dev/null || (echo "Alertmanager not ready"; exit 1)

verify-uptime:
	@echo "Checking Uptime Kuma..."
	@curl -sf http://localhost:8082 >/dev/null || (echo "Uptime Kuma not responsive"; exit 1)

verify-secrets:
	@echo "Checking Infisical secret manager..."
	@curl -sf http://localhost:8080/api/status >/dev/null 2>&1 || (echo "Infisical not ready"; exit 1)
	@echo "Infisical reachable"

verify-auth:
	@echo "Checking Authelia..."
	@curl -sf http://localhost:9091/api/healthz >/dev/null 2>&1 || (echo "Authelia not ready"; exit 1)
	@echo "Authelia reachable"

verify-crowdsec:
	@echo "Checking CrowdSec..."
	@docker exec crowdsec wget -qO- http://localhost:8080/health >/dev/null 2>&1 || (echo "CrowdSec not ready"; exit 1)
	@echo "CrowdSec reachable"

verify-tracing:
	@echo "Checking Tempo tracing..."
	@curl -sf http://localhost:3200/ready >/dev/null 2>&1 || (echo "Tempo not ready"; exit 1)
	@echo "Tempo reachable"
	@echo "Checking OTEL Collector..."
	@curl -sf http://localhost:8888/metrics >/dev/null 2>&1 || (echo "OTEL Collector not ready"; exit 1)
	@echo "OTEL Collector reachable"

verify-backup:
	@echo "Checking backup repository..."
	@source .env && export RESTIC_REPOSITORY RESTIC_PASSWORD B2_ACCOUNT_ID B2_ACCOUNT_KEY && \
	restic -r "$$RESTIC_REPOSITORY" snapshots --latest 1 | grep -q "snapshot" || (echo "No recent snapshot"; exit 1)
	@echo "Recent snapshot exists"

# Backup & restore
backup:
	./scripts/backup.sh

restore:
	@echo "Usage: make restore SNAPSHOT=<snapshot-id>"
	@restic -r $$RESTIC_REPOSITORY restore $$SNAPSHOT --target /mnt/restore-test

restore-test:
	./scripts/restore-test.sh

# Config validation
config:
	docker compose -f stacks/core/docker-compose.yml config >/dev/null && \
	docker compose -f stacks/network/docker-compose.yml config >/dev/null && \
	docker compose -f stacks/secrets/docker-compose.yml config >/dev/null && \
	docker compose -f stacks/auth/docker-compose.yml config >/dev/null && \
	docker compose -f stacks/monitoring/docker-compose.yml config >/dev/null && \
	docker compose -f stacks/apps/docker-compose.yml config >/dev/null && \
	docker compose -f stacks/smarthome/docker-compose.yml config >/dev/null && \
	docker compose -f stacks/uptime-kuma/docker-compose.yml config >/dev/null && \
	docker compose -f stacks/crowdsec/docker-compose.yml config >/dev/null && \
	docker compose -f stacks/tracing/docker-compose.yml config >/dev/null && \
	docker compose -f stacks/nas/docker-compose.yml config >/dev/null && \
	echo "All compose files valid"

help:
	@echo "Available targets:"
	@echo "  up-core, up-network, up-secrets, up-auth, up-monitoring, up-apps, up-smarthome, up-uptime, up-crowdsec, up-tracing, up-nas"
	@echo "  up-phase1, up-phase2, up-phase3, up-phase4, up-phase5, up-phase6, up-phase7, up-phase8, up-phase9, up-phase10"
	@echo "  up-all"
	@echo "  down-core, down-network, down-secrets, down-auth, down-monitoring, down-apps, down-smarthome, down-uptime, down-crowdsec, down-tracing, down-nas, down-all"
	@echo "  ps, logs"
	@echo "  verify-v1, verify-health, verify-loki, verify-alertmanager, verify-uptime, verify-secrets, verify-auth, verify-crowdsec, verify-tracing, verify-backup"
	@echo "  backup, restore, restore-test"
	@echo "  config, help"

.DEFAULT_GOAL := help