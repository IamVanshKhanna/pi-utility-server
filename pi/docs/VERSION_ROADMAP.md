# Version Roadmap — homelab-prod

> Living document. Updated each release.

---

## Versioning Scheme
- **Major** (v1, v2): Architectural shifts, breaking changes, new stacks
- **Minor** (v1.1, v1.2): New services, features, non-breaking improvements
- **Patch** (v1.0.1): Bug fixes, dependency updates, doc corrections

---

## v1.x — Baseline (Current: v1.7 ✅ Done)

| Version | Focus | Target | Timeline (2-week sprints) | Estimated Date | Status |
|---------|-------|--------|---------------------------|----------------|--------|
| **v1.0** | Production baseline | 2 weeks (Sprint 1) | 2026-06-09 | 2026-06-09 | ✅ **Released** |
| **v1.1** | Observability hardening | 2 weeks (Sprint 2) | 2026-06-23 | 2026-06-09 | ✅ **Released** |
| **v1.2** | Secrets + backup automation | 2 weeks (Sprint 3) | 2026-07-07 | 2026-06-09 | ✅ **Released** |
| **v1.3** | Hermes agent expansion | 2 weeks (Sprint 4) | 2026-07-21 | 2026-06-09 | ✅ **Released** |
| **v1.4** | Security + compliance | 2 weeks (Sprint 5) | 2026-08-04 | 2026-06-09 | ✅ **Released** |
| **v1.5** | Supply chain hardening | 2 weeks (Sprint 6) | 2026-08-18 | 2026-06-09 | ✅ **Released** |
| **v1.6** | Tracing + Automation | 2 weeks (Sprint 7) | 2026-09-01 | 2026-06-09 | ✅ **Released** |
| **v1.7** | Multi-node eval + GPU offload | 2 weeks (Sprint 8) | 2026-09-15 | 2026-06-09 | ✅ **Released** |
| **v1.8** | Patch fixes, doc refinements | 2 weeks (Sprint 9) | 2026-09-29 | — | 🔄 **Planned** |
| **v1.9** | Additional Hermes skills | 2 weeks (Sprint 10) | 2026-10-13 | — | 🔄 **Planned** |
| **v1.10** | Cost optimization, log analysis skills | 2 weeks (Sprint 11) | 2026-10-27 | — | 🔄 **Planned** |
| **v1.11** | Testing improvements, CI hardening | 2 weeks (Sprint 12) | 2026-11-10 | — | 🔄 **Planned** |
| **v1.12** | Documentation polish, runbook updates | 2 weeks (Sprint 13) | 2026-11-24 | — | 🔄 **Planned** |
| **v1.13** | Feature freeze, v1.x stabilization | 2 weeks (Sprint 14) | 2026-12-08 | — | 🔄 **Planned** |

---

## v2.x — Platform Evolution (Quarterly / 2-week sprints)

| Version | Focus | Target | Timeline | Estimated Date | Status |
|---------|-------|--------|----------|----------------|--------|
| **v2.0** | Supply Chain + Auth (BREAKING) | 4 weeks (Sprints 15-16) | 2026-12-22 – 2027-01-19 | 2027-01-19 | ✅ **Released** |
| **v2.1** | Logging + Tracing + GitOps | 4 weeks (Sprints 17-18) | 2027-01-19 – 2027-02-16 | 2027-02-16 | ✅ **Completed** |
| **v2.2** | Multi-node Ready | 4 weeks (Sprints 19-20) | 2027-02-16 – 2027-03-16 | 2027-03-16 | ✅ **Completed** |
| **v2.3** | Observability maturity | 4 weeks (Sprints 21-22) | 2027-03-16 – 2027-04-13 | 2027-04-13 | ✅ **Completed** |
| **v2.4–v2.9** | *Deferred* — supply chain maturity, security hardening, operational excellence, performance, multi-cluster, DR maturity | — | — | — | ⏸️ **Deferred** |
| **v2.10** | Cost optimization | 4 weeks (Sprints 35-36) | 2027-10-28 – 2027-11-25 | 2027-11-25 | ✅ **Completed** |
| **v2.11** | Documentation refresh | 4 weeks (Sprints 37-38) | 2027-11-25 – 2027-12-23 | 2027-12-23 | ✅ **Completed** |
| **v2.12** | v2.x stabilization, v3.0 prep | 4 weeks (Sprints 39-40) | 2027-12-23 – 2028-01-20 | 2028-01-20 | 🔄 **Planned** |

