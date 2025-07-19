# Web Services


> NOTICE: All the configuration items in this list only show the keys we consider you need to setup or decide upon.
>
> For a full list of configuration options check the defaults.yaml in the role directory

### Fe26

Simple web based File Manager.

> Note: fe26 does NOT have authentication, you will need to protect the files with a proxy, see [vhosts](Vhosts.md) for details

Once enabled you can point a reverse proxy to: 127.0.0.1:7070

#### Tags:

* _fe26_ => run only this role

#### Mandatory configuration:

```yaml
run_role_fe26: true
```
#### Optional:
```yaml
fe26:
  # if you want to install as a diferent user.
  user:
    name: fe26
    uid: # Let system assign UID
    group: fe26
    gid: # Let system assign GID
  paths:
    # location for the shared files
    data_dir: /opt/fe26/data
```

---

### Homepage

Configurable homepage service.

Once enabled you can point a reverse proxy to: 127.0.0.1:3003

#### Tags:

* _homepage_ => run only this role
* _homepage-settings_ => only apply new homepage settings

#### Mandatory configuration:

```yaml
run_role_homepage: true
homepage:
  allowed_host: localhost:8443
```
To configure homepage you need to create the config files: bookmarks.yaml, services.yaml, settings.yaml and widgets.yaml
in any of the following paths: _<inventory_root>/files/homepage_ or  _<inventory_root>/files/homepage/<host_name>_

They will be picked up in order of preference, giving priority to the host.

For details on configuration check the official documentation: [https://gethomepage.dev/configs/](https://gethomepage.dev/configs/)

You can add additional images and icons on the paths: 
_<inventory_root>/files/homepage/images_ and  _<inventory_root>/files/homepage/icons_ respectively

 

---
### Radicale

CalDav and CardDav server that stored data as plain files.

Note: radicale does NOT have authentication enabled by default, 
you will need to protect the files with a proxy, see [vhosts](Vhosts.md) for details

Once enabled you can point a reverse proxy to: 127.0.0.1:5232

Radicale expects the header X-Remote-User to be populated, e.g. use this vhost config:

```yaml
# in the vhosts: config
servers:
  - enabled: true
    domains:
      - "http://radicale.localhost:8080"
      - "https://radicale.localhost:8443"
    type: "proxy"
    proxy_url: "http://127.0.0.1:5232"
    # Radicale requires the header X-Remote-User
    proxy_lines:
      - 'header_up X-Remote-User "{http.auth.user.id}"'

    authentication: true
    htpasswd_file_users:
      - user: user1
        pass: "1234"
        enabled: true
```

#### Mandatory configuration:

```yaml
run_role_radicale: true
```

---

### Immich

The personal replacement for google photos

Once enabled you can point a reverse proxy to: 127.0.0.1:2283

#### Tags:

* _immich_ => run only this role

#### Mandatory configuration:

```yaml
run_role_immich: true
immich:
  # change, only the characters `A-Za-z0-9`, without special characters or spaces
  db_pass: "changeMe"

```
#### Optional:
```yaml
immich:
  paths:
    # where uploaded photos will be placed
    uploads_dir: /opt/immich/uploads
  service:

    # set an identifier from this list: https://en.wikipedia.org/wiki/List_of_tz_database_time_zones#List
    timezone: Etc/UTC
    # Mount local folders into a targe withing the docker container
    # the tarted will be /media/<name> -> the target, e.g.
    #  piratecove: "/media/piratecove"
    mounts: []
```

---

### Docmost

Collaborative wiki 

Once enabled you can point a reverse proxy to: 127.0.0.1:3030

#### Tags:

* _docmost_ => run only this role

#### Mandatory configuration:

```yaml
run_role_docmost: true
docmost:
  # change, only the characters `A-Za-z0-9`, without special characters or spaces
  db_pass: "changeMe"
  # needs to be at least 32 chars
  app_secret: "REPLACE_WITH_LONG_SECRET_REPLACE_WITH_LONG_SECRET"
```
#### Optional:
```yaml
immich:
  paths:
    # where uploaded photos will be placed
    uploads_dir: /opt/immich/uploads
  service:

    # set an identifier from this list: https://en.wikipedia.org/wiki/List_of_tz_database_time_zones#List
    timezone: Etc/UTC
    # Mount local folders into a targe withing the docker container
    # the tarted will be /media/<name> -> the target, e.g.
    #  piratecove: "/media/piratecove"
    mounts: []
```
---

### Mealie

Keep track of food recipes and planning

Once enabled you can point a reverse proxy to: 127.0.0.1:9925

#### Tags:

* _mealie_ => run only this role

#### Mandatory configuration:

```yaml
run_role_mealie: true
mealie:
  # change, only the characters `A-Za-z0-9`, without special characters or spaces
  db_pass: "changeMe"
  # needs to be at least 32 chars
  app_secret: "REPLACE_WITH_LONG_SECRET_REPLACE_WITH_LONG_SECRET"
```

### PHPmyadmin

PHP interface to manage Mysql/MariaDB Databases.

to use this you will need to setup a php vhost like this:


```yaml
# in the vhosts: config
servers:
  - name: phpmyadmin
    enabled: true
    comment: "mysql database management in php"
    servers:
      - enabled: true
        domains:
          - "http://pma.localhost:8080"
          - "https://pma.localhost:8443"
        type: "php"
        document_root: "/opt/phpmyadmin/latest"
    php:
      enabled: yes
      open_basedir:
        - "/opt/phpmyadmin/latest"
```

#### Tags:

* _phpmyadmin_ => run only this role

#### Mandatory configuration:

```yaml
run_role_phpmyadmin: true
phpmyadmin:
  blowfish_secret: "so1deege7Shoogaewoo4haR2phohghae7sas3luifaex7quahv"
```

### MediaWiki

The Original WIKI

To use this you will need to setup a php vhost like this:


```yaml
# in the vhosts: config
servers:
  - name: mediawiki
    enabled: true
    comment: "wiki powered by mediawiki"
    servers:
      - enabled: true
        domains:
          - "http://wiki.localhost:8080"
          - "https://wiki.localhost:8443"
        type: "php"
        document_root: "/opt/mediawiki/public"
    php:
      enabled: yes
      open_basedir:
        - "/opt/mediawiki/data"
        - "/opt/mediawiki/install"
    mariadb:
      enabled: true
      password: "mediawiki"
```

> IMPORTANT: ensure that the server name and the database matchers the mediawiki config.
> see [vhost](Vhosts.md) for more information.

#### Tags:

* _mediawiki_ => run only this role

#### Mandatory configuration:

```yaml
run_role_mediawiki: true
mediawiki:
  wiki:
    name: "demo wiki"
    admin_user: "demo"
    admin_pass: "wiki12345678"
    base_url: "https://wiki.localhost:8443"
    secret_key: "changeme"
    site_upgrade_key: "changeme"
```

#### Optional:
```yaml
mediawiki:
  wiki:
    emergency_contact_mail: "me@localhost"
    password_sender_mail: "me@localhost"
    secret_key: "changeme"
    site_upgrade_key: "changeme"

    namespace: "main"
    print_exceptions: false
    
    locale: "en_US.utf8"
    lang: "en"
    # allowed upload extensions
    allowed_extensions:
      - pdf
      - tiff
      - txt
    # whitelist extensions that are normally not allowed
    whitelisted_extensions:
      - txt
```
---