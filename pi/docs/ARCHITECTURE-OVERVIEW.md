# homelab-prod Architecture Documentation

## Overview

homelab-prod is a production-grade, multi-cluster homelab infrastructure running on Raspberry Pi 4B/5 hardware with cloud DR capabilities. Built with GitOps principles, it provides a complete self-hosted platform with enterprise-grade observability, security, and disaster recovery.

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                              homelab-prod Architecture                               │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                      │
│  ┌──────────────────┐     ┌──────────────────┐     ┌──────────────────┐            │
│  │   Primary Site   │     │   Cloud DR       │     │   Management     │            │
│  │  (Pi 4B/5 Cluster)│────▶│   (EKS/GKE)      │     │   Workstation    │            │
│  │                  │     │                  │     │                  │            │
│  │ ┌──────────────┐ │     │ ┌──────────────┐ │     │   ┌──────────┐ │            │
│  │ │ Pi 4B (Control)│ │     │ │ EKS Cluster  │ │     │   │  GitOps  │ │            │
│  │ │ Pi 5 (Worker)  │ │     │ │ Spot Nodes   │ │     │   │  (ArgoCD)│ │            │
│  │ │ Pi 5 (Worker)  │ │     │ │ Velero DR    │ │     │   └──────────┘ │            │
│  │ └──────────────┘ │     │ └──────────────┘ │     │          │     │            │
│  └────────┬─────────┘     └────────┬─────────┘     └──────────────┘            │
│           │                        │                                        │
│           ▼                        ▼                                        │
│  ┌─────────────────────────────────────────────────────────────────────────┐ │
│  │                    Cross-Cluster Connectivity (Submariner)               │ │
│  └─────────────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

## Cluster Topology

### Primary Cluster (homelab-pi4)

| Node | Role | Hardware | OS | Purpose |
|------|------|----------|-----|---------|
| pi4-ctrl | Control Plane | Pi 4B 8GB | Raspberry Pi OS Lite | K3s control plane, etcd |
| pi5-w1 | Worker | Pi 5 8GB | Raspberry Pi OS Lite | Workloads (apps, monitoring) |
| pi5-w2 | Worker | Pi 5 8GB | Raspberry Pi OS Lite | Workloads (databases, AI) |

### Cloud DR Cluster (homelab-dr)

| Component | Configuration |
|-----------|---------------|
| Platform | AWS EKS (us-west-2) |
| Control Plane | EKS Managed |
| Workers | Spot instances (t3.medium) - 3-10 nodes |
| Storage | EBS gp3, S3 for Velero |
| Networking | VPC with private subnets, NAT Gateway |

### Management Cluster (Optional)

| Component | Configuration |
|-----------|---------------|
| Platform | k3s on workstation or dedicated Pi |
| Purpose | CAPI management, ArgoCD, Thanos Query |

## Network Architecture

### IP Addressing

| Network | CIDR | Purpose |
|---------|------|---------|
| Primary LAN | 192.168.1.0/24 | Pi cluster management |
| Pod CIDR | 10.42.0.0/16 | K3s pod network |
| Service CIDR | 10.43.0.0/16 | K3s service network |
| DR VPC | 10.0.0.0/16 | EKS cluster |
| DR Pods | 10.42.0.0/16 | EKS pod network |
| DR Services | 10.43.0.0/16 | EKS service network |
| Globalnet | 242.0.0.0/8 | Submariner global IPs |

### DNS & Ingress

| Layer | Technology | Configuration |
|-------|------------|---------------|
| External DNS | Cloudflare | Automatic DNS via External-DNS |
| Ingress Controller | Traefik v3 | TLS termination, mTLS via Linkerd |
| Internal DNS | CoreDNS + External-DNS | Cluster.local + homelab.local |
| TLS | Cert-Manager + Let's Encrypt | DNS-01 challenge only (port 80 closed) |
| Service Mesh | Linkerd | mTLS, traffic split, observability |

### Cross-Cluster Connectivity

| Technology | Purpose | Configuration |
|------------|---------|---------------|
| Submariner | Cross-cluster networking | Cable driver, Globalnet (242.0.0.0/8) |
| Lighthouse | Service discovery | DNS-based (clusterset.local) |
| ServiceExport/Import | Service sharing | 12 critical services exported |

## Storage Architecture

### Primary Cluster Storage

| Layer | Technology | Configuration |
|-------|------------|---------------|
| Block | Longhorn | 3 replicas, 2GB reserve, backup to B2 |
| Object | MinIO (optional) | S3-compatible for backups |
| Local | NVMe SSD | 2TB per Pi 5 node |

### Cloud DR Storage

