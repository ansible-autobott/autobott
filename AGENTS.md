# AutoBott — Agent Guide

Ansible playbooks to manage self-hosted services on Debian servers (and basic Debian desktops).

## Project Overview

AutoBott automates the installation and configuration of a full self-hosted stack on Debian:
- Base system hardening, ZFS, VPN (WireGuard/Tailscale), backup (Borg/Borgmatic)
- Web stack: Caddy, PHP-FPM, Authelia, MariaDB
- Monitoring: Prometheus, Grafana, Alertmanager, Monit
- Media/Servarr: Jellyfin, Kavita, Sonarr, Radarr, etc.
- Productivity: Immich, Docmost, MediaWiki, Homepage
- Desktop: KDE, developer tools, desktop apps

## Development Setup

```bash
make prepare           # Create venv + install ansible==11.6.0 and deps
source venv/bin/activate
```

## Common Commands

```bash
# Lint (must pass before release — strict mode)
make lint
make lint-fix

# Run playbook against real inventory
make run INV=../inventory/main.yaml HOST=myhost TAG=role_docker
make run-verbose INV=../inventory/main.yaml TAG=role_caddy

# Enroll a new host
make enroll INV=../inventory/main.yaml HOST=myhost ANSIBLE_USER=root

# Vagrant testing (Debian 12/13 VMs)
make vagrant-up
make vagrant-run TAG=role_docker        # Test a specific role
make vagrant-test                        # Run validation tests (test.yaml)
make vagrant-destroy

# Secrets
make encrypt INV=../inventory/main.yaml KEY=mariadb_root_pass VALUE=s3cr3t
make decrypt INV=../inventory/main.yaml

# Release (requires GITHUB_TOKEN, clean git, on main branch)
# First bump autobot_version in roles/base/enroll/defaults/main.yaml
make release version=v0.2.0
```

## Architecture

### Playbook Structure

`autobott.yaml` has 4 plays:
1. **All hosts** — base, base-services, security foundation
2. **linux_servers** — web-base, monitoring, servarr, webservices
3. **linux_desktop** — KDE, dev-apps, apps
4. **post-setup** — finalization, version write

### Role Organization

```
roles/
  base/          # enroll, linux-apt, linux-basic, zfs, nullmailer, smartd, hdparm
  base-services/ # wireguard, tailscale, docker, samba, mariadb, borg, borgmatic, goback
  security/      # lynis, malwarescan, crowdsec, firewall
  web-base/      # php-fpm, caddy, authelia, vhosts
  monitoring/    # prometheus, alertmanager, node_exporter, grafana, monit
  webservices/   # homepage, docmost, mediawiki, immich, mealie, etnafinance, radicale, fe26, phpmyadmin
  servarr/       # jellyfin, kavita, transmission, sonarr, radarr, prowlarr, lidarr, whisparr, romm, stash, xbvr
  desktop/       # linux-desktop, linux-kde, vbox-guest, dev-apps, apps
  games/         # minecraft
  validation/    # test roles
```

### Role Conventions

Every role follows this layout:
```
roles/<category>/<role-name>/
  defaults/main.yaml   # All variables; always includes run_role_<name>: true
  tasks/main.yaml      # All tasks wrapped in block: with when: run_role_<name> guard
  handlers/main.yaml   # Handlers (if needed)
  templates/           # Jinja2 templates (.j2)
  meta/main.yaml       # Role metadata (if needed)
```

Key rules:
- Every role has a boolean `run_role_<name>: true` in defaults — this is how per-host opt-out works
- Tasks always use `block:` with `tags: [role_<rolename>]` and `when: run_role_<name>`
- Use `ansible.builtin.*` fully-qualified module names
- Variables follow `<rolename>_<setting>` pattern (e.g. `wireguard_port`, `mariadb_root_pass`)
- Sensitive defaults (passwords, keys) use empty string `""` — must be overridden in inventory
- User-configurable dicts: define `<role>_defaults` in defaults/, merge with inventory dict via `combine(recursive=True)`

### Inventory Structure

Per-host config lives in `inventory/host_vars/<hostname>/` with files grouped by category (base.yaml, webservices.yaml, secrets.yaml, etc.). Vault password file: `<INV_DIR>/vault_pass.txt` (never commit this).

## Adding a New Role

1. Create `roles/<category>/<rolename>/defaults/main.yaml` and `tasks/main.yaml`
2. In defaults: define `run_role_<rolename>: true` and all variables
3. In tasks: wrap all tasks in `block:` guarded by `when: run_role_<rolename>` with `tags: [role_<rolename>]`
4. Add the role to the correct play in `autobott.yaml`
5. Test: `make vagrant-run TAG=role_<rolename>`
6. Lint: `make lint`

## Key Files

| File | Purpose |
|------|---------|
| `autobott.yaml` | Main playbook — add new roles here |
| `roles/base/enroll/defaults/main.yaml` | Contains `autobot_version` — bump before release |
| `Makefile` | All commands — read before running anything |
| `inventory/vagrant.yaml` | Vagrant test inventory |
| `utils/vault.sh` | Vault encrypt/decrypt helper |
