# Roadmap

## missing roles to migrate
* base/linux-hardware 
* security/fail2ban or security/crowdsec

* desktop kde
* linux-desktop


## possible future services

* base/postgres
* base/se-linux
* vaultwarden
* gonic / airsonic music server
* excalidraw some type of selfhosted with server storage
* OliveTin
* SMART web ui => https://github.com/AnalogJ/scrutiny

# Braindump

* check how to make borgmatic pull for vps manual/automatic backup
* add a mechanism to prevent running old version
    * store the version on the server
    * autobot will check the version and only run if it is a supported one, e.g. v3 allows to update from v2 but not v1

* automatic torrent cleanup
* validation role:
    * ensure all servarr ports are not publicly available

* grafana
    * add a graph for zfs l2arc cache hit ratio
    * Smart data for disks

* authelia role is not complete
    * no email sending

* verify docmost backup/restore
* make sure local account has login, in case you need to access the machine
* make homepage files templated so that we can add secrets using ansible managed secrets