| Layer | Technology | Configuration |
|-------|------------|---------------|
| Block | AWS EBS gp3 | 3000 IOPS, encrypted |
| Object | AWS S3 | Versioned, cross-region replication |
| Velero | S3 | Daily backups, 30-day retention |

### Backup Strategy

| Method | Schedule | Retention | Target |
|--------|----------|-----------|--------|
| Restic | Daily 2AM | 30 daily, 12 monthly, 5 yearly | /mnt/data, /etc/k8s, gitops |
| Velero | Every 6h | 72h | All cluster resources |
| DR Verify | Weekly Sun 5AM | 24h | Critical namespaces restore test |

## Compute Architecture

### Workload Distribution

| Tier | Namespaces | Workloads | Compute Profile |
|------|------------|-----------|-----------------|
| **P0 Critical** | apps, databases, secrets, auth, monitoring | Nextcloud, Vaultwarden, PostgreSQL, Redis, Prometheus, Grafana | Guaranteed resources, on-demand nodes |
| **P1 Important** | smarthome, logging, tracing, security, uptime | Home Assistant, Loki, Tempo, CrowdSec, Uptime Kuma | Moderate resources, spot-eligible |
| **P2 Standard** | tracing, security (additional) | Tempo (additional), Kyverno | Standard limits, spot-eligible |
| **P3 Optional** | ai, litmus | Ollama, LitmusChaos | Minimal limits, spot-only |

### Resource Quotas by Tier

| Tier | CPU Limit | Memory Limit | Storage | Pods |
|------|-----------|--------------|---------|------|
| P0 | 4 cores | 8 GiB | 100 GiB | 50 |
| P1 | 2 cores | 4 GiB | 50 GiB | 30 |
| P2 | 1 core | 2 GiB | 20 GiB | 20 |
| P3 | 500m | 1 GiB | 10 GiB | 10 |

### Cloud DR Spot Integration

| Component | Configuration |
|-----------|---------------|
| Node Group | EKS Spot (capacity-optimized) |
| Instance Types | t3.medium, t3.large, t2.medium, t3a.medium |
| Labels | `lifecycle=spot`, `workload=spot-tolerant` |
| Taints | `dedicated=spot:NoSchedule` |
| Workloads | Vaultwarden, Grafana, Loki, Tempo, Prometheus, Home Assistant |
| Savings | ~70% vs on-demand |

## Observability Stack

### Metrics (Thanos Federation)

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│  Cluster 1  │     │  Cluster 2  │     │  Cluster N  │
│ Prometheus  │     │ Prometheus  │     │ Prometheus  │
│ + Sidecar   │     │ + Sidecar   │     │ + Sidecar   │
└──────┬──────┘     └──────┬──────┘     └──────┬──────┘
       │                   │                   │
       ▼                   ▼                   ▼
┌─────────────────────────────────────────────────────────┐
│                    Thanos Query (Global)                 │
│  Deduplication │ Downsampling │ Global Query │ HA       │
└─────────────────────┬───────────────────────────────────┘
                      ▼
┌─────────────────────────────────────────────────────────┐
│                     Grafana (Single Pane)                │
└─────────────────────────────────────────────────────────┘
```

### Logging (Loki Multi-Tenancy)

| Component | Configuration |
|-----------|---------------|
| Central Loki | Multi-tenant, auth_enabled, S3 storage |
| Per-Cluster Promtail | tenant_id per cluster (homelab-pi4, homelab-pi5) |
| Retention | 30 days (hot), 365 days (cold via S3) |
| Queries | Tenant-isolated via X-Scope-OrgID header |

### Tracing (Tempo)

| Component | Configuration |
|-----------|---------------|
| Tempo | Single-binary, S3 backend, 30-day retention |
| OTEL Collector | DaemonSet + Gateway, batch processor |
| Sampling | Probabilistic (10%), trace-based (errors 100%) |
| Correlation | W3C TraceContext, baggage propagation |

### Metrics Collection

| Component | Scrape Interval | Retention |
|-----------|-----------------|-----------|
| Prometheus (per cluster) | 30s | 30d local |
| Thanos Compact | N/A | 5m:180d, 1h:0d |
| Node Exporter | 30s | 30d |
| kube-state-metrics | 30s | 30d |
| Cadvisor | 30s | 7d |

## Security Architecture

### Zero Trust Network

| Layer | Technology | Policy |
|-------|------------|--------|
| Network | Calico + NetworkPolicies | Default deny, explicit allow |
| Service Mesh | Linkerd | mTLS (mandatory), authz policies |
| Ingress | Traefik + AuthMiddleware | Authelia ForwardAuth on all external |
| Egress | Egress NetworkPolicies | Default deny, explicit allow |

### Identity & Access

| Layer | Technology | Configuration |
|-------|------------|---------------|
| SSO | Authelia | OIDC, TOTP, WebAuthn |
| Authorization | Authelia + Traefik | Group-based (admin, family, services) |
| Secrets | Infisual | PostgreSQL + Redis backend, audit log |
| Certificates | Cert-Manager | DNS-01 (Cloudflare), 90-day certs |
| mTLS | Linkerd | Automatic, rotated every 24h |

### Admission Control

| Policy | Tool | Enforcement |
|--------|------|-------------|
| Digest pinning | Kyverno | Enforce |
| No :latest tags | Kyverno | Enforce |
| Resource limits | Kyverno | Enforce |
| Non-root containers | Kyverno | Enforce |
| Read-only rootfs | Kyverno | Enforce |
| No host namespaces | Kyverno | Enforce |
| Capability dropping | Kyverno | Enforce |
| Network policies | Kyverno + Calico | Audit → Enforce |

### Supply Chain Security

| Control | Tool | Implementation |
|---------|------|----------------|
| SBOM | Syft | SPDX-JSON per image, per build |
| Signing | Cosign | Keyless (OIDC), GitHub Actions |
| Vulnerability Scan | Trivy | Block CRITICAL, warn HIGH |
| Dependency Policy | Renovate + custom | Group PRs, auto-merge patch/minor |
| Base Image Policy | Custom | Approved registries only |

## GitOps & Deployment

### ArgoCD Architecture

```
┌─────────────────┐
│   ArgoCD        │  (Management Cluster)
│  ApplicationSet │
│   Controllers   │
└────────┬────────┘
         │
    ┌────┴────┐
    ▼         ▼
