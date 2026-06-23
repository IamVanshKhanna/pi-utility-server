# homelab-ops-mesh

**A two-computer home server system that runs your own private versions of cloud services — like Google Drive, Dashboards, Password Manager, VPN, and more — all from a Raspberry Pi and your Windows PC.**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

---

## What Is This?

This project turns two ordinary computers into one private, self-hosted cloud:

- A **Raspberry Pi 4B** (the size of a deck of cards, uses as much power as a night light) runs basic services 24/7
- A **Windows PC** handles the heavy lifting when it's turned on — dashboards, monitoring, security

They talk to each other over a secure tunnel (like a private internet connection) so nothing is exposed to hackers. You access everything through one web address with a lock icon (HTTPS).

```
You visit a website address ──► Secure tunnel ──► Pi decides where to send you
                                                     │
                                              ┌───────┼────────┐
                                              ▼               ▼
                                        Pi services      Windows services
                                        (always on)      (when PC is on)
```

---

## What Problem Does This Solve?

Instead of paying monthly for services like Dropbox, LastPass, or a monitoring service, this project runs your own versions on hardware you already own. It's a learning project that shows how real companies set up their internal systems.

| Instead of paying for... | This runs your own version | Why bother |
|---|---|---|
| Dropbox / Google Drive | **Nextcloud** — your private cloud storage | Your files, your rules, no monthly fee |
| LastPass / 1Password | **Vaultwarden** — password manager | You control the master password |
| Statuspage / Pingdom | **Uptime Kuma** — website monitoring | Know when your internet goes down |
| Grafana Cloud / Datadog | **Grafana + Prometheus** — dashboards and alerts | See what your computers are doing |
| Duo Security / Okta | **Authelia** — login with 2-factor auth | Extra lock on all your services |
| AWS Secrets Manager | **Infisical** — store API keys safely | Keep tokens out of code |
| Google Nest / Alexa | **Home Assistant** — smart home hub | Automate lights, sensors, everything |
| NordVPN / ExpressVPN | **WireGuard** — private VPN to your home | Access your home network from anywhere |

---

## Why I Built This

I wanted to understand how the tools that run the internet actually work — monitoring, security, networking, backups — by building them myself instead of clicking buttons in a cloud dashboard.

The Pi alone doesn't have enough memory (4GB) to run everything, so I split the work: the Pi runs the always-on essentials, and my Windows PC runs the heavy stuff when I'm using it.

It also saves me about $50-80/month in cloud subscriptions.

---

## The Two Computers

### The Pi — "autobot" (Always On)

Think of this as the reception desk. It's always there, uses almost no electricity, and handles:

- **Traefik** — the traffic cop that directs visitors to the right service
- **Pi-hole** — blocks ads across your whole WiFi (not just one browser)
- **Nextcloud** — your private Google Drive (files, photos, contacts)
- **Vaultwarden** — your private password manager (syncs with Bitwarden apps)
- **Home Assistant** — controls smart lights, sensors, automations
- **CrowdSec** — watches for hackers trying to break in
- **Samba** — shared folders on your home network (like a NAS)
- **Syncthing** — keeps files in sync between your devices automatically

**Power usage**: ~5 watts (about $5/year in electricity)

### The Windows PC — "mr-stranger" (On When You Are)

This does the heavy work when your PC is on:

- **Grafana** — beautiful charts showing what every service is doing
- **Prometheus** — collects numbers (CPU, memory, disk) every 15 seconds
- **Alertmanager** — sends you a Telegram message if something breaks
- **Loki** — stores logs (error messages, crash reports) from all services
- **Tempo** — traces slow requests to find bottlenecks
- **Authelia** — adds a second login screen with 2-factor auth to every service
- **Infisical** — safely stores API keys and passwords for developers

**Power usage**: your normal PC electricity (but no extra hardware needed)

---

## Quick Tour — What Each Service Does

