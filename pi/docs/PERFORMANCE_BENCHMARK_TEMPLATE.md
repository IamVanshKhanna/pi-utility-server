# Performance Benchmark Templates for Homelab

## Overview
Standardized benchmarks for measuring and tracking service performance across versions and deployments.

## 1. Database Benchmarks (PostgreSQL)

### PgBench - OLTP Workload
```bash
# Initialize test database
kubectl exec -n databases homelab-postgres-0 -- pgbench -i -s 50 homelab_db

# Run benchmark (read-write)
kubectl exec -n databases homelab-postgres-0 -- pgbench -c 10 -j 2 -T 60 -S homelab_db

# Run benchmark (read-only)
kubectl exec -n databases homelab-postgres-0 -- pgbench -c 10 -j 2 -T 60 -S homelab_db

# Custom workload (mixed)
kubectl exec -n databases homelab-postgres-0 -- pgbench -c 20 -j 4 -T 300 \
  -f /path/to/custom-workload.sql homelab_db
```

#### Custom Workload SQL (`custom-workload.sql`)
```sql
-- Mixed OLTP workload: 70% reads, 30% writes
\set aid random(1, 100000 * :scale)
\set bid random(1, 1 * :scale)
\set tid random(1, 10 * :scale)
\set delta random(-5000, 5000)

BEGIN;
  -- 70% probability: Simple SELECT
  \if random(1, 100) <= 70
    SELECT abalance FROM pgbench_accounts WHERE aid = :aid;
  \else
    -- 30% probability: UPDATE + SELECT
    UPDATE pgbench_accounts SET abalance = abalance + :delta WHERE aid = :aid;
    SELECT abalance FROM pgbench_accounts WHERE aid = :aid;
  \end if
END;
```

#### Metrics to Collect
| Metric | Target | Alert Threshold |
|--------|--------|-----------------|
| TPS (transactions/sec) | > 1000 | < 500 |
| Latency p50 | < 5ms | > 20ms |
| Latency p95 | < 20ms | > 50ms |
| Latency p99 | < 50ms | > 100ms |
| Connection pool usage | < 80% | > 90% |

---

## 2. Redis Benchmarks

### Redis-Benchmark
```bash
# Run from a pod in the cluster
kubectl run redis-benchmark --rm -i --tty --image=redis:7-alpine -- \
  redis-benchmark -h homelab-redis.databases.svc.cluster.local \
  -p 6379 -a $REDIS_PASSWORD \
  -c 50 -n 100000 \
  -t set,get,mset,mget,lpush,lpop,lrange,rpush,rpop \
  --csv > redis-benchmark-$(date +%Y%m%d).csv
```

#### Key Tests
```bash
# Pipeline test (max throughput)
redis-benchmark -h $HOST -p 6379 -c 100 -n 1000000 -P 50 -t set,get

# Large values test
redis-benchmark -h $HOST -p 6379 -d 10240 -c 50 -n 10000 -t set,get

# Lua script test
redis-benchmark -h $HOST -p 6379 -c 50 -n 100000 \
  --lua-script 'return redis.call("set", KEYS[1], ARGV[1])' \
  -t eval
```

#### Metrics to Collect
| Metric | Target | Alert Threshold |
|--------|--------|-----------------|
| SET ops/sec | > 50000 | < 20000 |
| GET ops/sec | > 80000 | < 30000 |
| Latency p99 | < 2ms | > 10ms |
| Memory fragmentation | < 1.5 | > 2.0 |
| Replication lag | < 10ms | > 100ms |

---

## 3. HTTP Service Benchmarks

### k6 Load Testing
```javascript
// k6-script.js
import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate } from 'k6/metrics';

const errorRate = new Rate('errors');

export const options = {
  stages: [
    { duration: '30s', target: 10 },   // Ramp up
    { duration: '1m', target: 50 },    // Sustained load
    { duration: '30s', target: 100 },  // Peak load
    { duration: '30s', target: 0 },    // Ramp down
  ],
  thresholds: {
    http_req_duration: ['p(95)<500', 'p(99)<2000'],
    http_req_failed: ['rate<0.01'],
    errors: ['rate<0.01'],
  },
};

const BASE_URL = __ENV.BASE_URL || 'https://nextcloud.homelab.local';

export default function() {
  const endpoints = [
    '/status.php',
    '/index.php/login',
    '/ocs/v2.php/apps/notifications/api/v2/notifications',
    '/remote.php/dav/files/user/',
  ];
  
  const url = BASE_URL + endpoints[Math.floor(Math.random() * endpoints.length)];
  
  const res = http.get(url, {
    headers: {
      'Accept-Encoding': 'br, gzip, deflate',
      'User-Agent': 'k6-load-test/1.0',
    },
  });
  
  const success = check(res, {
    'status is 200': (r) => r.status === 200,
    'response time < 2s': (r) => r.timings.duration < 2000,
    'has content': (r) => r.body.length > 0,
  });
  
  errorRate.add(!success);
  sleep(Math.random() * 2);
}
```

