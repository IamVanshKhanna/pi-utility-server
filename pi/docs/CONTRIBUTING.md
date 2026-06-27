# Contributing

Thank you for your interest in contributing to homelab-ops-mesh!

This is primarily a personal homelab project, but improvements, fixes, and suggestions are welcome.

---

## Ways to Contribute

- **Bug reports**: Open an issue describing the problem, your hardware, OS version, and relevant logs
- **Improvements**: Submit a PR with config improvements, security hardening, or new service additions
- **Documentation**: Fix typos, clarify steps, add examples
- **New stack suggestions**: Open an issue proposing a new self-hosted service addition

---

## Guidelines

### General
- Pi services must be ARM64-compatible (Raspberry Pi 4B)
- Windows services run x86_64 on Docker Desktop
- Memory footprint should be reasonable — Pi has 4GB RAM, Windows has 16GB
- All secrets must use environment variables or `.template` files; never hardcode credentials
- Follow existing naming conventions and file structure (`pi/` + `windows/` + `portfolio/` + `docs/`)

### Docker Compose
- Use specific image tags, not `:latest`
- Always include `restart: unless-stopped`
- Add health checks where the upstream image supports it (distroless images exempt)
- Add memory and CPU limits to all services
- Use `:ro` on config bind mounts where possible
- Add log rotation: `max-size: 10m, max-file: 3`
- Windows stacks use `external: true` for `homelab_win` network (auth stack creates it)

### Documentation
- Update `docs/ARCHITECTURE.md` for network/topology changes
- Add troubleshooting tips to `docs/TROUBLESHOOTING.md` for known gotchas
- Use `.template` files for configs containing secrets; real files are gitignored

### Scripts
- Use `load_env()` function (not `source .env`) in all Bash scripts
- Use `set -euo pipefail` at the top of all Bash scripts
- Test on actual hardware if possible
- Ensure `eol=lf` (enforced by `.gitattributes`)

---

## Development Setup

```bash
# Clone the repo
git clone https://github.com/IamVanshKhanna/homelab-ops-mesh.git
cd homelab-ops-mesh

# Copy env example (Pi)
cp pi/.env.example .env
# Edit .env with your values

# Deploy Pi stacks
cd pi
docker compose -f stacks/core/docker-compose.yml --env-file ../../.env up -d

# Deploy Windows stacks
cd windows
docker compose -f stacks/auth/docker-compose.yml --env-file ../.env up -d
```

---

## Pull Request Process

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/add-service-name`
3. Make your changes
4. Test on real hardware if possible
5. Commit with a clear message: `git commit -m "feat: add Homer dashboard stack"`
6. Push and open a PR against `master`

---

## Code of Conduct

Be respectful and constructive. This is a learning project — feedback should help, not discourage.

---

*Built with curiosity on a Raspberry Pi 4B + Windows Desktop, connected via Tailscale mesh.*