### v2.0 — Supply Chain + Auth (Quarter 1) ✅ **RELEASED**
**Breaking:** All external access via Authelia ForwardAuth
- [x] Authelia + Redis session store
- [x] Traefik middleware: `forwardauth` on all routers
- [x] Per-service groups: `admin`, `family`, `services`
- [x] Tailscale ACLs aligned with Authelia groups
- [x] Infisical for all secrets (no `.env` in repo)
- [x] Cloudflare DNS-01 → wildcard certs, port 80 closed
- [x] Syft SBOM on every image build
- [x] Cosign keyless signing (OIDC)
- [x] Trivy gate in CI: fail on CRITICAL
- [x] Renovate: auto-merge only after Trivy pass
- [x] Dependency policy doc
- [x] Migration guide: `docs/MIGRATION_GUIDE_v2.md`
- [x] ADR-008: v2.0 Breaking Migration — Docker Compose to K3s

### v2.1 — Logging + Tracing + GitOps ✅ **COMPLETED**
- [x] Loki + Promtail (replaces scattered `docker logs`)
- [x] Tempo for traces (OpenTelemetry sidecar)
- [x] Grafana: logs + metrics + traces unified
- [x] Correlation IDs across services
- [x] 28 ArgoCD applications for full GitOps
- [x] Helmfile with unified values
- [x] Correlation ID middleware (Go + Python)
- [x] Loki/Tempo/PromQL query scripts
- [x] Grafana tracing dashboards (Tracing Overview, Correlation ID Debugging)
- [x] OTEL Collector config with transform processors
- [x] K8s cluster Prometheus rules (Pods, Nodes, Longhorn)
- [x] ArgoCD app sync script
- [x] Cluster health check script
- [x] Helm release validator
- [x] **Log retention policies** — `config/loki/retention-policy.yaml`
- [x] **SLO/SLI definitions** — `config/prometheus/rules/slo-definitions.yaml`
- [x] **Burn rate alerting** — `config/prometheus/rules/burn-rate-alerts.yaml`
- [x] Cost optimizer script — `scripts/cost_optimizer.py`
- [x] SLO Error Budget dashboard — `config/grafana/provisioning/dashboards/slo-error-budget.json`
- [x] Explicit GitHub Actions permissions — all workflows updated
- [x] Workflow validator script — `scripts/validate-workflows.py`

### v2.2 — Multi-node Ready ✅ **COMPLETED**
- [x] K3s cluster setup script — `scripts/k3s-cluster-setup.sh`
- [x] Multi-node documentation — `docs/MULTI_NODE_SETUP.md`
- [x] NetworkPolicies for zero-trust segmentation — `config/network-policies/`
- [x] NetworkPolicy README with traffic flow matrix
- [x] Automated deny/allow policy generation scripts
- [x] K3s cluster on 2× Pi 4 (or Pi 5)
- [x] External PostgreSQL (Patroni) + Redis Cluster
- [x] Longhorn or Ceph for shared storage
- [x] Decision: stay single-node or migrate

### v2.3 — Observability Maturity ✅ **COMPLETED**
- [x] SLO/SLI definitions for all services
- [x] Burn rate alerting
- [x] **Distributed tracing sampling policies** — `docs/DISTRIBUTED_TRACING_SAMPLING.md`
- [x] Log retention policies
- [x] SLO Error Budget dashboard
- [x] NetworkPolicies for zero-trust
- [x] ArgoCD ApplicationSet for automated GitOps
- [x] ArgoCD health check script
- [x] Disaster recovery test script
- [x] **Correlation ID propagation across all services** — `docs/CORRELATION_ID_EXTRACTION.md`, `docs/DISTRIBUTED_TRACING_SAMPLING.md`
- [x] Promtail correlation ID extraction pipeline

