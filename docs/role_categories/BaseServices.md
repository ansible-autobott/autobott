# Base Services



> NOTICE: All the configuration items in this list only show the keys we consider you need to setup or decide upon.
>
> For a full list of configuration options check the defaults.yaml in the role directory



### Wireguard

Simple wireguard role that will install the module and configure wg0 

_mandatory configuration:_

```
run_role_wireguard: true
```
_optional:_

```
wireguard:
  # set false to disable the wg0 interface, but still leave it configured
  enabled: true
  
  # private key can be generated with "wg genkey", create the public key with: echo <priv_key> | wg pubkey
  # if left empty a key will be created at /etc/wireguard/private.key
  # configure the private key of the interface wg0 
  private_key: ""
  port: "51820"

  # the IP address of the interface 
  address: "192.168.20.1/24" #
  address_ipv6: ""

  # setup firewall rules to use as exit node
  exit_node: false

  # peers to configure
  peers: []
   - name: peer1
     public_key: "" 
     endpoint: ""
     # for VPN client set what ips go the vpn.
     # for VPN servers, limit the ips a client can assign itself
     # defaults to 0.0.0.0/0,::/0 ( all traffic)
     AllowedIPs: "192.168.20.2/32"
```

### Tailscale

Install the tailscale client.

Note: due to the nature of tailscale it's state cannot be provisioned with Ansible.

_mandatory configuration:_

```
run_role_wireguard: true
```

### Docker

Install docker.

_mandatory configuration:_

```
run_role_docker: true
```
_optional:_

```
docker:
  # add a metrics endpoint on "127.0.0.1:9323"
  expose_metrics: true
  
  # Enable experimental features
  experimental: false
  
  # Enable live restore, https://docs.docker.com/engine/daemon/live-restore/
  live_restore: true
  
  # users added to the docker group
  users: 
    - jsmith
```

### Samba

Install and configure Samba shares a.k.a Windows shared folders

_mandatory configuration:_

```
run_role_samba: true
```
_optional:_

Note: samba configuration is quite extensive and complex, check the defaults of the role if you miss something.

```
samba:

  # define the root dir for all shared folders
  shares_root: "/srv/shares"
  
  # setu shared folders
  shares:
    - name: "shared_folder"
      comment: "A shared folder"
      path: "/path/to/shared_folder"
      # list of users that can access the share
      valid_users: 
        - jsmith
      # sepcify users that have write access
      write_list:
        - jsmith
      # force user, group and modes when creating files
      force_user: ""
      force_group: ""
      create_mode: "0664"
      force_create_mode: "0664"
      directory_mode: "0775"
      force_directory_mode: "0775"        
  # define users
  users:
    - name: jsmith
      password: "{{ secrets.users.jsmith.passwd }}"
```

### MariaDB

Install MariaDB (compatible with mysql)

_mandatory configuration:_

```
run_role_mariadb: true
```
_optional:_

```
  # change the default port
  port: 3306
  
  # overwrite the sql_mode values eg,
  # "ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION"
  # see: https://mariadb.com/kb/en/sql-mode/
  sql_mode: ""

```

### Borg

Install Borg backup

NOTE: currently the role uses Borg 2 that is not yet classified as production ready.

_mandatory configuration:_

```
run_role_borg: true
```
_optional:_

```
borg:

  # The server settings configures the machine so that other borg instances
  # can backup to this server using ssh. This will only setup the SSH configuration
  # you still need to use borg on the client to initialize the repo.
  server:    
    enabled: false
    
    # where the backups will be stored
    data_directory: /var/borg_backups
    
    # Create symlink to ease the access and not expose internal storage structure
    # Set to empty string to disable symlink creation
    data_symlink: /backup
    
    # list of repositories, 
    repos: 
      - name: test
        public_key: "ssh-rsa AAAAB..."
        append_only: true        
```

### Borgmatic

Install and configure Borgmatic

_mandatory configuration:_

```
run_role_borgmatic: true
```
_optional:_

```
# setup automatic backups configurations
borgmatic:
  - name: test_php
    enabled: true
    # needs to be an existing borg repo
    destination: /vhosts/php/backups
    # select what directories to bacup
    dirs:
      - root: /vhosts/php/home_dir/public_html
    # select a list of databases to include in the backup
    mariadb:
      - php
      - test
      
    # select the retention policy
    retention: "minimal" # "minimal", "medium", "aggressive"
```

About retention policy
_minimal_ is:
```
keep_hourly: 1
keep_daily: 1
keep_weekly: 1
keep_monthly: 1
keep_yearly: 0
```
medium is: 
```
keep_hourly: 6
keep_daily: 2
keep_weekly: 2
keep_monthly: 2
keep_yearly: 1
```

and _aggressive_ is:
```
keep_hourly: 24
keep_daily: 7
keep_weekly: 4
keep_monthly: 6
keep_yearly: 1
```

