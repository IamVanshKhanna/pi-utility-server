# Pi Utility Server

**An always-on Raspberry Pi utility platform for self-hosted services, networking, and automation.**

---

## Overview

This repository contains the configuration, stacks, and operational tooling for a Raspberry Pi 4B that runs essential home-lab services 24/7. The platform provides networking (Headscale/Tailscale mesh VPN), file sync (Syncthing), password management (Vaultwarden), and supporting infrastructure.

Active live deployment currently remains at the legacy path until a separately approved final cutover.

---

## Repository Map

| Directory | Purpose |
|-----------|---------|
| \pi/\ | Raspberry Pi service stacks, configs, scripts, and systemd units |
| \windows/\ | Windows PC service stacks and monitoring configuration |
| \portfolio/\ | Personal portfolio website (Astro) |
| \docs/\ | Architecture and operational runbooks |

---

## Runtime-Secret Boundaries

All secret values (passwords, tokens, API keys) are stored in \.env\ files that are **never committed** to the repository. The \.env.example\ files provide templates. Never commit real secrets.

Ignored runtime assets include:
- \.env\, \.env.backup\, and all \.env.*\ variants
- Tinybot state, logs, queue, and virtualenv
- TLS certificates and keys (\*.key\, \*.pem\)
- Gitea app.ini and runner config
- Traefik dynamic runtime config

---

## License

MIT License — see [LICENSE](LICENSE).

Copyright (c) 2026 Vansh Khanna
