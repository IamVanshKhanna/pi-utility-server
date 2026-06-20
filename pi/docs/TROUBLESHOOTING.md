# Troubleshooting Guide

Common issues and solutions for the Pi4B Homelab stack.

---

## General Debugging Commands

```bash
# View all running containers
docker ps

# View logs for a specific service
docker compose -f stacks/core/docker-compose.yml logs -f traefik

# Inspect container
docker inspect <container_name>

# Check Docker networks
docker network ls
docker network inspect proxy

# Check resource usage
docker stats

# View system resources
htop
df -h
free -h
```

---

## Traefik Issues

### Dashboard not accessible
- Verify the Traefik container is running: `docker ps | grep traefik`
- Check labels on the traefik service in docker-compose
- Ensure basic auth middleware is configured and `.htpasswd` file exists
- Check Traefik logs: `docker logs traefik`

### SSL certificate not generating
- Ensure ports 80 and 443 are forwarded from your router to the Pi
- Check the email in `traefik.yml` is valid
- Verify `/opt/homelab/data/traefik/certs/acme.json` has permissions `600`:
  ```bash
  chmod 600 /opt/homelab/data/traefik/certs/acme.json
  ```
- Let's Encrypt has rate limits - check logs for rate limit errors
- For testing, switch to `caServer: https://acme-staging-v02.api.letsencrypt.org/directory`

### Service not being routed by Traefik
- Ensure the service is on the `proxy` network
- Verify `traefik.enable=true` label is set
- Check router and service labels are correct
- Run: `docker inspect <container> | grep -A 20 Labels`

---

## Docker Issues

### Containers keep restarting
```bash
# Check exit code and logs
docker logs --tail 50 <container_name>
docker inspect <container_name> | grep -A 5 State
```

### Out of disk space
```bash
# Check disk usage
df -h
docker system df

# Clean up unused resources
docker system prune -a
docker volume prune
```

### Permission denied errors on volumes
```bash
# Check ownership
ls -la /opt/homelab/data/<service>

# Fix permissions (example for Grafana)
sudo chown -R 1000:1000 /opt/homelab/data/grafana

# Fix permissions for Prometheus
sudo chown -R 65534:65534 /opt/homelab/data/prometheus
```

### Docker daemon not starting after reboot
```bash
sudo systemctl status docker
sudo systemctl enable docker
sudo systemctl start docker
```

---

## Pi-hole Issues

### DNS not resolving
- Ensure Pi-hole container is running
- Check port 53 is not in use by another process: `sudo lsof -i :53`
- On Raspberry Pi OS, disable systemd-resolved if conflicting:
  ```bash
  sudo systemctl disable systemd-resolved
  sudo systemctl stop systemd-resolved
  ```
- Point your router's DNS to the Pi's IP address

### Pi-hole web UI unreachable
- Check port 8053 is accessible: `curl http://localhost:8053/admin`
- Verify the `WEBPASSWORD` env variable is set in `.env`

---

## WireGuard Issues

### VPN not connecting
- Check WireGuard logs: `docker logs wireguard`
- Ensure UDP port 51820 is forwarded from router
- Verify peer public keys match
- Check firewall rules: `sudo iptables -L`

### Regenerate peer configs
```bash
docker exec -it wireguard /app/show-peer 1
```

---

## Prometheus / Grafana Issues

### No data in Grafana
- Verify Prometheus is scraping: visit `http://prometheus-ip:9090/targets`
- Check datasource URL in Grafana: should be `http://prometheus:9090`
- Ensure both containers are on the `monitoring` network

### Grafana shows "No data" for panels
- Adjust time range in Grafana (top right)
- Check the Prometheus query in the panel editor
- Verify node-exporter and cAdvisor are running

---

## Nextcloud Issues

### 504 Gateway Timeout
- Nextcloud PHP-FPM may need more time. Add to Traefik router labels:
  `traefik.http.middlewares.nextcloud-timeout.buffering.retryExpression=IsNetworkError() && Attempts() < 2`

### Trusted domains error
```bash
docker exec -it nextcloud php occ config:system:set trusted_domains 1 --value=nextcloud.yourdomain.com
```

### Database connection errors
- Check MariaDB is running: `docker ps | grep mariadb`
- Verify DB credentials in `.env` match `docker-compose.yml`

---

## Raspberry Pi Hardware Issues

### Pi overheating (throttling)
```bash
# Check temperature
vcgencmd measure_temp

# Check for throttling
vcgencmd get_throttled
# 0x0 = no throttling
```
- Add a heatsink or fan
- Reduce `OLLAMA` usage during peak hours

### Low memory
```bash
free -h
docker stats --no-stream
```
- Stop unused stacks: `docker compose -f stacks/smarthome/docker-compose.yml stop`
- Reduce Prometheus retention: add `--storage.tsdb.retention.time=7d`

### USB SSD not detected after reboot
```bash
lsblk
dmesg | grep -i usb
```
- Add to `/etc/fstab` with `nofail` option for robust mounting
- Use UUID instead of device path: `blkid /dev/sda1`
