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

## Repository Layout

```
autobott.yaml          # Main playbook (4 plays: all, linux_servers, linux_desktop, post-setup)
Makefile               # All dev/ops commands
requirements.txt       # Python deps (ansible==11.6.0 + helpers)
inventory/             # Host and variable inventory files
roles/
  base/                # enroll, linux-apt, linux-basic, zfs, nullmailer, smartd, hdparm
  base-services/       # wireguard, tailscale, docker, samba, mariadb, borg, borgmatic, goback
  security/            # lynis, malwarescan, crowdsec, firewall
  web-base/            # php-fpm, caddy, authelia, vhosts
  monitoring/          # prometheus, alertmanager, node_exporter, grafana, monit
  webservices/         # homepage, docmost, mediawiki, immich, mealie, etnafinance, radicale, fe26, phpmyadmin
  servarr/             # jellyfin, kavita, transmission, sonarr, radarr, prowlarr, lidarr, whisparr, romm, stash, xbvr
  desktop/             # linux-desktop, linux-kde, vbox-guest, dev-apps/*, apps/*
  games/               # minecraft
  validation/          # test roles
vagrant/               # Vagrant test environment (debian 12)
utils/                 # vault.sh — Ansible Vault helper script
```

## Role Structure

Every role follows this standard Ansible layout:

```
roles/<category>/<role-name>/
  defaults/main.yaml   # All role variables with defaults; always has a run_role_<name>: true flag
  tasks/main.yaml      # Tasks, always wrapped in a block with a when: run_role_<name> guard
  handlers/main.yaml   # Handlers (if needed)
  templates/           # Jinja2 templates (.j2)
  meta/main.yaml       # Role metadata (if needed)
```

### Role conventions

- Every role has a boolean `run_role_<name>` variable (default `true`) to disable it per-host.
- Tasks are wrapped in a `block:` with `tags:` and `when: run_role_<name>`.
- Tag naming: use `role_<rolename>` as the primary tag (e.g., `role_enroll`, `role_docker`).
- Use `ansible.builtin.*` fully-qualified module names.
- Variables follow the pattern `<rolename>_<setting>` (e.g., `wireguard_port`, `mariadb_root_pass`).
- Sensitive defaults (passwords, keys) are empty strings `""` — must be set in inventory.
- Where a role has user-configurable data, define `<role>_defaults` dict in `defaults/` and merge with `<role>` inventory dict using `combine(recursive=True)`.

## Development Setup

```bash
make prepare           # Create venv + install ansible==11.6.0 and deps
source venv/bin/activate
```

## Running the Playbook

```bash
# Full run
make run INV=../inventory/main.yaml HOST=myhost

# Specific tag
make run INV=../inventory/main.yaml TAG=role_docker

# Verbose
make run-verbose INV=../inventory/main.yaml TAG=role_caddy

# Enroll new host
make enroll INV=../inventory/main.yaml HOST=myhost ANSIBLE_USER=root
```

## Testing

```bash
make vagrant-up        # Start Vagrant Debian 12 VM (one-time)
make vagrant-run       # Run full playbook against Vagrant
make vagrant-run TAG=role_docker  # Run a specific role against Vagrant
make vagrant-test      # Run validation tests (test.yaml)
make vagrant-destroy   # Tear down Vagrant VMs
```

**Always test role changes with `make vagrant-run TAG=role_<name>` before committing.**

## Linting

```bash
make lint              # Run ansible-lint (strict mode)
make lint-fix          # Auto-fix lint issues
```

Lint must pass before releasing. Fix all warnings — the project uses strict `-s` mode.

## Secrets / Vault

Secrets are encrypted with Ansible Vault. The vault password file lives at `<INV_DIR>/vault_pass.txt`.

```bash
make encrypt INV=../inventory/main.yaml KEY=mariadb_root_pass VALUE=s3cr3t
make decrypt INV=../inventory/main.yaml
```

Never commit plaintext secrets. Never commit `vault_pass.txt`.

## Adding a New Role

1. Create directory: `roles/<category>/<rolename>/defaults/` and `tasks/`.
2. `defaults/main.yaml`: define `run_role_<rolename>: true` and all variables.
3. `tasks/main.yaml`: wrap all tasks in a `block:` guarded by `when: run_role_<rolename>` with appropriate `tags:`.
4. Add the role to `autobott.yaml` in the correct play section.
5. Test with `make vagrant-run TAG=role_<rolename>`.
6. Run `make lint` and fix any issues.

## Releasing

```bash
# Update autobot_version in roles/base/enroll/defaults/main.yaml first
make release version=v0.2.0  # requires GITHUB_TOKEN env var, clean git, on main branch
```

Release checks: version in enroll defaults must match, must be on `main`, repo must be clean.

## Key Files to Know

| File | Purpose |
|------|---------|
| `autobott.yaml` | Main playbook — add new roles here |
| `roles/base/enroll/defaults/main.yaml` | Contains `autobot_version` — bump on release |
| `Makefile` | All commands — read before running anything |
| `inventory/vagrant.yaml` | Vagrant test inventory |
| `utils/vault.sh` | Vault encrypt/decrypt helper |
