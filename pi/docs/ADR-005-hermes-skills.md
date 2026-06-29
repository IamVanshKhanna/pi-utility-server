# ADR-005: TinyBot Agent Skills Architecture

## Status
Accepted (replaces Hermes Agent — removed in v1.3)

## Context
TinyBot runs on the Pi homelab as a headless Telegram bot. It needs safe, structured capabilities for homelab operations with:
- Admin-only command gating (no unauthenticated actions)
- Safe command execution (`subprocess.run` with list args — no shell injection)
- Least privilege (no root, no passwordless sudo)
- Offline-first (no external AI API calls)

## Decision
TinyBot skills are **Python functions with `@admin_only` decorator**:
1. **Admin gating:** `@admin_only` decorator checks `ADMIN_CHAT_IDS` from env
2. **Safe execution:** All `subprocess.run([...])` use list form (never `shell=True`)
3. **Read-only by default:** Health checks, status queries are safe
4. **Confirmation for destructive:** Docker restart operations show confirmation

## Implemented Commands

| Command | Category | Description | Trust Level |
|---------|----------|-------------|-------------|
| /health | system | Pi CPU, RAM, temp, disk | Read-only |
| /fan [speed] | system | Fan control (0-100) | Destructive |
| /docker | system | Container list | Read-only |
| /docker close [name] | system | Stop container | Destructive |
| /docker restart [name] | system | Restart container | Destructive |
| /search | web | DuckDuckGo search | Read-only |
| /chatid | bot | Get chat ID for admin config | Read-only |

## Security Model

1. **Admin-only:** All commands gated by `@admin_only` decorator
2. **No shell injection:** `subprocess.run(["cmd", "arg1", "arg2"])` — list form only
3. **No secrets in logs:** Bot token never logged
4. **No root access:** Runs as user-level systemd service
5. **Env-based secrets:** `.env` symlinked, gitignored

## References
- `pi/tinybot/tinybot.py` — Source code
- ADR-006 — Threat model for full security analysis