| Service | In Plain English | What You'd Use It For |
|---|---|---|
| **Traefik** | The person at the front desk who points visitors to the right room | Every request comes here first; it routes to the correct service |
| **Pi-hole** | An ad blocker for your entire house — not just one browser | Blocks ads on phones, smart TVs, game consoles, everything |
| **WireGuard** | A private tunnel from anywhere in the world back to your home | Check your security cameras or files while traveling |
| **Vaultwarden** | Store all your passwords in one safe place | Works with the Bitwarden app on your phone |
| **Nextcloud** | Your own Google Drive — files, photos, calendar, contacts | Access your files from anywhere, share with family |
| **Home Assistant** | Ties all your smart home gadgets together | "Goodnight" button that turns off lights, locks doors, sets thermostat |
| **CrowdSec** | A neighborhood watch for your server | Automatically blocks IP addresses that try to break in |
| **Grafana** | A dashboard showing everything | See CPU usage, disk space, temperature, all in one place |
| **Prometheus** | A robot that constantly checks health every 15 seconds | Tells Grafana what to draw on its charts |
| **Alertmanager** | Calls you (via Telegram) when something breaks | "Your disk is 90% full!" or "A service has crashed!" |
| **Authelia** | A second lock on the door | When you visit any service, it asks for password + code from your phone |
| **Infisical** | A safe for API keys and secrets | Developers use it instead of putting passwords in code |
| **Loki** | Stores error messages from every service | When something breaks, check here for clues |
| **Tempo** | Traces a single request across all services | Find out why a page loaded slowly |
| **Uptime Kuma** | Checks if websites are working | Get alerted if your internet goes down |
| **Syncthing** | Syncs folders between devices automatically | Keep your Documents folder identical on laptop, desktop, phone |
| **Samba** | Shared folders on your home network | Like the shared drive at an office — drag and drop files |
| **Portainer** | A visual dashboard for Docker | See which containers are running, restart them, view logs |
| **cAdvisor** | Watches containers' resource usage | See which app is using too much memory |

---

## How Visitors Get To Your Services

1. You open a link like `https://your-name.ts.net/cloud/`
2. **Tailscale** (a private mesh network) checks it's really you and encrypts the connection
3. The request arrives at the **Pi's Traefik** on a private port
4. **Traefik** reads the path (`/cloud/`) and routes it:
   - `/cloud/` → Nextcloud on the Pi
   - `/grafana/` → Grafana on your Windows PC
   - `/vault/` → Vaultwarden on the Pi
   - `/auth/` → Authelia login on your Windows PC

Nothing is exposed to the public internet — everything goes through the secure Tailscale tunnel.

---

## Services, Ports & Default Passwords

All secret values (passwords, tokens, API keys) are stored in `.env` files that are NOT included in the repository. The `.env.example` files show you which values you need to set. Never commit real secrets to Git.

### Pi Services (19 services, always running)

| Service | How To Access | What You Need To Log In |
|---|---|---|
| **Traefik Dashboard** | `https://your-domain/dashboard` | Username: `admin`, Password: set in `pi/.env` |
| **Portainer** | `https://your-domain/portainer` | Create an account on first visit |
| **Pi-hole** | `http://pi-ip-address:8053` | Password set in `pi/.env` |
| **WireGuard** | VPN — connect with the config file | Configs are generated automatically on first run |
| **Vaultwarden** | `https://your-domain/vault` | Register your account; admin panel at `/vault/admin` with token from `pi/.env` |
| **Nextcloud** | `https://your-domain/cloud` | Username: `admin`, Password: set in `pi/.env` |
| **Home Assistant** | `http://pi-ip-address:8123` | Create an account on first visit |
| **Syncthing** | `http://pi-ip-address:8384` | Set password in the Web UI on first visit |
| **Uptime Kuma** | `https://your-domain/uptime` | Create an account on first visit |
| **Samba** | `\\autobot\shared` (File Explorer) | Username: `vansh`, Password: set in `pi/.env` |
| **CrowdSec** | Internal only | No login needed (runs automatically) |
| **MariaDB** | Internal (database for Nextcloud) | Credentials in `pi/.env` |
| **Redis** | Internal (speeds up Nextcloud) | No login needed |
| **cAdvisor** | Internal | No login needed |
| **Node Exporter** | Internal | No login needed |
| **Promtail** | Internal | No login needed |
| **CrowdSec Relay** | Internal | No login needed |
| **Portfolio** | `https://your-domain/` | Public website, no login needed |

