# ADR-003: Memory Strategy — Small Model + Limits + ZRAM

## Status
Accepted

## Context
Pi 4B has 4 GB RAM. Must run: OS, Docker, 14 containers, local LLM inference.
Goal: Stay under 3.9 GB used (leave ~200 MB buffer).

## Decision
1. **Local LLM:** `gemma:2b` (1.6 GB quantized, ~1.8 GB runtime)
2. **Container memory limits** (hard `mem_limit` in compose)
3. **ZRAM swap:** 2 GB compressed in RAM (no disk swap)
4. **Operational rule:** Stop non-critical stack before heavy tasks

## Memory Budget (v1 measured)

| Component | Limit | Typical |
|-----------|-------|---------|
| OS + Docker | — | 600 MB |
| Traefik + Portainer | 384 MB | 180 MB |
| Ollama (gemma:2b) | 2 GB | 1.8 GB |
| Hermes Agent | 512 MB | 350 MB |
| Nextcloud + DB + Redis | 1.5 GB | 1.1 GB |
| Prometheus + Grafana + Exporters | 512 MB | 380 MB |
| Pi-hole + Tailscale | 128 MB | 90 MB |
| Home Assistant (host net) | 512 MB | 300 MB |
| **Total** | **5.5 GB** | **~3.8 GB** |

**Why it fits:** Compose `mem_limit` prevents OOM; ZRAM absorbs spikes; actual usage < limits.

## ZRAM Configuration
```ini
# /etc/systemd/zram-generator.conf
[zram0]
zram-size = ram / 2
compression-algorithm = zstd
```

## Model Alternatives Evaluated

| Model | Size (4-bit) | RAM | Quality | Speed | Verdict |
|-------|--------------|-----|---------|-------|---------|
| gemma:2b | 1.6 GB | 1.8 GB | ★★★★☆ | ~15 tok/s | **Chosen** |
| qwen2:1.5b | 1.1 GB | 1.3 GB | ★★★★☆ | ~20 tok/s | Backup |
| phi3:mini | 2.3 GB | 2.5 GB | ★★★★★ | ~10 tok/s | Too tight |
| llama3:8b | 4.7 GB | 5.5 GB | ★★★★★ | ~5 tok/s | **No** |
| mistral:7b | 4.1 GB | 4.8 GB | ★★★★☆ | ~6 tok/s | **No** |

## Consequences
- No heavy models (llama3:8b) on this hardware
- Restic full check may need `docker compose stop apps` first
- v2: consider 8 GB Pi 5 or offload LLM to separate box

## References
- [Ollama model library](https://ollama.com/library)
- [ZRAM generator docs](https://manpages.ubuntu.com/manpages/noble/man5/zram-generator.conf.5.html)