# ADR-005: Hermes Agent Skills Architecture

## Status
Accepted

## Context
Hermes Agent runs on the Pi homelab as a headless AI assistant. It needs structured, reusable capabilities for homelab operations. We need a consistent architecture for skills that:
- Are safe (read-only by default, confirm destructive actions)
- Are composable (skills can be loaded/unloaded per profile)
- Are versioned and documented
- Run with least privilege
- Work offline (no external API calls required)

## Decision
Implement Hermes skills as **self-contained YAML+Markdown packages** with:
1. **Frontmatter**: name, description, version, category, triggers
2. **Command allowlist**: explicit allowed commands (read-only vs. confirmation required)
3. **Forbidden list**: explicit denials
4. **Context variables**: environment variables the skill uses
5. **Example usage**: natural language triggers

Skills are stored in `~/.hermes/profiles/<profile>/skills/<skill-name>/SKILL.md`

## Skill Structure

```yaml
---
name: skill-name
description: One-line description
version: 1.0.0
category: homelab|security|backup|capacity
---

## Triggers
- Natural language phrases that activate this skill

## Allowed Commands (read-only, no confirmation)
- `safe command 1`
- `safe command 2`

## Allowed Actions (require confirmation)
- `action requiring confirmation`

## Forbidden
- `forbidden command 1`

## Context Variables
- `ENV_VAR_1`
- `ENV_VAR_2`

## Example Usage
> "Natural language trigger example"
```

## Skill Categories

| Category | Skills | Trust Level |
|----------|--------|-------------|
| **homelab-ops** | Health checks, log inspection, safe restarts | Medium |
| **backup-ops** | Snapshots, restore (dry-run), verify | High |
| **security-audit** | Trivy scans, CVE reports | Medium |
| **capacity-plan** | Disk/RAM forecasts, PromQL queries | Low |
| **gitops-helper** | CI/CD file proposals, compose validation | Medium |

## Trust Model

| Level | Read-only Commands | Confirmation Required | Forbidden |
|-------|-------------------|----------------------|-----------|
| **Low** | All | None | Destructive |
| **Medium** | Most | Some | Destructive + privileged |
| **High** | Minimal | All | Almost everything |

## Skill Loading

Skills are loaded via profile config:
```yaml
skills:
  auto_load:
    - homelab-ops
    - gitops-helper
  available:
    - backup-ops
    - security-audit
    - capacity-plan
```

- `auto_load`: Skills always available in chat
- `available`: Skills loaded on-demand when triggered

## Security Model

1. **Least Privilege**: Skills only allow explicitly listed commands
2. **Confirmation Gating**: Destructive actions require explicit user confirmation
3. **Environment Isolation**: Skills only access declared env vars
3. **No Network by Default**: Skills only run local commands unless declared
4. **Audit Trail**: All skill executions logged with timestamp, skill, command, result

## Skill Development Workflow

1. Create skill directory: `~/.hermes/profiles/homelab/skills/new-skill/`
2. Write `SKILL.md` with frontmatter and sections
3. Test in Hermes chat: "skill-name trigger phrase"
4. Iterate on allowlist based on usage
5. Version bump on changes
6. Document in CHANGELOG

## Hermes Profile Config (homelab)

```yaml
skills:
  auto_load:
    - homelab-ops
    - gitops-helper
  available:
    - backup-ops
    - security-audit
    - capacity-plan
```

## References
- [Hermes Skills Documentation](https://github.com/NousResearch/hermes-agent/blob/main/docs/skills.md)
- [Skill Authoring Guide](https://hermes-agent.nousresearch.com/docs/skills)
- [Security Best Practices](https://hermes-agent.nousresearch.com/docs/security)