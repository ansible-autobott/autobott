# Roles Overview

Here you can find a list of Roles in Autobott and their scope


## Base 

The [Base](role_categories/Base.md) category includes foundational system configuration roles essential for 
provisioning and maintaining the core of the Debian-based Linux environment.

| Role          | Description                                                        | 
|---------------|--------------------------------------------------------------------|
| `linux_basic` | Sets up base system settings: packages, SSH, timezone, users, etc. | 
| `linux_apt`   | Configures APT sources for Debian systems.                         |
| `zfs`         | Installs and configures OpenZFS from the Debian contrib repo.      | 
| `wireguard`   | Installs and configures a basic Wireguard VPN setup.               | 
| `tailscale`   | Installs the Tailscale client.                                     | 
| `docker`      | Installs and configures the Docker daemon and user access.         | 
| `nullmailer`  | Install a minimal smtp email forwarder to get email notifications  | 

### Base Services

The [Base Services](role_categories/BaseServices.md) category provides core system services commonly used. 
These include VPN, file sharing, database, and backup solutions.

| Role        | Description                                                    |
|-------------|----------------------------------------------------------------|
| `wireguard` | Installs and configures a basic Wireguard VPN setup.           |
| `tailscale` | Installs the Tailscale client.                                 |
| `docker`    | Installs and configures the Docker daemon and user access.     |
| `samba`     | Installs and configures Samba file shares.                     |
| `mariadb`   | Installs and configures a MariaDB server.                      |
| `borg`      | Installs BorgBackup (v2) for backup storage or remote targets. |
| `borgmatic` | Installs and configures Borgmatic for scheduled backup jobs.   |

---

## Security

The [Security](role_categories/Security.md) category contains roles that harden and protect your system, 
covering firewall rules and system auditing.

| Role         | Description                                                    |
|--------------|----------------------------------------------------------------|
| `lynis`      | Runs a Lynis audit and generates a security compliance report. |
| `firewall`   | Configures a restrictive firewall with allowlist-based rules.  |

---

### Web Services

The [Web Services](role_categories/WebServices.md) category provides self-hosted web applications and interfaces. These roles enable wiki hosting, media galleries, calendars, dashboards, and more.

| Role         | Description                                                                 |
|--------------|-----------------------------------------------------------------------------|
| `fe26`       | Simple web-based file manager. No auth; protect via proxy (see vhosts).     |
| `homepage`   | Customizable web dashboard for links, widgets, and bookmarks.               |
| `radicale`   | CalDAV and CardDAV server for contacts and calendars. Proxy-auth required.  |
| `immich`     | Self-hosted photo backup and gallery system.                                |
| `docmost`    | Collaborative wiki for documentation and notes.                             |
| `mealie`     | Recipe manager with meal planning and shopping list features.               |
| `phpmyadmin` | Web-based interface for managing MySQL/MariaDB databases.                   |
| `mediawiki`  | Full-featured wiki platform, requires PHP + MariaDB backend.                |


### Servarr

The [Servarr Services](role_categories/Servarr.md) category provides media-related services for managing, organizing, and accessing your personal collections — including music, movies, TV shows, books, and more.

| Role           | Description                                          |
|----------------|------------------------------------------------------|
| `jellyfin`     | Self-hosted media player and server.                 |
| `kavita`       | Modern eBook and comic reader server.                |
| `transmission` | Torrent client for downloading content.              |
| `prowlarr`     | Indexer manager to support Sonarr, Radarr, etc.      |
| `lidarr`       | Music collection manager.                            |
| `radarr`       | Movie library management and automation.             |
| `readarr`      | Book library management with automation.             |
| `sonarr`       | TV series management and downloading.                |
| `whisparr`     | Adult media collection manager (Sonarr/Radarr fork). |
| `stash`        | Content organizer/player for adult media.            |
| `xbvr`         | 3D/VR adult content manager and media server.        |
