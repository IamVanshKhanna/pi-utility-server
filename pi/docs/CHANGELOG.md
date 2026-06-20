# Changelog — homelab-prod

> All notable changes. Follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

---

## [v1.7.0] — 2026-06-19

### Added
- **Infisical secrets stack** — PostgreSQL + Redis + Infisical (replaces .env files)
- **NAS foundation** — Nextcloud external storage mount point at `${DATA_DIR}/nextcloud/userdata`
- **TinyBot Telegram agent** — Health, search, chat, status, clear commands
- **Local-first architecture** — Removed K3s, ArgoCD, multi-cluster, AWS/GKE, Thanos, Linkerd

### Changed
- **Apps stack** — Removed Ollama (2GB RAM savings), kept Nextcloud, MariaDB, Redis, Vaultwarden
- **Memory budget** — Reduced from ~3.6 GB to ~2.5 GB with healthy headroom on 4GB Pi
- **PROJECT_SUMMARY.md** — Rewritten for single Pi, Docker Compose only
- **Makefile** — Added `up-secrets`, `verify-secrets`, fixed health check endpoints

### Removed
- `stacks/ollama-cluster/` (K8s manifests)
- `infra/argocd/`, `infra/cluster-api/`, `infra/thanos/`, `infra/submariner/`, `infra/litmus/`, `infra/kyverno/` (moved to infra/ but not used)
- v2.x roadmap (K3s, multi-cluster, cloud DR, AI/ML platform)

### Fixed
- Health check endpoints (Uptime Kuma on 8082, CrowdSec internal, Authelia API)

---

## [v2.12.1] — 2026-06-13

### Added
- **Pi-hole Prometheus exporter** (`ekofr/pihole-exporter:v1.0.1`) with proxy network + host-gateway for Prometheus metrics collection
- **test-deploy.sh** — Post-deployment smoke test script covering 23 containers, 9 HTTP endpoints, 5 direct ports, and Prometheus target validation
- Pre/post-update health-checks and backup trigger in `scripts/update.sh`

### Changed
- **Nextcloud**: Pinned from `:stable` to `nextcloud:30.0.5` (version policy compliance)
- **Home Assistant**: Pinned from `:stable` to `homeassistant/home-assistant:2025.12.0` (version policy compliance)
- **WireGuard**: Updated from `linuxserver/wireguard:1.0.20210914` (Sep 2021) to `linuxserver/wireguard:1.0.20250514` (May 2025)
- `update.sh`: Added 4 missing stacks (auth, crowdsec, tracing, uptime-kuma) + pre/post-update safety checks

### Fixed
- **Prometheus**: Pi-hole scrape target now points to `pihole-exporter:9617` with working exporter service
- **ARCHITECTURE.md**: Data persistence path corrected from `/opt/homelab/data/` to `/mnt/data/` (matching .env.example)
- **CONTRIBUTING.md**: Clone URL fixed from `VK7160/pi4b-homelab` to `IamVanshKhanna/homelab-prod`
- **SETUP_GUIDE.md**: Tailscale hostname updated to `AutoBot` (matching Pi hostname)

### Upgraded From v2.12
| File | Change |
|------|--------|
| stacks/network/docker-compose.yml | Added pihole-exporter service, updated WireGuard tag |
| stacks/apps/docker-compose.yml | Pinned Nextcloud to `nextcloud:30.0.5` |
| stacks/smarthome/docker-compose.yml | Pinned HA to `homeassistant/home-assistant:2025.12.0` |
| config/prometheus/prometheus.yml | Added pihole-exporter scrape job |
| scripts/update.sh | Added 4 stacks, pre/post-update safety |
| scripts/test-deploy.sh | New: 23-container smoke test |
| docs/ARCHITECTURE.md | Fixed data path |
| docs/SETUP_GUIDE.md | Fixed hostname reference |
| CONTRIBUTING.md | Fixed clone URL |

---

## [v2.10.0] — 2026-06-09

### Added
- **Resource Quotas & Limits** — 4-tier quotas (P0-P3) across 12 namespaces with ResourceQuota + LimitRange (29 YAML files)
- **Spot Instance Integration** — EKS Spot node group (t3.medium, capacity-optimized) with 70% cost savings, PDBs, termination handler
- **Right-Sizing Automation** — Weekly VPA + Prometheus analysis with GitHub Actions workflow (10%+ savings detection)
- **Unused Resource Detection** — 8-category scanner (PVCs, Secrets, Services, Ingresses, NetworkPolicies, HPAs, Roles, LBs) with PR creation
- **Cost Allocation & Chargeback** — Weekly allocation by namespace/team/service with configurable rates, GitHub Actions report
- **Power/Electricity Optimization** — Pi CPU governor/frequency limits, LED/WiFi/BT disable, USB/storage/network power mgmt, Grafana dashboard, Prometheus alerts
- **Backup Encryption Verification** — Weekly Restic/Velero/B2 AES-256 verification via GitHub Actions
- **Cross-Region Backup Replication** — Restic rclone (B2→S3/GCS), Velero BSL replication, S3 CRR, GCS dual-region
- **DR Automation** — Monthly DR test, quarterly failover, automated DNS failover (Cloudflare), Velero cross-region restore
- **Ansible DR Runbooks** — Failover, monthly test, Velero operations, full DR failover playbooks
- **Ansible Resource Quotas** — 29 quota/limit manifests with Kustomize
- **Spot Instance Patches** — 7 workload patches with tolerations/affinity for DR spot nodes

### Changed
- **helmfile.yaml** — Added Velero, EKS Spot nodes, updated repositories
- **supply-chain.yml** — Enhanced Trivy gate to block HIGH in production
- **renovate.json** — Enhanced severity-based PR grouping (patch/minor/major/security)

### Fixed
- **VERSION_ROADMAP.md** — Updated v2.10 status to completed

---

## [v2.9.0] — 2026-06-09
### Added
- **DR Monthly Test** — `scripts/dr-test-monthly.sh` with critical services restore validation
- **DR Quarterly Failover** — `scripts/dr-failover.sh` with Cloudflare DNS failover + Velero restore
- **DR Documentation** — `docs/disaster-recovery-secondary-region.md` with RTO/RPO matrix
- **Incident Drills** — `scripts/drills/incident-response-drill.sh` with 8 scenarios
- **Service Failover Drill** — `scripts/drills/service-failover-drill.sh` per-service testing
- **Ansible DR Playbooks** — Failover, monthly test, Velero operations playbooks
- **Loki Multi-Tenancy** — Central Loki with per-cluster Promtail (homelab-pi4, homelab-pi5)
- **Thanos Federation** — Sidecar, Query, Store Gateway, Compactor, Ruler with B2/S3 objstore

### Changed
- **helmfile.yaml** — Added Thanos, Loki, ArgoCD ApplicationSet releases
- **VERSION_ROADMAP.md** — Updated v2.9 status to completed

---

## [v2.8.0] — 2026-06-09
### Added
- **Cluster API (CAPI)** — Pi 4B (Docker) + Pi 5 (Metal3) cluster definitions with Kustomize
- **Thanos Federation** — Sidecar, Query, Store Gateway, Compactor, Ruler with B2 objstore
- **Loki Multi-Tenancy** — Central Loki + per-cluster Promtail (tenant_id: homelab-pi4/pi5)
- **Submariner** — Cross-cluster service discovery (broker, 2 clusters, 12 ServiceExports)
- **ArgoCD ApplicationSet** — 6 generators (cluster, git, matrix) with sync windows/waves
- **LitmusChaos** — 7 experiments (pod delete, CPU/mem hog, network latency/loss, node drain, disk fill)
- **NetworkPolicies** — Complete deny/allow for all 14 namespaces with kustomize

### Changed
- **helmfile.yaml** — Added Thanos, Litmus, Submariner, ArgoCD ApplicationSet repos/releases

---

## [v2.7.0] — 2026-06-09
### Added
- **PostgreSQL Optimization** — Patroni config with shared_buffers=1GB, parallel workers, wal_compression
- **Redis Optimization** — LFU eviction, AOF everysec, active defrag, diskless sync
- **Cloudflare CDN** — Workers (security headers, cache logic), Page Rules, WAF, Rate Limiting, Terraform
- **Traefik Compression** — Brotli/Zstd/Gzip middleware with content-type targeting
- **Cache Warming** — CronJob (15m), Nextcloud/Vaultwarden/HA static assets, PG/Redis prewarm
- **Performance Benchmarks** — PgBench, redis-benchmark, k6, vegeta, iperf3, fio templates

### Changed
- **helmfile.yaml** — Added Loki repo + Loki + Promtail (Pi4/Pi5) releases

---

## [v2.6.0] — 2026-06-09
### Added
- **Ansible Runbooks** — 8 playbooks (backup, restore, health-check, rotate-secrets, update-certs, scale-workload, DR, site)
- **LitmusChaos** — 7 chaos experiments + Argo workflows + RBAC + NetworkPolicies
- **Capacity Planning** — Python analyzer (Prometheus forecasting), weekly workflow, Grafana dashboard
- **Incident Response Drills** — Monthly/quarterly scripts + GitHub Actions + Ansible playbooks

### Changed
- **helmfile.yaml** — Added Litmus, ArgoCD ApplicationSet controller

---

## [v2.5.0] — 2026-06-09
### Added
- **Kyverno Policies** — 13 policies (digest pinning, no :latest, resource limits, non-root, read-only rootfs, no host NS, capabilities, labels, network policies, PrometheusRule validation, ExternalSecret validation, PDB enforcement)
- **NetworkPolicies** — Complete deny/allow for all 14 namespaces (kyverno, portainer, linkerd, litmus, databases, external-dns, etc.)
- **Linkerd mTLS** — Helmfile values, ArgoCD apps, NetworkPolicies, documentation
- **Secrets Rotation** — Script, systemd timer, GitHub Actions workflow

### Changed
- **helmfile.yaml** — Added Kyverno, Linkerd (crds, control-plane, viz) releases

---

## [v2.4.0] — 2026-06-09
### Added
- **Supply Chain Maturity** — Syft SBOM, Cosign keyless signing, Trivy HIGH gate, Renovate severity grouping
- **Dependency Policy** — Comprehensive doc with SLAs, exceptions, emergency override
- **SBOM Generation** — All sources (compose, K8s, Helmfile, ArgoCD) + base images
- **Cosign Signing** — Keyless OIDC, SBOM attestations
- **Trivy Gate** — Block CRITICAL, scan HIGH (warn), SARIF upload

### Changed
- **supply-chain.yml** — Enhanced with base image SBOM, base image signing, HIGH warning, Renovate gate
- **renovate.json** — Severity-based grouping (patch/minor/major/security-critical)
- **DEPENDENCY_POLICY.md** — Updated with v2.4 enhancements

---

## [v2.3.0] — 2026-06-09
### Added
- **Logging + Tracing + GitOps** — Loki+Promtail, Tempo+OTEL, 28 ArgoCD apps, Helmfile
- **Correlation IDs** — Go/Python middleware, Promtail extraction, distributed tracing
- **SLO/SLI** — Definitions, burn rate alerting, error budget dashboard
- **Distributed Tracing Sampling** — Probabilistic (10%), trace-based (errors 100%)
- **Log Retention** — Loki 30d hot / 365d cold
- **ArgoCD ApplicationSet** — 28 apps + AppProject

---

## [v2.2.0] — 2026-06-09
### Added
- **Multi-Node Ready** — K3s cluster setup, NetworkPolicies, Patroni PostgreSQL, Redis Cluster, Longhorn
- **External PostgreSQL/Redis** — Patroni 3-replica HA, Redis Cluster 3-replica
- **Longhorn/Ceph** — Distributed storage evaluation

---

## [v2.1.0] — 2026-06-09
### Added
- **Tempo + OpenTelemetry** — Distributed tracing with OTEL Collector
- **Cronjob Operations** — Daily health summary, weekly backup verify, weekly report
- **TTS Alerts** — Text-to-speech for critical alerts (edge-tts, espeak)

---

## [v1.7.0] — 2026-06-09
### Added
- **K3s Multi-node Cluster** — Automated bootstrap with Longhorn, Cert-Manager, Prometheus, Loki, Tempo
- **Ollama Cluster** — 7 K8s manifests + Helm values (HPA, PDB, security contexts)
- **GPU Offload** — Documentation for CUDA/VideoCore/Vulkan

---

## [v1.6.0] — 2026-06-09
### Added
- **Tempo + OTEL Collector** — Distributed tracing stack
- **Cronjob/TTS Skills** — New Hermes skills for automation and TTS alerts

---

## [v1.5.0] — 2026-06-09
### Added
- **Supply Chain Security** — Syft SBOM, Cosign keyless signing, Trivy gate (CRITICAL block)

---

## [v1.4.0] — 2026-06-09
### Added
- **Authelia SSO** — Redis + Authelia, Traefik ForwardAuth on all external
- **Cloudflare DNS-01** — ACME DNS-01, port 80 closed
- **CrowdSec** — PostgreSQL + CrowdSec IDS
- **Runbooks** — Service Down, Backup Failure, Security Incident

---

## [v1.3.0] — 2026-06-09
### Added
- **3 Hermes Skills** — backup-ops, security-audit, capacity-plan
- **ADR-005** — Hermes Skills Architecture (trust model)

---

## [v1.2.0] — 2026-06-09
### Added
- **Infisical Secret Manager** — PostgreSQL 16 + Redis 7 + Infisical 1.7.1
- **Backup Restore Test** — Automated verify + restore-test.sh

---

## [v1.1.0] — 2026-06-09
### Added
- **Loki + Promtail** — Centralized logging
- **Alertmanager + Telegram** — Alerting with receivers
- **Uptime Kuma** — External monitoring
- **ZRAM 2GB** — Swap configuration

---

## [v1.0.0] — 2026-06-09
### Added
- Core: Traefik, Portainer, Pi-hole, Tailscale
- Monitoring: Prometheus, Grafana, Node Exporter, cAdvisor
- Apps: Nextcloud, Vaultwarden, Ollama (gemma:2b)
- Smarthome: Home Assistant
- Hermes Agent (headless) + skills
- Restic → B2 backup
- ZRAM 2GB swap
- 3 ADRs (orchestration, network, memory)
- Architecture diagram (SVG)
- Demo transcript
- GitHub Actions: compose-validate, trivy-scan, backup-test
- Renovate config

---

## Template for Future Releases

```markdown
## [vX.Y.Z] — YYYY-MM-DD
### Added
- Feature/service with brief description
### Changed
- Modification to existing behavior
### Deprecated
- Soon-to-be-removed feature
### Removed
- Deleted feature
### Fixed
- Bug fix with issue reference
### Security
- Vulnerability addressed or hardening
```