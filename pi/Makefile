# Homelab Makefile (Pi node)
# Usage: make <target>
#
# Note: secrets, auth, tracing stacks run on Windows only.
# Pi stacks: core, network, monitoring, apps, smarthome, uptime-kuma, crowdsec, nas, portfolio

.PHONY: help up-core up-network up-monitoring up-apps up-smarthome up-uptime up-crowdsec up-nas up-portfolio up-all down-core down-network down-monitoring down-apps down-smarthome down-uptime down-crowdsec down-nas down-portfolio down-all ps logs verify-v1 verify-health verify-crowdsec verify-uptime verify-backup backup config

up-core:
	docker compose -f stacks/core/docker-compose.yml up -d

up-network:
	docker compose -f stacks/network/docker-compose.yml up -d

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

up-nas:
	docker compose -f stacks/nas/docker-compose.yml up -d

up-portfolio:
	docker compose -f stacks/portfolio/docker-compose.yml up -d

up-all: up-core up-network up-monitoring up-apps up-smarthome up-uptime up-crowdsec up-nas up-portfolio
	@echo "All Pi stacks deployed"

down-core:
	docker compose -f stacks/core/docker-compose.yml down

down-network:
	docker compose -f stacks/network/docker-compose.yml down

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

down-nas:
	docker compose -f stacks/nas/docker-compose.yml down

down-portfolio:
	docker compose -f stacks/portfolio/docker-compose.yml down

down-all: down-portfolio down-nas down-crowdsec down-uptime down-smarthome down-apps down-monitoring down-network down-core
	@echo "All Pi stacks stopped"

ps:
	docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

logs:
	docker compose -f stacks/core/docker-compose.yml \
		-f stacks/network/docker-compose.yml \
		-f stacks/monitoring/docker-compose.yml \
		-f stacks/apps/docker-compose.yml \
		-f stacks/smarthome/docker-compose.yml \
		-f stacks/uptime-kuma/docker-compose.yml \
		-f stacks/crowdsec/docker-compose.yml \
		-f stacks/nas/docker-compose.yml \
		-f stacks/portfolio/docker-compose.yml \
		logs -f --tail=100

# Verification
verify-v1: verify-health verify-crowdsec verify-uptime verify-backup
	@echo "All verification checks passed"

verify-health:
	./scripts/health-check.sh --strict

verify-crowdsec:
	@echo "Checking CrowdSec..."
	@docker exec crowdsec wget -qO- http://localhost:8080/health >/dev/null 2>&1 || (echo "CrowdSec not ready"; exit 1)
	@echo "CrowdSec reachable"

verify-uptime:
	@echo "Checking Uptime Kuma..."
	@curl -sf http://localhost:8082 >/dev/null || (echo "Uptime Kuma not responsive"; exit 1)
	@echo "Uptime Kuma reachable"

verify-backup:
	@echo "Checking backup repository..."
	@RESTIC_REPOSITORY=$$(grep RESTIC_REPOSITORY ../.env | cut -d= -f2) && \
	RESTIC_PASSWORD=$$(grep RESTIC_PASSWORD ../.env | cut -d= -f2) && \
	export RESTIC_REPOSITORY RESTIC_PASSWORD && \
	restic snapshots --latest 1 | grep -q "snapshot" || (echo "No recent snapshot"; exit 1)
	@echo "Recent snapshot exists"

backup:
	./scripts/backup.sh

config:
	docker compose -f stacks/core/docker-compose.yml config >/dev/null && \
	docker compose -f stacks/network/docker-compose.yml config >/dev/null && \
	docker compose -f stacks/monitoring/docker-compose.yml config >/dev/null && \
	docker compose -f stacks/apps/docker-compose.yml config >/dev/null && \
	docker compose -f stacks/smarthome/docker-compose.yml config >/dev/null && \
	docker compose -f stacks/uptime-kuma/docker-compose.yml config >/dev/null && \
	docker compose -f stacks/crowdsec/docker-compose.yml config >/dev/null && \
	docker compose -f stacks/nas/docker-compose.yml config >/dev/null && \
	docker compose -f stacks/portfolio/docker-compose.yml config >/dev/null && \
	echo "All compose files valid"

help:
	@echo "Pi Stacks:"
	@echo "  up-core, up-network, up-monitoring, up-apps, up-smarthome, up-uptime, up-crowdsec, up-nas, up-portfolio"
	@echo "  up-all"
	@echo "  down-core, down-network, down-monitoring, down-apps, down-smarthome, down-uptime, down-crowdsec, down-nas, down-portfolio, down-all"
	@echo "  ps, logs"
	@echo "  verify-v1, verify-health, verify-crowdsec, verify-uptime, verify-backup"
	@echo "  backup, config, help"
	@echo ""
	@echo "Note: secrets (Infisical), auth (Authelia), tracing (Tempo) run on Windows only."

.DEFAULT_GOAL := help