┌─────────┐ ┌─────────┐
│Cluster 1│ │Cluster N│
│(Agent)  │ │(Agent)  │
└─────────┘ └─────────┘
```

### ApplicationSet Generators

| Generator | Pattern | Use Case |
|-----------|---------|----------|
| Cluster | All clusters | Cluster addons (monitoring, networking) |
| Git Directory | config/argocd/services/* | Per-service deployment |
| Matrix | Cluster × Service | Service mesh, databases |
| PR | Pull requests | Preview environments |

### Sync Policies

| Tier | Sync Policy | Sync Window |
|------|-------------|-------------|
| Core (Traefik, Cert-Manager) | Automated, Prune, Self-Heal | Anytime |
| Platform (Monitoring, Logging) | Automated, Prune, Self-Heal | Weekly Sun 2-6 AM |
| Applications | Automated, Prune, Self-Heal | Weekly Sun 2-6 AM |
| Production | Manual | Manual approval |

## Disaster Recovery

### RTO/RPO Targets

| Tier | Services | RTO | RPO | Strategy |
|------|----------|-----|-----|----------|
| P0 | Nextcloud, Vaultwarden, DBs, Auth | 4h | 6h | Warm standby + Velero |
| P1 | Home Assistant, Auth, Secrets | 12h | 12h | Velero + ArgoCD |
| P2 | Monitoring, Logging, Tracing | 24h | 24h | Velero |
| P3 | Chaos, Benchmarks | 72h | 72h | Scheduled restore |

### DR Automation

| Component | Automation |
|-----------|------------|
| DNS Failover | Cloudflare API (60s TTL) |
| Velero Restore | Automated via GitHub Actions |
| Health Checks | 8 critical services verified |
| Failback | Automated with data sync |

### Backup Locations

| Data | Primary | Secondary | Tertiary |
|------|---------|-----------|----------|
| Restic (files) | B2 us-east-1 | S3 us-west-2 | GCS us-central1 |
| Velero (K8s) | B2 us-east-1 | S3 us-west-2 | GCS dual-region |
| Velero DR | S3 us-west-2 | - | - |
| Velero Replication | S3 CRR (15min RPO) | - | - |

## Cost Optimization

### Resource Management

| Control | Implementation |
|---------|----------------|
| Quotas | Per-namespace ResourceQuota + LimitRange |
| Right-Sizing | Weekly VPA + Prometheus analysis (10%+ savings) |
| Unused Detection | Weekly scan (8 categories, PR creation) |
| Spot Instances | DR cluster (70% savings) |
| Power Management | Pi CPU scaling, peripheral disable |

### Cost Allocation

| Dimension | Method |
|-----------|--------|
| Namespace | Prometheus metrics (CPU, Mem, Storage, LB) |
| Team | Namespace → Team mapping |
| Service | Namespace service mapping |
| Chargeback | Weekly report, PR with allocation |

### Cost Rates (Monthly)

| Resource | Rate | Source |
|----------|------|--------|
| CPU Core | $30.00 | Cloud equivalent |
| Memory (GiB) | $4.00 | Cloud equivalent |
| Storage (GiB) | $0.10 | Longhorn/Cloud |
| Load Balancer | $22.00 | AWS NLB equivalent |
| Electricity (Pi) | $0.15/kWh | Local utility |

## Deployment Pipeline

### CI/CD Flow

```
┌─────────┐    ┌─────────┐    ┌─────────┐    ┌─────────┐
│  Code   │───▶│  Build  │───▶│  Scan   │───▶│  Deploy │
│  Push   │    │  Image  │    │ (Trivy) │    │ (ArgoCD)│
└─────────┘    └─────────┘    └─────────┘    └─────────┘
                    │              │              │
                    ▼              ▼              ▼
              Syft SBOM       Trivy Scan      ArgoCD Sync
              Cosign Sign     Cosign Verify   Health Checks
