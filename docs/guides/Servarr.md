# About

The Servarr stack ( sonarr, radarr, etc) configuration it sout of the scope of this document, 
check the official documentation for details.

In this document we will provide a quick list getting started steps to be up and running, consider this like a 
checklist after installation.

## Prowlarr
* add a new index
* integrate with other services:
  * go to settings > Apps ( you need to gather an API key from the app you want to integrate)
  * Add the application, paste API key. all default URLs should be OK.

* (optional) Integrate with transmission
  * go to settings > Download Clients > Transmission
  * paste username + password
  * Add a default category (see auto-cleanup below)

# Other App Setup ( sonar, radar, etc)
* Getting the API key
  * go to settings > General
  * copy the API key
* Integrate with transmission
    * go to settings > Download Clients > Transmission
    * paste username + password
    * Add a category (see auto-cleanup below)

# Auto-Cleanup

Autobott ships with an auto-clean up script that can automatically remove completed torrents after a certain time.
(this ensures that your torrent has a minimum seed time, as some trackers need)

To isolate the auto-cleanup from regular downloads, it's highly recommend to use the Category field in your apps;
This creates dedicated directories that the cleanup script can address.


# File permissions across services

Every servarr runs as its own user and group, the same applies to samba shared folder users.

To allow all servarr and samba user access the same file we need to change how file permissions are setup for the 
share content.

In this example we will use a group called _smbmedia_ that will have access to all the media files, if you want 
to split e.g. movies, books, etc. into different groups this is possible.
The user smbmedia will act as a stub for files created by samba, but for this shared scenario user ownership is not relevant.

Important: both the user and the group needs to already exist on the system, use the linux_basic role to provision them.


### Torrent downloaded files

Create a samba shared dir for your torrents

```
shares:
  - name: "torrents"
    comment: "Download dir"
    path: "/media/torrent"
    owner: "smbmedia"  # select a common dummy user,
    group:  "smbmedia"  # all servarr users need to be part of this group
    mode: "2770" # 2xxx sets the setgid bit to ensure created files and dirs Inherit the group of the parent directory

    # this block ensure that files created thru samba are consistent
    force_user: "smbmedia"
    force_group: "smbmedia"
    create_mode: "0660"
    force_create_mode: "0660"
    directory_mode: "0770"
    force_directory_mode: "0770"
    inherit_permissions: true 
    inherit_acls: True

    # define user access
    valid_users:
      - "@smbmedia"
    write_list:
      - "@smbmedia"
```

Now configure transmission to download into that share with adequate permissions set
```
transmission:
  download:
    path:  "/media/torrent"
    owner: debian-transmission
    group: smbmedia
    mode: "2750"
  # important to set the umask value, this ensures that torrent files are created as with permissions 660
  # needs to be set in decimal notation: 18=022 (644), 2=002 (664), 7=007 (660)
  umask: 7
```

### Servarr integration

Create a samba shared dir for your media collection

```
shares:
  - name: "media"
    comment: "A shared folder"
    path: "/media/shared_movies"

    owner: "smbmedia"  # TODO add to defaults
    group:  "smbmedia" # TODO add to defaults
    mode: "2770" # 2xxx sets the setgid bit, to ensure created files and dirs Inherit the group of the parent directory

    force_user: "smbmedia"
    force_group: "smbmedia"
    create_mode: "0660"
    force_create_mode: "0660"
    directory_mode: "0770"
    force_directory_mode: "0770"
    inherit_permissions: true # TODO add to defaults
    inherit_acls: True # TODO add to defauls

    valid_users:
      - "@smbmedia"
    write_list:
      - "@smbmedia"

```

Now you need to configure the Servarr apps to have access to the shared files both torrent download and final destination.

For this example we will use Sonarr, but you need to repeat for all the apps you use.

```
sonarr:
  user:
    # tell the sonnar service to start as group smbmedia, this gives it read permissions on the torrent location
    group: smbmedia
  service:
    # tell sonnar to create new folders with permissions 770, aligend with the torrent share
    umask: "0007"
```

### Jellyfin integration

To have Jellyfin access the shared media, it also needs the following configuration:


