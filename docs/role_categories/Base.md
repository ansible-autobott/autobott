# Base 

> NOTICE: All the configuration items in this list only show the keys we consider you need to setup or decide upon.
>
> For a full list of configuration options check the defaults.yaml in the role directory



### Linux APT

This role takes care of configuring your apt sources.

_mandatory configuration:_

```
# Enable/disable the entire role
run_role_linux_apt: true

# configure the role
linux_apt:
  # needs to be set to the debian release, at the moment it MUST be bookworm ( will be changed in the future)
  release: "bookworm" 
```

_optional:_ 

```
linux_apt:
  # extra_sources_d allows to configure additional apt sources
  extra_sources_d: 
     - name: "docker"                                            # Repository identifier
       repo: "deb [arch=amd64] https://download.docker.com/linux/debian bookworm stable"  # Repository definition
       key_url: "https://download.docker.com/linux/debian/gpg"  # Repository signing key URL
       key_id: "9DC858229FC7DD38854AE2D88D81803C0EBFCD88"      # Key fingerprint for verification
       enabled: true                                            # Repository state
       pin_priority: 500                                        # Optional pin priority
```

### Linux Basic

This role sets up essential base configurations for the Linux host including packages, 
hostname, SSH, timezone, locale, users, and more.

_mandatory configuration:_

note: the default values of this role will perform the following changes on the system: 
* Installing default packages
* ssh:
  * allow only ssh key login

```
run_role_linux_basic: true

```

_optional:_

##### Install additional packages
```
# configure the role
linux_basic:
  packages:
    # list of apps that can be defined in a host inventory
    host_defined: []
    # list of apps that can be defined at group inventory
    group_defined: []
    # list of packages not to be present, defined in host inventory
    absent_host_defined: []
    # list of packages not to be present, defined in group inventory
    absent_group_defined: []
```

##### Hostname related configuration

```
linux_basic:
  # define the host's hostname
  hostname: ""
  
  # define the host's Fully qualified domain name
  fqdn: "{{ ansible_fqdn }}"
  
  # add extra entries to /etc/hosts
  etc_host_entries: 
    - 127.0.0.1 wiki.localhost
```

##### sshd related configuration
```
linux_basic:
  ssh:
    # enable X11 forwarding, this should not be needed on a normal server
    x11_forwarding: false
    
    # create a special group that will allow passwd auth, default only ssh keys are allowed
    pw_auth_group_name: "allowpwauth"
    
    # setup sftp jails for users in a specific group.
    # a jail allows users to sftp into the jail dir, but not navigate out of it 
    sftp_jails: 
      - group_name: sftp
        jail_dir: "/home"      # will be composed as {{ jail_dir }}/%u
        start_dir: "/home_dir" # optional, allows to define the default starting dir when opening a session
        umask: 0077            # change the umask parameter of the jail default is 0077 creates files as 0700
        allow_password: true
        remove: false # set to true to remove the sftp jail config
```
##### Locale
```
linux_basic:
  # set / change the timezone of the machine, e.g. "Europe/Zurich"
  timezone: "Europe/Zurich" # timezone to configure in the machine
  
  # this allows to overwrite the setting of the RTC (real time clock)
  # normally on windows the RTC is set to local time and on linux to UTC, you can force linux to use local
  time_rtc: "UTC" # "local | UTC"

  locale:
    # list of locales to be generated (take care to use value from /usr/share/i18n/SUPPORTED,as locale-gen exit with code 0 even with errors...)
    generate:
      - en_US.UTF-8 UTF-8
    # locale to be configured
    set:
      lang: en_US.UTF-8
      all: en_US.UTF-8  
```
##### Users and groups
```
linux_basic:
  ## create system groups
  groups: 
    - name: sftp
      gid: 402
      
  ## create an system users
  system_users:
    - username: "tardis"
      enabled: true
      name: "that blue box"
      groups: [ 'trenzalore','gallifrey']
      uid: 2001
      gid: 2001
  
  ## create regular users
  users:
    - username: jsmith
      name: "The Doctor"
      enabled: yes
      delete_home: false # if enabled is set to false, determine if the home directory should be deleted
      primary_group: "users" # group needs to exist, default "users"
      groups: ['sudo', 'trenzalore','gallifrey']  # empty string removes user from all secondary groups
      enforce_groups: no
      password: "my-secrets-password" # encrypted
      shell: /bin/bash # optional
      ssh_key:
        - "ssh-rsa AAAAA.... john@laptop"
        - "ssh-rsa AAAAB.... doctor@desktop"
      ssh_key_revoked:
        - "ssh-rsa AAAAB.... doctor@desktop"
      uid: 2001
      gid: 2002
      
  # same as users but allows to define users in two inventory places  
  users_extra: []    
```
##### Mixed stuff
```
linux_basic:
  # setup an email in cron that will get cron error reports
  cron_email: "" 
  # add a timeout of when sudo will ask a password again.
  # set to "" to disable
  sudo_timeout: "600"
```

### ZFS

This role will install openzfs from the debian contrib repository

note: contrib needs to be enabled, otherwise the role will fail

_mandatory configuration:_

```
run_role_zfs: true
```

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

### Nullmailer

Nullmailer is a lightweight SMTP relay agent designed to forward outgoing mail from a host to a configured 
smart relay server without handling local mail delivery.

Used to send email notifications through sendmail


_mandatory configuration:_

```
run_role_nullmailer: True
nullmailer:
  # destination address to send emails to, accepts multiple emails comma separated
  email_to: ""
  # smtp configuration
  smtp_server: ""
  smtp_user: ""
  smtp_pass: ""
  
```
_optional:_

```
nullmailer:
  # override set the from field in send emails
  # note see: https://github.com/bruceg/nullmailer/issues/72
  override_from: ""
  # set the default domain from where emails are sent from
  email_from: ""

```