### Windows Services (10 services, need PC to be on)

| Service | How To Access | What You Need To Log In |
|---|---|---|
| **Grafana** | `https://your-domain/grafana` | Username: `admin`, Password: set in `windows/.env` |
| **Prometheus** | Internal | No login needed |
| **Alertmanager** | Internal | No login needed (sends alerts to Telegram) |
| **Loki** | Internal | No login needed |
| **Tempo** | Internal | No login needed |
| **Authelia** | `https://your-domain/auth` | Username/password set in `users_database.yml` |
| **Authelia Redis** | Internal | Password set in `windows/.env` |
| **Infisical** | `https://your-domain/secrets` | Create an account on first visit |
| **Infisical Database** | Internal | Password set in `windows/.env` |
| **Infisical Redis** | Internal | Password set in `windows/.env` |

---

## How To Set This Up Yourself

### You'll Need

1. A **Raspberry Pi 4** (4GB or 8GB) with Raspberry Pi OS or Debian installed
2. A **Windows PC** with Docker Desktop installed
3. **Tailscale** installed on both (free account)
4. Tailscale **MagicDNS** turned on (one-click in the admin console)

### Step 1 — Get the Code

```bash
git clone https://github.com/IamVanshKhanna/homelab-ops-mesh.git
cd homelab-ops-mesh
```

### Step 2 — Set Your Passwords

```bash
# On the Pi:
cp pi/.env.example pi/.env
# Edit pi/.env and fill in your passwords, domain, timezone

# On Windows (PowerShell):
cp windows\.env.example windows\.env
# Edit windows\.env with the same values
```

### Step 3 — Start the Pi Services (in this order)

```bash
docker compose -f pi/stacks/core/docker-compose.yml up -d      # Traffic cop + management
docker compose -f pi/stacks/network/docker-compose.yml up -d   # Ad blocker + VPN
docker compose -f pi/stacks/monitoring/docker-compose.yml up -d  # Health checks
docker compose -f pi/stacks/nas/docker-compose.yml up -d       # File sharing
docker compose -f pi/stacks/apps/docker-compose.yml up -d      # Cloud storage + passwords
docker compose -f pi/stacks/crowdsec/docker-compose.yml up -d  # Security
docker compose -f pi/stacks/smarthome/docker-compose.yml up -d # Smart home
docker compose -f pi/stacks/uptime-kuma/docker-compose.yml up -d  # Uptime checks
docker compose -f pi/stacks/portfolio/docker-compose.yml up -d # Your portfolio site
```

### Step 4 — Start the Windows Services

```powershell
docker compose -f windows/stacks/monitoring/docker-compose.yml up -d
docker compose -f windows/stacks/tracing/docker-compose.yml up -d
docker compose -f windows/stacks/auth/docker-compose.yml up -d
docker compose -f windows/stacks/secrets/docker-compose.yml up -d
```

---

## Skills This Project Shows Employers

### Infrastructure & DevOps
- **Docker Compose** — managing 29 containers across 13 stacks with dependencies, health checks, and resource limits
- **Git & config management** — `.env`/`.env.example` pattern, secrets never committed, bundle deployments to offline servers
- **Cross-platform** — deploying and networking Linux ARM64 + Windows amd64 in a single system
- **Systemd & cron** — scheduled automated tasks (backups, health reports)

