# AutoBott
Ansible playbooks to manage self-hosted services on Debian servers  (_and basic debian desktop_)

## About:

Ansible-autbott allows to maintain several self-hosted services on debian based machines.
Minimal desktop functionality is also provided.

## Autobot includes:
* basic Debian management and security hardening
    * lynis repot
    * crowdsec
* Automate installation and configuration* of:
    * zfs
    * wireguard and tailscaile
    * authelia
    * samba (windows shared folders)
    * mariadb
* backup with borg and borgmatic
* monitoring: prometheus/grafana stack
* media: installation of jellifyn and kavita
* servarr: start your servarr stack.
* productivity:
    * homepage as main dashboard.
    * wikis: Docmost and mediawiki
    * Immich photo manager


### This is for you if:
* you want to have control of your setup but are fine with a set of sensible defaults.
* you want to host web-services and/or php-mariadb apps
* you are conformable opening an ssh connection on your VPS/Server
* you embrace (or accept) that you are running debian stable on your server/system

### This is NOT for you if:
* you want a Click UI to setup your infra (similar to synology)
* you don't have a basic understanding of the technologies involved: Ansible, git ( or don't want to learn them)

## Documentation

for detailed information check the [documentation](https://ansible-autobott.github.io/docs/)