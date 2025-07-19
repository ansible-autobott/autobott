# Getting started

## Enroll

to run autobott you will need to have a user on the target system that allows for ssh in and sudo.

The recommendation is to use a dedicated management user (default is "ans") for this use-case.

The expectation is that this system user can be accessed with an ssh key only (defined in `autobott_enroll_ssh_keys`)
and once accessed it needs an second password (defined in `autobott_enroll_passwd` ) to obtain root on the system.

### Enrolling remote machines 

There is a convenient make target specified to enroll remote machines

```
export ANSIBLE_USER="debian"
export ANSIBLE_PASS="secret"
make enroll INV=../autobott2-inventory/inventory.yaml HOST=dev.ika.re

```

## running locally
if you don't want to have the ssh user exposes, you can as well clone the repository to the target machine
and run it locally with a user that also has sudo permissions.

TODO: not tested yet

# Inventory

Autobott allows to manage multiple hosts with different configurations.

Generally you would keep your own inventory in a different git repository, one repo that contains multiple hosts
normally is enough.

You can use the sample inventory in this repo (used for vagrant) as guidance to set up your own.

the default inventory locaion is _../inventory/main.yaml_ but you can specify diferent one with the env var
_INV_

```
export INV="../inventory/servers.yaml"
make run
```
```
make run INV=../inventory/servers.yaml
```

## Secrets

within the inventory there is a `secrets.yaml` file that store all the secrets for a specific host.
It is imperative that you do NOT commit any un-encrypted secret to your inventory repository.

#### TODO

For now the only way to encrypt/decrypt secrets is to replicate the ansible-vault plugin into the inventory 
repository, I'm looking for better alternatives