### Networking
- **Tailscale mesh VPN** — zero-config secure networking, automatic HTTPS certificates
- **Reverse proxy** (Traefik) — path-based routing, rate limiting, header manipulation, authentication forwarding
- **DNS** (Pi-hole) — network-level ad blocking, custom DNS entries
- **VPN server** (WireGuard) — secure remote access with peer management

### Monitoring & Observability
- **Full LGTM stack** — Prometheus (metrics), Loki (logs), Grafana (dashboards), Tempo (traces)
- **Alerting** — Alertmanager with Telegram delivery, grouping, deduplication, custom HTML templates
- **8 scrape targets** across two physical nodes, all reporting `UP`
- **Container monitoring** — cAdvisor for container metrics, node-exporter for hardware metrics

### Security
- **SSO with 2FA** (Authelia) — forward-auth protecting all web services
- **Intrusion detection** (CrowdSec) — custom remediation profiles, multi-stage alert pipeline to Telegram
- **Secrets management** (Infisical) — PostgreSQL-backed encrypted storage, health-checked deployment
- **Password management** (Vaultwarden) — Bitwarden-compatible self-hosted instance
- **Defense in depth** — VPN, WAF headers, rate limiting, basic auth, IP whitelisting

### Automation
- **Python** — alert format conversion relay, legacy backup scripts
- **Bash** — backup automation with Restic, health reporting, deployment scripts
- **Scheduled tasks** — daily encrypted backups (cron 03:00), daily health summary (systemd timer 08:00)

### Storage & Backup
- **Restic** — encrypted snapshots with full retention policy (7 daily, 4 weekly, 6 monthly)
- **Docker volume backups** — compressed archives of all 9 named volumes
- **NAS capabilities** — Samba file sharing + Syncthing device sync across `/mnt/nas/`
- **Cloud-ready** — backup scripts support Backblaze B2 with a config change

---

## The Good and The Not-So-Good

### What Works Well

- The Pi costs about **$5/year** to run 24/7 — no cloud server bills
- Your Windows PC is already there — no extra hardware to buy
- Plain Docker Compose is easy to understand (no Kubernetes learning curve)
- One web address covers everything with automatic HTTPS
- Real security — intrusion detection, 2-factor auth, VPN, rate limiting
- Adding a new service is dropping in one config file

### What To Keep In Mind

- Your Windows PC needs to be on for dashboards, login, and secrets to work
- If the Pi fails, everything goes down (no backup server)
- If Tailscale has an outage, nothing is accessible remotely
- Backups report success but aren't automatically tested
- Passwords in `.env` files need to be rotated manually over time
- The Pi has 4GB RAM shared across 19 containers — room to grow, but limited
- Services on Windows are one network hop away through Tailscale

---

## Project History

```
v0.x     2024       Started with Kubernetes (K3s + ArgoCD) — too complex, removed
v1.0     2025-01    Single Pi 4B with 27 Docker containers
v1.1     2026-05    Moved heavy services (Grafana, monitoring, auth) to Windows
v1.2     2026-06    Upgraded CrowdSec, added Telegram alert pipeline
v1.3     2026-06    Optimized memory, set up automated backups, cleaned up
```

---

## Repository Layout

```
homelab-ops-mesh/
├── pi/                          # Raspberry Pi 4B files
│   ├── stacks/                  #   9 service groups (docker-compose files)
│   ├── config/                  #   Settings for each service
│   ├── scripts/                 #   Backup and health check scripts
│   ├── systemd/                 #   Scheduled task configurations
│   └── .env.example             #   Template for your passwords
├── windows/                     # Windows PC files
│   ├── stacks/                  #   4 service groups
│   ├── config/                  #   Settings for Windows services
│   └── .env.example             #   Template for your passwords
├── portfolio/                   # Personal portfolio website (Astro)
└── docs/                        # Architecture documentation
```

---

## License

MIT License — see [LICENSE](LICENSE).

Copyright (c) 2026 Vansh Khanna