```bash
# Run k6 test
kubectl run k6-test --rm -i --image=grafana/k6:latest -- \
  run -e BASE_URL=https://nextcloud.homelab.local /scripts/k6-script.js
```

### Vegeta HTTP Benchmark
```bash
# Install vegeta
# Test sustained rate
echo "GET https://nextcloud.homelab.local/status.php" | \
  vegeta attack -rate=100 -duration=60s | \
  vegeta report

# Test with multiple endpoints
cat > targets.txt <<EOF
GET https://nextcloud.homelab.local/status.php
GET https://nextcloud.homelab.local/index.php/login
GET https://vaultwarden.homelab.local/alive
GET https://grafana.homelab.local/api/health
EOF

vegeta attack -targets=targets.txt -rate=50 -duration=120s | vegeta report
vegeta attack -targets=targets.txt -rate=50 -duration=120s | vegeta plot > plot.html
```

#### Metrics to Collect
| Metric | Target | Alert Threshold |
|--------|--------|-----------------|
| Success rate | > 99.9% | < 99.5% |
| Latency p50 | < 100ms | > 500ms |
| Latency p95 | < 500ms | > 2000ms |
| Latency p99 | < 1000ms | > 5000ms |
| Throughput (req/s) | > 100 | < 50 |
| Error rate | < 0.1% | > 1% |

---

## 4. Network Benchmarks

### iperf3 (Pod-to-Pod)
```bash
# Server (run on one node)
kubectl run iperf3-server --rm -i --image=networkstatic/iperf3 -- -s

# Client (run on another node)
kubectl run iperf3-client --rm -i --image=networkstatic/iperf3 \
  -c iperf3-server.default.svc.cluster.local -t 60 -P 10 -J > iperf3-results.json

# Bidirectional
kubectl run iperf3-client --rm -i --image=networkstatic/iperf3 \
  -c iperf3-server.default.svc.cluster.local -t 60 -P 10 -R -J
```

### Metrics to Collect
| Metric | Target (1GbE) | Target (10GbE) |
|--------|---------------|----------------|
| Throughput (single stream) | > 900 Mbps | > 9 Gbps |
| Throughput (10 streams) | > 950 Mbps | > 9.5 Gbps |
| Latency (ping) | < 0.5ms | < 0.2ms |
| Jitter | < 0.1ms | < 0.05ms |
| Retransmits | < 0.1% | < 0.01% |

---

## 5. Storage Benchmarks

### fio (Flexible I/O Tester)
```bash
# Create test PVC
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: fio-test-pvc
  namespace: databases
spec:
  accessModes: ["ReadWriteOnce"]
  storageClassName: longhorn
  resources:
    requests:
      storage: 50Gi
EOF

# Run fio via pod
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: fio-test
  namespace: databases
spec:
  containers:
  - name: fio
    image: nixery.dev/shell/fio
    command: ["fio", "--name=randrw", "--ioengine=libaio", "--iodepth=16",
              "--rw=randrw", "--bs=4k", "--direct=1", "--size=10G",
              "--numjobs=4", "--runtime=300", "--time_based",
              "--group_reporting", "--output-format=json",
              "--filename=/data/testfile"]
    volumeMounts:
    - name: data
      mountPath: /data
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: fio-test-pvc
  restartPolicy: Never
EOF

# Get results
kubectl logs fio-test -n databases
```

#### Tests to Run
```bash
# Sequential read
--rw=read --bs=128k --iodepth=32

# Sequential write
--rw=write --bs=128k --iodepth=32

# Random read (4K)
--rw=randread --bs=4k --iodepth=16

# Random write (4K)
--rw=randwrite --bs=4k --iodepth=16

# Mixed (70/30)
--rw=randrw --rwmixread=70 --bs=4k --iodepth=16
```

