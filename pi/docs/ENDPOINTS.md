# Service Endpoints Reference

> Last updated: 2026-06-13 | Host: AutoBot (192.168.68.59)

This document lists every service, its access URL, default credentials, and how to verify it is working. Non-technical users (age 16+) should be able to read this and understand what each service does and how to check if it is online.

---

## Quick Health Check

Open a terminal (Command Prompt or PowerShell on Windows, Terminal on Mac/Linux) and type:

```bash
ssh vansh@192.168.68.59
```

Once logged in, run:
```bash
cd ~/homelab-prod && bash scripts/health-check.sh
```

This checks if all services are running. Green = OK, Red = problem.

---

## Service List

### 1. Traefik (Reverse Proxy)
- **What it does:** Acts as the "front door" for all web services. Handles security certificates (HTTPS) and routes traffic to the right service.
- **Access URL:** `https://traefik.yourdomain.com`
- **Local test:** `curl -k https://192.168.68.59:443`
- **Credentials:** Set in `.env` as `TRAEFIK_DASHBOARD_USER` / `TRAEFIK_DASHBOARD_PASS`
- **How to check:** Visit the dashboard URL in a browser. You should see a Traefik dashboard with routers and services listed.

### 2. Portainer (Container Manager)
- **What it does:** A web interface to manage Docker containers. Useful if you prefer clicking over typing commands.
- **Access URL:** `https://portainer.yourdomain.com`
- **Local test:** `curl -k https://portainer.yourdomain.com` or `http://192.168.68.59:9000`
- **Credentials:** Set during first visit. Username: `admin`, Password: you choose
- **How to check:** Login to Portainer. All containers should show as "running" (green).

### 3. Nextcloud (Personal Cloud Storage)
- **What it does:** Your own private Dropbox/Google Drive. Store files, photos, calendars, contacts.
- **Access URL:** `https://cloud.yourdomain.com`
- **Local test:** `curl -k https://cloud.yourdomain.com`
- **Credentials:** Set in `.env` as `NEXTCLOUD_ADMIN_USER` / `NEXTCLOUD_ADMIN_PASSWORD`
- **How to check:** Open the URL. Login page should appear.

### 4. Vaultwarden (Password Manager)
- **What it does:** Stores all your passwords securely. Syncs with Bitwarden apps on phone/laptop.
- **Access URL:** `https://vault.yourdomain.com`
- **Local test:** `curl -k https://vault.yourdomain.com`
- **Credentials:** Create account on first visit. Admin panel: `ADMIN_TOKEN` from `.env`
- **How to check:** Open the URL. You should see a login page.

### 5. Home Assistant (Smart Home Hub)
- **What it does:** Controls smart home devices — lights, sensors, cameras, thermostats, etc.
- **Access URL:** `http://192.168.68.59:8123`
- **Local test:** `curl http://192.168.68.59:8123`
- **Credentials:** Set during first setup. Username and password you choose.
- **How to check:** Open `http://192.168.68.59:8123` in a browser. Setup/login page should appear.

### 6. Pi-hole (Ad Blocker + DNS)
- **What it does:** Blocks ads across your entire network. Also provides local DNS (custom domain names for your services).
- **Access URL (Web UI):** `http://192.168.68.59:8053/admin`
- **DNS Server:** `192.168.68.59` (port 53)
- **Credentials:** Set in `.env` as `PIHOLE_WEBPASSWORD`
- **How to check:** Open the admin page. The dashboard shows queries blocked, total queries, etc.

### 7. WireGuard (VPN)
- **What it does:** Creates a secure tunnel to your home network from anywhere. Like being at home even when you are away.
- **Access:** Via WireGuard app on your phone/laptop
- **Port:** UDP 51820
- **How to check:** Connect with the WireGuard app. You should be able to access `192.168.68.59` services.

### 8. Grafana (Monitoring Dashboards)
- **What it does:** Shows graphs and charts about your server's health — CPU, memory, disk, network.
- **Access URL:** `https://grafana.yourdomain.com`
- **Local test:** `curl -k https://grafana.yourdomain.com`
- **Credentials:** Set in `.env` as `GF_SECURITY_ADMIN_USER` / `GF_SECURITY_ADMIN_PASSWORD`
- **How to check:** Login to Grafana. Go to Dashboards → Homelab. You should see CPU/memory graphs updating.

