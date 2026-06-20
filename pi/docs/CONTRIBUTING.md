# Contributing

Thank you for your interest in contributing to the Pi4B Homelab project!

This is primarily a personal homelab project, but improvements, fixes, and suggestions are welcome.

---

## Ways to Contribute

- **Bug reports**: Open an issue describing the problem, your Pi model, OS version, and relevant logs
- **Improvements**: Submit a PR with config improvements, security hardening, or new service additions
- **Documentation**: Fix typos, clarify steps, add examples
- **New stack suggestions**: Open an issue proposing a new self-hosted service addition

---

## Guidelines

### General
- Keep services ARM64-compatible (works on Raspberry Pi 4B)
- Memory footprint should be reasonable — this runs on 4GB RAM
- All secrets must use environment variables; never hardcode credentials
- Follow existing naming conventions and file structure

### Docker Compose
- Use specific image tags, not `latest` in production configs (but `latest` is acceptable for simplicity in dev)
- Always include `restart: unless-stopped`
- Add health checks where the upstream image supports it
- Use the correct Docker network (proxy, monitoring, apps, smarthome)
- Add Traefik labels for services that need web access

### Documentation
- Update `README.md` if adding a new service to the stack
- Update `docs/ARCHITECTURE.md` for network/topology changes
- Add troubleshooting tips to `docs/TROUBLESHOOTING.md` for known gotchas

### Scripts
- Use `set -euo pipefail` at the top of all Bash scripts
- Include descriptive comments
- Test on actual Pi hardware if possible

---

## Development Setup

```bash
# Clone the repo
git clone https://github.com/IamVanshKhanna/homelab-prod.git
cd homelab-prod

# Copy env example
cp .env.example .env
# Edit .env with your values

# Run setup
bash scripts/setup.sh
```

---

## Pull Request Process

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/add-service-name`
3. Make your changes
4. Test on real hardware if possible
5. Commit with a clear message: `git commit -m "feat: add Homer dashboard stack"`
6. Push and open a PR against `main`

---

## Code of Conduct

Be respectful and constructive. This is a learning project — feedback should help, not discourage.

---

*Built with curiosity on a Raspberry Pi 4B.*