#### Metrics to Collect
| Metric | Target (SSD) | Target (NVMe) |
|--------|--------------|---------------|
| Seq Read | > 500 MB/s | > 3000 MB/s |
| Seq Write | > 450 MB/s | > 2500 MB/s |
| Rand Read 4K | > 80K IOPS | > 400K IOPS |
| Rand Write 4K | > 70K IOPS | > 350K IOPS |
| Latency p99 (read) | < 1ms | < 0.2ms |
| Latency p99 (write) | < 2ms | < 0.5ms |

---

## 6. Kubernetes Benchmarks

### k8s Resource Utilization
```bash
# Cluster-wide resource usage
kubectl top nodes --no-headers

# Per-pod resource usage
kubectl top pods -A --no-headers --sort-by=memory

# HPA metrics
kubectl get hpa -A

# API server latency
kubectl get --raw="/metrics" | grep apiserver_request_duration_seconds
```

### Cluster Autoscaler Metrics
```promql
# Node scale-up time
histogram_quantile(0.95, rate(cluster_autoscaler_scale_up_duration_seconds_bucket[5m]))

# Pending pods
sum(kube_pod_status_phase{phase="Pending"})

# Node utilization
sum(rate(container_cpu_usage_seconds_total[5m])) by (node) / sum(kube_node_status_capacity_cpu_cores) by (node)
```

---

## 7. CI/CD Integration

### GitHub Actions Benchmark Workflow

```yaml
# .github/workflows/benchmark.yml
name: Performance Benchmarks

on:
  schedule:
    - cron: '0 2 * * 0'  # Weekly Sunday 2 AM
  workflow_dispatch:
    inputs:
      service:
        description: 'Service to benchmark'
        required: true
        type: choice
        options: [postgresql, redis, nextcloud, vaultwarden, all]

jobs:
  benchmark:
    runs-on: ubuntu-latest
    timeout-minutes: 60
    steps:
      - uses: actions/checkout@v4
      
      - name: Setup kubectl
        uses: azure/k8s-set-context@v4
        with:
          kubeconfig: ${{ secrets.KUBECONFIG }}
      
      - name: Run PostgreSQL benchmark
        if: inputs.service == 'postgresql' || inputs.service == 'all'
        run: |
          kubectl exec -n databases homelab-postgres-0 -- \
            pgbench -c 20 -j 4 -T 300 homelab_db \
            > pgbench-results.txt
          # Extract metrics and compare with baseline
      
      - name: Run Redis benchmark
        if: inputs.service == 'redis' || inputs.service == 'all'
        run: |
          kubectl run redis-benchmark --rm -i --image=redis:7-alpine -- \
            redis-benchmark -h homelab-redis.databases -c 50 -n 100000 \
            > redis-benchmark-results.txt
      
      - name: Run k6 HTTP benchmark
        if: inputs.service == 'nextcloud' || inputs.service == 'all'
        uses: grafana/k6-action@v0.2.0
        with:
          script: scripts/k6-benchmark.js
          env: BASE_URL=https://nextcloud.homelab.local
      
      - name: Upload results
        uses: actions/upload-artifact@v4
        with:
          name: benchmark-results
          path: *-results.txt
          retention-days: 30
      
      - name: Compare with baseline
        run: |
          python3 scripts/compare-benchmarks.py \
            --current pgbench-results.txt \
            --baseline benchmarks/baselines/pgbench-baseline.txt \
            --threshold 0.10  # 10% regression threshold
```

---

## 8. Baseline Storage

```bash
# Directory structure
benchmarks/
├── baselines/
│   ├── pgbench-baseline.txt
│   ├── redis-baseline.txt
│   ├── k6-nextcloud-baseline.json
│   ├── iperf3-baseline.json
│   └── fio-baseline.json
├── results/
│   ├── 2026-01-15/
│   └── ...
└── scripts/
    ├── compare-benchmarks.py
    └── generate-report.py
```