### v2.4–v2.9 — Deferred (No Active Work)

> These versions were planned but no implementation started. Deferred to post-v3.0 or removed.

| Version | Original Focus | Reason |
|---------|----------------|--------|
| v2.4 | Supply Chain Maturity | Partial done in v2.0/v2.10; remaining low priority |
| v2.5 | Security Hardening | Kyverno tagged (v2.5.0); mTLS, pen testing deferred |
| v2.6 | Operational Excellence | Runbooks done (v2.11); chaos, capacity planning deferred |
| v2.7 | Performance Optimization | Not started; may address in v3.0 |
| v2.8 | Multi-cluster Readiness | Prerequisites (Cluster API, federation) not met |
| v2.9 | DR Maturity | Cross-region replication done (v2.10); full DR deferred |

---

### v2.10 — Cost Optimization ✅ **COMPLETED**
- [x] **Resource Quotas & Limits** — 4-tier quotas (P0-P3) across 12 namespaces (29 YAML files)
- [x] **Spot Instance Integration** — EKS Spot node group (t3.medium, capacity-optimized) with 70% cost savings, PDBs, termination handler
- [x] **Right-Sizing Automation** — Weekly VPA + Prometheus analysis with GitHub Actions workflow (10%+ savings detection)
- [x] **Unused Resource Detection** — 8-category scanner (PVCs, Secrets, Services, Ingresses, NetworkPolicies, HPAs, Roles, LBs) with PR creation
- [x] **Cost Allocation & Chargeback** — Weekly allocation by namespace/team/service with configurable rates, GitHub Actions report
- [x] **Power/Electricity Optimization** — Pi CPU governor/frequency limits, LED/WiFi/BT disable, USB/storage/network power mgmt, Grafana dashboard, Prometheus alerts
- [x] **Backup Encryption Verification** — Weekly Restic/Velero/B2 AES-256 verification via GitHub Actions
- [x] **Cross-Region Backup Replication** — Restic rclone (B2→S3/GCS), Velero BSL replication, S3 CRR, GCS dual-region
- [x] **DR Automation** — Monthly DR test, quarterly failover, automated DNS failover (Cloudflare), Velero cross-region restore
- [x] **Ansible DR Runbooks** — Failover, monthly test, Velero operations, full DR failover playbooks
- [x] **Ansible Resource Quotas** — 29 quota/limit manifests with Kustomize
- [x] **Spot Instance Patches** — 7 workload patches with tolerations/affinity for DR spot nodes

### v2.11 — Documentation Refresh ✅ **COMPLETED**
- [x] **ARCHITECTURE.md** — Comprehensive architecture documentation ✅ **Done**
- [x] **README.md** — Updated with v2.10 features ✅ **Done**
- [x] **Runbooks** for new components (quotas, spot, rightsizing, unused, cost, power) ✅ **Done**
- [x] **CHANGELOG.md** — v2.10 entries ✅ **Done**
- [x] **Operational guides** for new components ✅ **Done** (exists in operational-guides.md)
- [x] **VERSION_ROADMAP.md** — Updated with v2.10 completion ✅ **Done**

---

### v2.12 — v2.x Stabilization & v3.0 Prep 🔄 **Planned**

> Final v2.x release. Stabilize current platform, validate DR, prepare v3.0 AI/ML platform.

