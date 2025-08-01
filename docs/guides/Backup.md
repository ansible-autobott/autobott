# TODO

* explain how to setup local backupç
* how to setup vps backtup to remote location
* how to setup a server, init the backup and autome the backup with borgmatic

explain how to use goback to generate remove (vps backups ) to a central location
then use goback remote pull/ sync to bring back the remotes to a local locatop
to keep the access to a minimum use linux basic to create the user and add him to a sfpt jail


```
  ssh:
    sftp_jails:
      - group_name: sftp
        allow_password: true
        jail_dir: "/home"
        # remove: false

      - group_name: goback
        allow_password: false
        jail_dir: "/var/goback"
        # remove: false

  users:
    - username: goback
      enabled: true
      delete_home: false
      name: "goback"
      primary_group: "goback"
      groups: []
      shell: /bin/false # optional
      ssh_key:
        - "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHuZR7OcbpycqjQ7BhdvYtLhX8QWpNFoc2qrfRRV0J5l odo@zeus"

```