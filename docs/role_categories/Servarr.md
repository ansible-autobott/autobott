# Servarr

> NOTICE: All the configuration items in this list only show the keys we consider you need to setup or decide upon.
>
> For a full list of configuration options check the defaults.yaml in the role directory
  

### Jellyfin

Media player

Once enabled you can point a reverse proxy to: 127.0.0.1:8096

> Note for local network Client Discovery you need to add a firewall rule to allow UDP on port 7359

#### Tags:

* _jellyfin_ => run only this role

#### Mandatory configuration:

```yaml
run_role_jellyfin: true
```
#### Optional:
```yaml
jellyfin:
  # start the service with different umask value
  # set to something like 0022 (755) or 0007 (770), will be ommited if empty
  umask: ""
```

---

### Kavita

Book reader

Once enabled you can point a reverse proxy to: 127.0.0.1:5000

#### Tags:

* _kavita_ => run only this role

#### Mandatory configuration:

```yaml
run_role_kavita: true
```
#### Optional:
```yaml
kavita:
  # start the service with different umask value
  # set to something like 0022 (755) or 0007 (770), will be ommited if empty
  umask: ""
  # use External to delegate auth to the proxy
  auth_method: "External" # Basic | Forms | External | None
```

---

### Transmission

Torrent Client

Once enabled you can point a reverse proxy to: 127.0.0.1:9091

#### Tags:

* _transmission_ => run only this role

#### Mandatory configuration:

```yaml
run_role_transmission: true
transmission:
  remote_user: "torrent"
  remote_password: "torrent"
  # Download paths
  download_path: "/var/download"
```
#### Optional:
```yaml
transmission:
  # start the service with different umask value
  # needs to be set in decimal notation: 18=022 (644), 2=002 (664), 7=007 (660)
  umask: ""

```


---

### Prowlarr

Once enabled you can point a reverse proxy to: 127.0.0.1:9696

#### Tags:

* _prowlarr_ => run only this role

#### Mandatory configuration:

```yaml
run_role_prowlarr: true
```
#### Optional:
```yaml
prowlarr:
  # start the service with different umask value
  # set to something like 0022 (755) or 0007 (770), will be ommited if empty
  umask: ""
  # use External to delegate auth to the proxy
  auth_method: "External" # Basic | Forms | External | None
```

---
### Lidarr

Once enabled you can point a reverse proxy to: 127.0.0.1:8686

#### Tags:

* _lidarr_ => run only this role

#### Mandatory configuration:

```yaml
run_role_lidarr: true
```
#### Optional:
```yaml
lidarr:
  # start the service with different umask value
  # set to something like 0022 (755) or 0007 (770), will be ommited if empty
  umask: ""
  # use External to delegate auth to the proxy
  auth_method: "External" # Basic | Forms | External | None
```

---

### Radarr

Once enabled you can point a reverse proxy to: 127.0.0.1:7878

#### Tags:

* _radarr_ => run only this role

#### Mandatory configuration:

```yaml
run_role_radarr: true
```
#### Optional:
```yaml
radarr:
  # start the service with different umask value
  # set to something like 0022 (755) or 0007 (770), will be ommited if empty
  umask: ""
  # use External to delegate auth to the proxy
  auth_method: "External" # Basic | Forms | External | None
```

---


### Readarr

Once enabled you can point a reverse proxy to: 127.0.0.1:8787

#### Tags:

* _readarr_ => run only this role

#### Mandatory configuration:

```yaml
run_role_readarr: true
```
#### Optional:
```yaml
readarr:
  # start the service with different umask value
  # set to something like 0022 (755) or 0007 (770), will be ommited if empty
  umask: ""
  # use External to delegate auth to the proxy
  auth_method: "External" # Basic | Forms | External | None
```

---

### Sonarr

Once enabled you can point a reverse proxy to: 127.0.0.1:8989

#### Tags:

* _sonarr_ => run only this role

#### Mandatory configuration:

```yaml
run_role_sonarr: true
```
#### Optional:
```yaml
sonarr:
  # start the service with different umask value
  # set to something like 0022 (755) or 0007 (770), will be ommited if empty
  umask: ""
  # use External to delegate auth to the proxy
  auth_method: "External" # Basic | Forms | External | None
```

---

### Romm

Once enabled you can point a reverse proxy to: 127.0.0.1:3040

#### Tags:

* _romm_ => run only this role

#### Mandatory configuration:

```yaml
run_role_romm: true
romm:
  db_pass: "changeMe"
  # needs to be at least 32 chars generate with openssl rand -hex 32
  app_secret: "f787f1489baba67c41ea0187f6590a2742b1b6cd69b8f5fb6fef13e17c96ae5f"
  

```
#### Optional:
```yaml
romm:
  # check: https://docs.romm.app/latest/Getting-Started/Quick-Start-Guide/
  integration:
    igdb_client_id: ""
    igdb_client_secret: ""

    # https://docs.romm.app/latest/Getting-Started/Generate-API-Keys/#mobygames
    mobygames_api_key: ""
    # https://docs.romm.app/latest/Getting-Started/Generate-API-Keys/#steamgriddb
    steamgridd_api_key: ""

    # Use your ScreenScraper username and password
    # https://docs.romm.app/latest/Getting-Started/Generate-API-Keys/#screenscraper
    screenscraper_user: ""
    screenscraper_pw: ""

    # https://api-docs.retroachievements.org/#api-access
    retroachievements_api_key: ""
```

--- 

### Whisparr

Once enabled you can point a reverse proxy to: 127.0.0.1:6969

#### Tags:

* _whisparr_ => run only this role

#### Mandatory configuration:

```yaml
run_role_whisparr: true
```
#### Optional:
```yaml
whisparr:
  # start the service with different umask value
  # set to something like 0022 (755) or 0007 (770), will be ommited if empty
  umask: ""
  # use External to delegate auth to the proxy
  auth_method: "External" # Basic | Forms | External | None
```

---

### Stash

Once enabled you can point a reverse proxy to: 127.0.0.1:9999

#### Tags:

* _stash_ => run only this role

#### Mandatory configuration:

```yaml
run_role_stash: true
```

---


### Xbvr

Once enabled you can point a reverse proxy to: 127.0.0.1:9997

#### Tags:

* _xbvr_ => run only this role

#### Mandatory configuration:

```yaml
run_role_xbvr: true
```

---