### 9. Prometheus (Metrics Database)
- **What it does:** Collects numbers about every service (feeds data to Grafana for charts).
- **Access:** `http://192.168.68.59:9090`
- **Credentials:** None (local access only)
- **How to check:** Open the URL, click Status → Targets. All should show "UP" in green.

### 10. Uptime Kuma (Uptime Monitor)
- **What it does:** Constantly checks if your services are online. Sends alerts if something goes down.
- **Access URL:** `https://uptime.yourdomain.com`
- **Local test:** `curl -k https://uptime.yourdomain.com`
- **Credentials:** Set during first visit.
- **How to check:** Login. All monitors should show green "UP" status.

### 11. Authelia (Authentication / SSO)
- **What it does:** Adds a login gate before any service. Provides two-factor authentication (2FA).
- **Access URL:** `https://auth.yourdomain.com`
- **Credentials:** Defined in `config/authelia/users_database.yml`
- **How to check:** Visit any protected service. You should be redirected to Authelia login.

### 12. CrowdSec (Intrusion Detection)
- **What it does:** Monitors logs for hacking attempts and automatically blocks bad IPs.
- **Access:** No web UI. Works silently in the background.
- **How to check:** `docker logs crowdsec` — should show log parsing activity.

### 13. Ollama (Local AI / LLM)
- **What it does:** Runs AI language models locally on your Pi. No internet needed, your data stays private.
- **Access:** `http://127.0.0.1:11434` (local only)
- **Credentials:** None
- **How to check:** `curl http://127.0.0.1:11434/api/tags` — should return a list of downloaded models.

### 14. Loki + Promtail (Log Aggregation)
- **What it does:** Loki collects all logs from every container. Promtail ships logs to Loki. Viewable in Grafana.
- **How to check:** In Grafana, go to Explore → select Loki datasource → run `{job="varlogs"}` — should see log entries.

### 15. Alertmanager (Alert Notifications)
- **What it does:** Sends notifications when Prometheus detects problems (high CPU, low disk, service down).
- **Access:** `http://192.168.68.59:9093`
- **How to check:** Open the URL. Should show the Alertmanager status page.

### 16. Tempo (Distributed Tracing)
- **What it does:** Tracks requests as they travel between services, helping debug slow performance.
- **Access:** Via Grafana Explore → Tempo datasource.
- **How to check:** In Grafana, Explore → Tempo. Search for recent traces.

---

## Port Summary

| Port | Service | External? | Purpose |
|------|---------|-----------|---------|
| 22 | SSH | Yes | Remote terminal access |
| 53 | Pi-hole DNS | Yes (UDP) | DNS server |
| 80 | Traefik HTTP | Yes | Redirects to HTTPS |
| 443 | Traefik HTTPS | Yes | Secure web access |
| 3000 | Grafana | Internal | Monitoring UI |
| 8082 | Traefik Metrics | Internal | Prometheus metrics |
| 8053 | Pi-hole Web | Yes | Ad-block admin page |
| 8123 | Home Assistant | Yes | Smart home control |
| 9090 | Prometheus | Internal | Metrics database |
| 9093 | Alertmanager | Internal | Alert management |
| 9100 | Node Exporter | Internal | System metrics |
| 9617 | Pi-hole Exporter | Internal | Pi-hole metrics for Prometheus |
| 11434 | Ollama | Internal | AI model API |
| 3100 | Loki | Internal | Log storage |
| 51820 | WireGuard | Yes (UDP) | VPN |

---

## Troubleshooting Quick Reference

| Problem | What to try |
|---------|------------|
| Website shows "404 Not Found" | Check Traefik dashboard — is the router listed? |
| Website shows "502 Bad Gateway" | The backend container may be down. Run `docker ps` and check status. |
| Can't reach any service | Check if Pi is powered on. Try `ping 192.168.68.59`. |
| Pi-hole not blocking ads | Try `nslookup doubleclick.net 192.168.68.59`. Should return `0.0.0.0`. |
| Low disk space warning | Run `df -h /mnt/data`. Clear old backups: `rm /mnt/backup/*.tar.gz` |
| Service keeps restarting | Run `docker logs containername --tail 50` to see last 50 log lines. |
| RAM is full (>90%) | Stop Ollama: `docker stop ollama`. Restart when needed. |