| Area | Tasks |
|------|-------|
| **Tech Debt** | Dependency upgrades, CVE remediation, deprecated API migration |
| **Security** | Full Trivy scan remediation, cert rotation drill, pen test |
| **Reliability** | Full DR failover test (RTO/RPO validation), backup restore test |
| **Observability** | Dashboard consolidation, alert tuning, SLO validation |
| **Documentation** | v2→v3 migration guide, API reference, runbook review |
| **v3.0 Prep** | Jetson Orin procured, Qdrant vs Milvus POC, cloud GPU credits, MLflow POC |

---

---

## v3.x — Advanced Capabilities (6+ months)

| Version | Theme | Target | Timeline | Estimated Date | Status |
|---------|-------|--------|----------|----------------|--------|
| **v3.0** | AI/ML Platform | 8 weeks (Sprints 39-46) | 2028-03-17 – 2028-05-12 | 2028-05-12 | 🔄 **Planned** |
| **v3.1** | Edge/OT — Matter, Thread, Zigbee | 8 weeks (Sprints 47-54) | 2028-05-12 – 2028-07-07 | 2028-07-07 | 🔄 **Planned** |
| **v3.2** | Developer Platform | 8 weeks (Sprints 55-62) | 2028-07-07 – 2028-09-01 | 2028-09-01 | 🔄 **Planned** |

---

## v3.0 — AI/ML Platform (6+ months) 🔄 **Planned**

> See `docs/v3-planning.md` for detailed architecture, milestones, and hardware requirements.

### Milestones

| Milestone | Target | Components |
|-----------|--------|------------|
| **M1: Ollama Cluster** | Month 2 | Multi-node GPU inference, model registry, auto-scaling |
| **M2: RAG Pipeline** | Month 3 | Qdrant, BGE-M3 embeddings, hybrid search, reranking |
| **M3: Fine-Tuning** | Month 4 | LoRA/QLoRA, dataset versioning, model registry, eval |
| **M4: Inference API** | Month 5 | OpenAI-compatible, streaming, functions, routing |
| **M5: MLOps Platform** | Month 6 | MLflow, model CI/CD, drift detection, auto-retraining |

### Prerequisites (Must Complete Before v3.0 Kickoff)
- [ ] v2.11 documentation complete
- [ ] Jetson Orin 16GB ×1 procured (GPU worker)
- [ ] Cloud GPU credits secured (AWS/GCP — $5k-10k for 6 months)
- [ ] Qdrant vs Milvus POC completed (2 weeks)
- [ ] Ollama cluster on Pi 5 + Jetson POC completed (2 weeks)
- [ ] Team capacity confirmed (1-2 engineers for 6 months)
- [ ] Budget approved for cloud GPU burst ($5k-10k)

### v3.1 — Edge/OT (Matter, Thread, Zigbee) 🔄 **Planned**
- [ ] Matter/Thread/Zigbee bridge (OpenThread/OTBR)
- [ ] Home Assistant Matter integration
- [ ] Zigbee2MQTT / ZHA unification
- [ ] Thread border router (OpenThread)
- [ ] Matter device provisioning automation

### v3.2 — Developer Platform 🔄 **Planned**
- [ ] Gitea + Drone/Woodpecker CI
- [ ] Preview environments per PR
- [ ] Ephemeral environments per feature branch
- [ ] GitOps with ArgoCD/Flux
- [ ] Developer self-service portal (Backstage)
- [ ] Preview env TTL and cleanup

---

## Release Cadence

| Line | Minor | Patch |
|------|-------|-------|
| v1.x | 2-week sprints (complete) | As needed |
| v2.x | 4-week quarters | As needed |
| v3.x | 8-week milestones | As needed |

---

## Version Metadata (for automation)

```json
{
  "current": "v2.11.0",
  "next": "v2.12.0",
  "next_major": "v3.0.0",
  "branches": {
    "main-v1": "v1.7",
    "develop-v1": "v1.7",
    "main-v2": "v2.11",
    "develop-v2": "v2.11"
  },
  "support": {
    "v1.x": "maintenance",
    "v1.7": "released",
    "v2.x": "active",
    "v2.10": "released",
    "v2.11": "released",
    "v2.12": "planned"
  }
}
```