### Python Comparison Script
```python
# scripts/compare-benchmarks.py
import json
import argparse
import sys

def compare(current, baseline, threshold=0.10):
    """Compare current metrics with baseline, alert on regression > threshold"""
    regressions = []
    improvements = []
    
    for metric, cur_val in current.items():
        if metric in baseline:
            base_val = baseline[metric]
            change = (cur_val - base_val) / base_val
            
            if change < -threshold:
                regressions.append(f"{metric}: {base_val} -> {cur_val} ({change:.1%})")
            elif change > threshold:
                improvements.append(f"{metric}: {base_val} -> {cur_val} ({change:.1%})")
    
    if regressions:
        print("⚠️ REGRESSIONS DETECTED:")
        for r in regressions:
            print(f"  {r}")
        return 1
    
    if improvements:
        print("✅ IMPROVEMENTS:")
        for i in improvements:
            print(f"  {i}")
    
    return 0

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--current", required=True)
    parser.add_argument("--baseline", required=True)
    parser.add_argument("--threshold", type=float, default=0.10)
    args = parser.parse_args()
    
    with open(args.current) as f:
        current = json.load(f)
    with open(args.baseline) as f:
        baseline = json.load(f)
    
    sys.exit(compare(current, baseline, args.threshold))
```

---

## 9. Grafana Dashboard for Benchmarks

```json
{
  "title": "Performance Benchmarks",
  "panels": [
    {
      "title": "PostgreSQL TPS Trend",
      "type": "graph",
      "targets": [
        {"expr": "pgbench_tps", "legendFormat": "TPS"}
      ]
    },
    {
      "title": "Redis OPS/sec",
      "type": "graph",
      "targets": [
        {"expr": "redis_ops_per_sec", "legendFormat": "OPS"}
      ]
    },
    {
      "title": "HTTP Latency p50/p95/p99",
      "type": "graph",
      "targets": [
        {"expr": "histogram_quantile(0.50, rate(http_request_duration_seconds_bucket[5m]))", "legendFormat": "p50"},
        {"expr": "histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))", "legendFormat": "p95"},
        {"expr": "histogram_quantile(0.99, rate(http_request_duration_seconds_bucket[5m]))", "legendFormat": "p99"}
      ]
    },
    {
      "title": "Benchmark Regression Alert",
      "type": "stat",
      "targets": [
        {"expr": "benchmark_regression", "legendFormat": "Regressions"}
      ],
      "fieldConfig": {
        "defaults": {
          "thresholds": {
            "steps": [
              {"color": "green", "value": 0},
              {"color": "red", "value": 1}
            ]
          }
        }
      }
    }
  ]
}
```

---

## 10. Runbook Integration

Each benchmark should have a corresponding runbook section:

```markdown
# Benchmark Runbook: PostgreSQL

## When to Run
- Weekly (automated)
- After PostgreSQL version upgrade
- After configuration changes
- Before/after major deployments

## How to Run
1. `kubectl exec -n databases homelab-postgres-0 -- pgbench -c 20 -j 4 -T 300 homelab_db`
2. Record TPS, latency percentiles
3. Compare with baseline in `benchmarks/baselines/pgbench-baseline.txt`

## Expected Results
- TPS: > 1000
- Latency p50: < 5ms
- Latency p95: < 20ms
- Latency p99: < 50ms

## Troubleshooting
- Low TPS: Check autovacuum, indexes, connection pooling
- High latency: Check I/O, locks, long-running queries
- Run EXPLAIN ANALYZE on slow queries
```

---

## 11. Automation Schedule

| Benchmark | Frequency | Automation |
|-----------|-----------|------------|
| PostgreSQL (pgbench) | Weekly | GitHub Actions |
| Redis (redis-benchmark) | Weekly | GitHub Actions |
| HTTP Services (k6) | Weekly | GitHub Actions |
| Network (iperf3) | Monthly | CronJob |
| Storage (fio) | Monthly | CronJob |
| Kubernetes (kube-bench) | Weekly | GitHub Actions |

---

## 12. Alerting Rules

```yaml
# config/prometheus/rules/benchmark-alerts.yaml
groups:
- name: benchmark
  rules:
  - alert: BenchmarkRegression
    expr: benchmark_regression > 0
    for: 0m
    labels:
      severity: critical
    annotations:
      summary: "Performance regression detected"
      description: "Benchmark {{ $labels.benchmark }} regressed by {{ $value }}%"
      
  - alert: BenchmarkOverdue
    expr: time() - benchmark_last_run_timestamp > 604800  # 7 days
    for: 0m
    labels:
      severity: warning
    annotations:
      summary: "Benchmark overdue"
      description: "{{ $labels.benchmark }} hasn't run in over 7 days"
```