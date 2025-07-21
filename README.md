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


## Try it yourself

This ansible playbook has a convenien vagrant/virtualbox integration for testing and development. 

1. Install virtual box from https://www.virtualbox.org/
2. install vagrant https://developer.hashicorp.com/vagrant
3. bake the base vagrant image (this needs to be only once)

This will bake a base debian image that autobott will use to clone other instances 
```
make vagrant-base
```

4. Start and Enroll your VM (add the minimal setup to your new image)
```
make vagrant-up
```

5. Run all roles to provision all the services
```
make vagrant-run

#You can also run specific roles,targets using the Vars TAG=<tag> and HOST=<host>
make vagrant-run TAG=authelia
```
After completing the installation (can take a while) you can access the instance on https://localhost:8443

If you get error "WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED", you need to trust the new known_hosts, you can run
`make vagrant-ssh-renew` to delete and trigger a new ssh login


6. Lastly if you want to delete the image ( or start all over again)

Note: this will delete all data on the image 
```
make vagrant-destroy
```