```

### Quality Gates

| Gate | Tool | Threshold |
|------|------|-----------|
| Lint | golangci-lint / hadolint | Zero warnings |
| Unit Test | go test / pytest | >80% coverage |
| SAST | Trivy | No CRITICAL |
| Container Scan | Trivy | No CRITICAL |
| SBOM | Syft | Generated per image |
| Signing | Cosign | Keyless (OIDC) |
| Dependency | Renovate | Auto-merge patch/minor |

## Operational Procedures

### Routine Maintenance

| Task | Frequency | Automation |
|------|-----------|------------|
| OS Updates | Weekly | Unattended-upgrades |
| Cert Renewal | 60 days | Cert-Manager |
| Velero Backup | Daily 2AM | CronJob |
| DR Test | Monthly | GitHub Actions |
| Full DR Failover | Quarterly | Manual + Script |
| Right-Sizing | Weekly | GitHub Actions |
| Unused Resources | Weekly | GitHub Actions |
| Cost Report | Weekly | GitHub Actions |
| Cert Renewal Check | Daily | Cert-Manager |
| Power Optimization | Hourly | Systemd Timer |

### Incident Response

| Severity | Response Time | Escalation |
|----------|---------------|------------|
| Critical (P0) | 15 min | Page + Telegram |
| Warning (P1) | 1 hour | Telegram |
| Info (P2) | 4 hours | Telegram |

### Runbooks

| Scenario | Runbook |
|----------|---------|
| Service Down | `docs/runbooks/service-down.md` |
| Backup Failure | `docs/runbooks/backup-failure.md` |
| Security Incident | `docs/runbooks/security-incident.md` |
| DR Failover | `docs/runbooks/dr-failover.md` |
| DR Failback | `docs/runbooks/dr-failback.md` |

## Monitoring & Alerting

### Key SLIs

| SLI | Target | Measurement |
|-----|--------|-------------|
| Availability | 99.9% | Uptime Kuma + Prometheus |
| Latency (p95) | <500ms | Prometheus histogram |
| Error Rate | <0.1% | Prometheus counter |
| Durability | 99.999999999% | Velero + Restic verify |

### Critical Alerts

| Alert | Condition | Severity |
|-------|-----------|----------|
| ClusterDown | up{job="prometheus"} == 0 | Critical |
| ServiceDown | kube_deployment_status_replicas_available < spec.replicas | Critical |
| DiskSpaceCritical | disk_usage > 90% | Critical |
| MemoryPressure | memory_working_set > 90% limit | Warning |
| CPUThrottling | cpu_freq_cur < 0.8 * max | Warning |
| CertExpiring | cert_expiry < 30d | Warning |
| BackupFailed | velero_backup_status != Completed | Critical |
| DRTestFailed | dr_test_status != Passed | Critical |

## Future Roadmap

### v2.11 (Documentation) - Current
- [x] Architecture documentation
- [x] README update
- [ ] Runbooks for new components
- [ ] CHANGELOG v2.10
- [ ] Operational guides
- [ ] VERSION_ROADMAP update

### v2.12+ (Planned)
- [ ] Advanced GitOps (Image updater, PR preview)
- [ ] Policy as Code (OPA/Gatekeeper)
- [ ] Advanced cost optimization (Kubecost)
- [ ] Multi-region active-active
- [ ] Advanced chaos engineering

### v3.0 - AI/ML Platform (6+ months)

| Milestone | Target | Components |
|-----------|--------|------------|
| **M1: Ollama Cluster** | Month 2 | Multi-node GPU inference, model registry |
| **M2: RAG Pipeline** | Month 3 | Qdrant, BGE embeddings, retrieval API |
| **M3: Fine-tuning** | Month 4 | LoRA/QLoRA, dataset versioning, model registry |
| **M4: Inference API** | Month 5 | OpenAI-compatible, streaming, rate limits |
| **M5: MLOps** | Month 6 | MLflow, model CI/CD, experiment tracking |

---

*Architecture Version: 2.10*
*Last Updated: 2024-06-09*
*Maintained by: Platform Team*